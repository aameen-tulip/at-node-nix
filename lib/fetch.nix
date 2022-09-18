# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #
#
# Designed for use with `pkgs/build-support/fetcher.nix', but "pure" routines
# have been separated here so that they may be available for some `meta*'.
# NOTE: `pkgs/build-support/fetcher.nix' is somewhat dated, and came before
# the newer `mkExtInfo' patterns, and it lacks certain types of fetchers
# related to registry tarballs in the new `nodeScope' patterns.
# Those routines are likely due for an overhaul soon, and may be slowly
# migrated here to this lib - since they should represent pure interfaces
# anyway ( fetcher drv generators are not injected until the very end ).
#
# ---------------------------------------------------------------------------- #

  # Symlink: { resolved :: relative path string, link :: bool }
  # Path: { resolved :: relative path string }
  # Git ( private and public ):
  #   "resolved": "git+ssh://git@github.com/<owner>/<repo>.git#<rev>",
  #   This URI is consistent regardless of `https://' or other descriptors.
  #   So, if `builtins.match "git\\+.*" entry.resolved != null' you need to run
  #   the `prepare' ( or whatever ) lifecycle scripts.
  # Tarball: { resolved :: url or path string, integrity :: SHA512-SRI, [sha1] }
  typeOfEntry = entry: let
    isLink  = entry.link or false;
    isGit   = entry ? resolved && ( lib.test "git\\+.*" entry.resolved );
    isPath  = ! ( ( entry ? link ) || ( entry ? resolved ) );
    isRegTb =
      ( ( entry ? integrity ) || ( entry ? sha1 ) ) &&
      ( entry ? resolved ) &&
      ( ( lib.test "http.*/-/.*\\.tgz" entry.resolved ) ||
        ( lib.test "https?://npm.pkg.github.com/.*" entry.resolved ) );
    isSrcTb =
      ( ( entry ? integrity ) || ( entry ? sha1 ) ) &&
      ( entry ? resolved ) &&
      # XXX: Checking for "/-/" in the URL path is far from "robust" but
      #      it does what I need it to do for now.
      ( ! ( lib.test "http.*/-/.*\\.tgz" entry.resolved ) ) &&
      ( lib.test "http.*\\.(tar\\.gz|tgz)" entry.resolved );
  in if isLink  then "symlink"          else
     if isGit   then "git"              else
     if isPath  then "path"             else
     # XXX: `isRegTb' must be checked before `isSrcTb`
     if isRegTb then "registry-tarball" else
     if isSrcTb then "source-tarball"   else
     throw "(typeOfEntry) Unrecognized entry type: ${builtins.toJSON entry}";


# ---------------------------------------------------------------------------- #

  # Given a set of `nodeFetchers' which satisfy the expected interfaces -
  # Return the fetch function for the given `type'
  fetcherForType = {
    tarballFetcher
  , urlFetcher
  , gitFetcher
  , linkFetcher
  , dirFetcher
  , ...
  } @ nodeFetchers: type:
    if type == "symlink"          then nodeFetchers.linkFetcher     else
    if type == "path"             then nodeFetchers.dirFetcher      else
    if type == "git"              then nodeFetchers.gitFetcher      else
    if type == "registry-tarball" then nodeFetchers.tarballFetcher  else
    if type == "source-tarball"   then nodeFetchers.tarballFetcher  else
    if type == "tarball"          then nodeFetchers.tarballFetcher  else
    if type == "url"              then nodeFetchers.urlFetcher      else
    throw "(fetcherForType) Unrecognized entry type: ${type}";


# ---------------------------------------------------------------------------- #

  hashFields = {
    sha1      = true;
    sha256    = true;
    sha512    = true;
    integrity = true;
    hash      = true;
    narHash   = true;
  };

  # XXX: I'm unsure of whether or not this works with v1 locks.
  plockEntryHashAttr = entry: let
    integrity2Sha = integrity: let
      m = builtins.match "(sha(512|256|1))-(.*)" integrity;
      shaSet = { ${builtins.head m} = builtins.elemAt m 2; };
    in if m == null then { hash = integrity; } else shaSet;
    fromInteg = integrity2Sha entry.integrity;
  in if entry ? integrity then fromInteg else
     if entry ? sha1      then { inherit (entry) sha1; } else {};


# ---------------------------------------------------------------------------- #

  # Registry tarball package-lock entry to fetch* arguments
  #
  # Remember that Nix is lazily evaluated, so while this may look like a wasted
  # effort, since we ultimately only use one of these attributes - you need
  # to look at these like "lenses" ( or an object accessor for y'all OOP heads
  # in the audience ).
  #
  # If `impure' is enabled, the `narHash' of the unpacked tarball will be
  # calculated by pre-fetching.
  # This allows the `fetchzip' derivation to be created which is useful if you
  # plan to push/pull from remote binary caches or stores.
  # Ideally you would pre-fetch to define the derivation, then use
  # `nix-store --dump-db ...' or serialize this info with `toJSON' to stash the
  # info to optimize/purify future runs.
  plock2TbFetchArgs' = impure: { resolved ? entry.url, ... } @ entry: let
    prefetched = if ( ! impure ) then {} else fetchTree bfr;
    nha = plockEntryHashAttr entry;
    # nixpkgs.fetchurl
    nfu = { url = resolved; } // nha;
    # XXX: You cannot use `nixpkgs.fetchzip' without knowing the unpacked hash.
    # If `impure == true' we prefetch and record the hash so that it's possible
    # to push the derivation to a cache - this isn't /really/ that useful in
    # practice, but it is better than not having a DRV at all.
    nfz = { url = resolved; sha256 = prefetched.narHash; };
    # builtins.fetchurl
    bfu = resolved;                               # XXX: Impure
    # builtins.fetchTree
    bfr = { type = "tarball"; url = resolved; };  # XXX: Impure
    # builtins.fetchTarball
    bft = { url = resolved; };                    # XXX: Impure
    # fetchurlDrv
    lfu = { url = resolved; unpack = false; } // nha;
    flake = bfr // { flake = false; };
    impureArgs = {
      nixpkgs.fetchurl      = nfu;
      nixpkgs.fetchzip      = nfz;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr   // { inherit (prefetched) narHash; };
      builtins.fetchTarball = bft   // { sha256 = prefetched.narHash; };
      flake                 = flake // { inherit (prefetched) narHash; };
      lib.fetchurlDrv       = lfu;
    };
    pureArgs = {
      nixpkgs.fetchurl      = nfu;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr;
      builtins.fetchTarball = bft;
      inherit flake;
      lib.fetchurlDrv       = lfu;
    };
  in if impure then impureArgs else pureArgs;


# ---------------------------------------------------------------------------- #

  # Git
  plock2GitFetchArgs' = impure: { resolved ? entry.url, ... } @ entry: let
    # I'm pretty sure you can pass this "as is" to `fetchTree'.
    # I'm also pretty sure that Eelco implemented `fetchTree' and Flake refs
    # based on NPM's URIs to support Node.js at Target - the commonality is
    # uncanny even for NPM's extended URIs.
    #   0: protocol ( ssh, http(s), etc )
    #   1: host     ( git@github.com, github.com, gitlab.com, etc )
    #   2: owner
    #   3: repo
    #   4: rev
    #
    # git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c
    murl = builtins.match "(git+[^:]+)://([^/:]+)[/:]([^/]+)/([^#]+)#(.*)"
                          resolved;
    protocol = builtins.head murl;
    host     = builtins.elemAt murl 1;
    owner    = builtins.elemAt murl 2;
    repo     = builtins.elemAt murl 3;
    rev      = builtins.elemAt murl 4;

    # NOTE: If a hostname has a `git@' ( ssh ) prefix, it MUST use a ":", not
    #       "/" to separate the hostname and path.
    #       Nix's `fetchGit' and `fetchTree' do not use a ":" here, so replace
    #       it with "/" - if you don't, you'll get an error:
    #       "make sure you have access rights".
    # builtins.fetchGit { url = "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c"; }
    # builtins.fetchTree { type = "git"; url = "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c"; }
    # NOTE: You must provide `type = "git";' for `fetchTree' it doesn't parse
    #       the URI to try and guess ( flake refs will ).
    # NOTE: You must leave the "<path>#<rev>" as is for the builtin fetchers -
    #       a "<path>/<rev>" will not work; but I think flake inputs DO want it
    #       replaced with a "/".
    bfg = {
      url = "${protocol}://${host}/${owner}/${repo}#${rev}";
      inherit rev;
      allRefs = true;
    };
    bfr = bfg // { type = "git"; };
    prefetched = if ( ! impure ) then {} else fetchTree bfr;
    # XXX: Impure
    nfg = {
      inherit rev;
      url = "${protocol}://${host}/${owner}/${repo}";
      sha256 = prefetched.narHash;
    };
    flake = bfr // { flake = false; };
    impureArgs = {
      nixpkgs.fetchgit   = nfg;
      builtins.fetchTree = bfr   // { inherit (prefetched) narHash; };
      builtins.fetchGit  = bfg   // { inherit (prefetched) narHash; };
      flake              = flake // { inherit (prefetched) narHash; };
    };
    pureArgs = {
      builtins.fetchTree = bfr;
      builtins.fetchGit  = bfg;
      inherit flake;
    };
  in if impure then impureArgs else pureArgs;


# ---------------------------------------------------------------------------- #

  # This is the only fetcher that doesn't take the entry itself.
  # You need to pass the "key" ( relative path to directory ) and CWD instead.
  # NOTE: We intentionally avoid a check like `assert builtins.pathExists abs'
  #       here because these fetchers may be generated before dependant paths
  #       are actually fetched, and if they refer to store paths, they may not
  #       be built yet.
  #       Instead we put faith in the lazy evaluator.
  #       For this same reason, we strongly recommend that you explicitly set
  #       `cwd' because relying on the default of `PWD' makes a BIG assumption,
  #       which is that all of these paths are locally available.
  plock2PathFetchArgs' = impure: {
    cwd ? ( if impure then builtins.getEnv "PWD" else
          throw ( "(plock2PathFetchArgs) Cannot " +
                  "determine CWD to resolve path URIs" ) )
  , key ? args.pkey or args.resolved or args.path  # "key" is a relative path
  , ...
  } @ args: let
    cwd' = assert lib.libpath.isAbspath cwd;
      builtins.head ( builtins.match "(.*[^/])/?" cwd );
    abs = if ( lib.libpath.isAbspath key ) then key else
          if ( key == "" ) then cwd' else "${cwd'}/${key}";
  in {
    builtins.fetchTree = { type = "path"; path = abs; };
    builtins.path = { path = abs; };
    # FIXME: I have no idea if this works.
    flake = { type = "path"; path = abs; flake = false; };
  };


# ---------------------------------------------------------------------------- #

  # Symlink Relative ( "dirFetcher" in `pacote' taxonomy )
  # NOTE: This fetcher triggers additional lifecycle routines that are not
  #       run for a regular "node_modules/<path>" entry.
  #       We do not trigger life-cycle here, and defer to the caller.
  # The difference between "paths" and "symlinks" in NPM/pacote taxonomy is that
  # "symlinks" represent out of tree projects ( external projects ) which will
  # be processed under the assumption that they are raw source trees.
  # These are more similar to `git' sources insofar as they are conditionally
  # built when a `.scripts.build' routine is present ( or "prepare" routine ).
  # Where they differ from `git' checkouts is largely irrelevant for our
  # purposes but since it took my ages to figure out I'll share:
  # Git sources will only be processed a single time and are cached for reuse;
  # Symlink sources are re-checked when referenced to see if they need to be
  # rebuilt - this is very similar to how Nix treats dirty git checkouts.
  # In practice we treat paths and symlinks identically since Nix abstracts away
  # the practical differences that NPM and `pacote' have to deal with.
  plock2LinkFetchArgs' = impure: {
    cwd ? ( if impure then builtins.getEnv "PWD" else
            throw ( "(plock2LinkFetchArgs) Cannot determine " +
                    "CWD to resolve link URIs" ) )
  }: { resolved, ... }: plock2PathFetchArgs { inherit cwd; key = resolved; };


# ---------------------------------------------------------------------------- #

  # Returns the appropriate fetcher arg-set given a `plock(V2)' entry.
  plock2EntryFetchArgs' = impure: cwd: key: entry: let
    type = typeOfEntry entry;
    cwda = if cwd == null then {} else { inherit cwd; };
    pathArgs = ( { inherit key; } // cwda );
  in if type == "symlink" then plock2LinkFetchArgs' impure cwda entry   else
     if type == "path"    then plock2PathFetchArgs' impure pathArgs     else
     if type == "git"     then plock2GitFetchArgs' impure entry         else
     if type == "registry-tarball" then plock2TbFetchArgs' impure entry else
     if type == "source-tarball" then plock2TbFetchArgs' impure entry   else
     throw "(plock2EntryFetchArgs) Unrecognized entry type for: ${key}";


# ---------------------------------------------------------------------------- #

  # Attempts to guess `impure' setting.
  plock2TbFetchArgs    = plock2TbFetchArgs'    ( builtins ? currentTime );
  plock2GitFetchArgs   = plock2GitFetchArgs'   ( builtins ? currentTime );
  plock2PathFetchArgs  = plock2PathFetchArgs'  ( builtins ? currentTime );
  plock2LinkFetchArgs  = plock2LinkFetchArgs'  ( builtins ? currentTime );
  plock2EntryFetchArgs = plock2EntryFetchArgs' ( builtins ? currentTime );


# ---------------------------------------------------------------------------- #

  # Wrappers for builtin fetchers so that routines like `callPackages',
  # `lib.functionArgs', and `lib.makeOverridable' with work with them.
  # This is particularly important for `callPackage' with `builtins.fetchTree'.
  # Since these are not system dependant they

  callWith = {
    __functionArgs
  , __thunk ? {}
  , __fetcher
  #, __functor
  , ...
  } @ self: args: let
    args' = builtins.intersectAttrs __functionArgs ( __thunk // args );
  in lib.makeOverridable __fetcher args';

  # Wraps `fetchurlDrv'.
  # Since it isn't technically a builtin this wrapper is really just for
  # consistency with the other wrappers.
  # NOTE: You can't avoid unpacking in a platform dependant way in pure mode;
  # with that in mind the best we can do is fetch the tarball and pass a message
  # for builders to handle later.
  # We add the field `needsUpack = true' in pure mode.
  # In practice the best thing to do is to override this fetcher in pure mode
  # in your config.
  fetchurlDrvW = {
    #__functionArgs = hashFields // { name = true; url = false; };
    __functionArgs = ( lib.functionArgs lib.fetchurlDrv ) // {
      unpackAfter = true;  # Allows acting as a `tarballFetcher' in pure mode.
    };
    __thunk   = { unpack = false; unpackAfter = false; };
    __fetcher = lib.fetchurlDrv;
    __functor = self: args: let
      args' = let
        rargs = removeAttrs args ["unpackAfter"];
      in rargs // ( plock2TbFetchArgs rargs ).lib.fetchurlDrv;
      # Hide `unpackAfter' for real call.
      fetched = callWith ( self // {
        __functionArgs = removeAttrs self.__functionArgs ["unpackAfter"];
      } ) args';
      upa = builtins.fetchTarball { url = fetched.outPath; };
      unpackedFull = upa // { passthru.tarball = fetched; };
      doUnpackAfter = args.unpackAfter or self.__thunk.unpackAfter;
    in if doUnpackAfter then unpackedFull else fetched;
  };

  fetchurlUnpackDrvW = fetchurlDrvW // { __thunk.unpackAfter = true; };
  fetchurlNoteUnpackDrvW = fetchurlDrvW // {
    __functor = self: args:
      ( fetchurlDrvW.__functor self args ) // { needsUnpack = true; };
  };

  fetchGitW = {
    __functionArgs = {
      url     = false;
      name    = true;
      rev     = true;
      ref     = true;
      allRefs = true;
      shallow = true;
    };
    __thunk   = {
      ref        = "HEAD";
      submodules = false;
      shallow    = false;
      allRefs    = true;
    };
    __fetcher = builtins.fetchGit;
    __functor = self: args: let
      args' = args // ( plock2GitFetchArgs args ).builtins.fetchGit;
    in callWith self args';
  };

  # Wraps `builtins.path' and automatically filters out `node_modules/' dirs.
  # You can always wipe out or redefine that filter.
  # When using this with relative paths you need to set `cwd' to an absolute
  # path before calling:
  #   ( lib.pathW // { __thunk.cwd = toString ./../../foo; }  ) "./baz"
  #   or
  #   let fetchFromFoo = lib.pathW // { __thunk.cwd = toString ./../../foo; };
  #   in builtins.mapAttrs
  #
  # NOTE: If you pass an attrset with `outPath' or `path.outPath' as your args,
  # this is essentially an accessor that just returns that `outPath'.
  # The rationale for this is that it allows users to set `sourceInfo.path' to
  # a derivation using `sourceInfo.type = "path";' as a way to override sources
  # in `metaEnt' data ( this still applies `filter' if it is defined ).
  # If `outPath' is an arg no filtering is applied; the path it taken "as is",
  # which helps avoid needlessly duplicating store paths.
  pathW = {
    __functionArgs = {
      name      = true;
      path      = true;
      resolved  = true;
      filter    = true;
      recursive = true;
      sha256    = true;
      outPath   = true;
      cwd       = false;
    };
    __thunk = {
      filter = name: type: let
        bname = baseNameOf name;
      in ( type == "directory" -> ( bname != "node_modules" ) );
    };
    __fetcher = args: {
      outPath = args.outPath or ( builtins.path ( removeAttrs args ["cwd"] ) );
    };
    __functor = self: {
      path ? args.resolved or args.outPath or ""
      , ...
    } @ args: let
      # NOTE: `path' may be a set in the case where it is a derivation; so in
      # order to pass to `builtins.path' we need to make it a string.
      args' = if lib.libpath.isAbspath ( path.outPath or path ) then args else {
        path = "${args.cwd or self.__thunk.cwd}/${path}";
      };
    in callWith self args';
  };

  fetchTreeW = {
    __functionArgs = {
      # Common
      type    = false;
      narHash = true;
      name    = true;
      # `fetchTarball' mode
      url     = true;
      # `fetchGit' mode
      rev     = true;
      ref     = true;
      allRefs = true;
      shallow = true;
      # `path' mode
      path    = true;
    };
    # Copy the thunk from other fetchers.
    __thunk = fetchGitW.__thunk;
    __fetcher = builtins.fetchTree;
    __functor = self: { type, ... } @ args: let
      fa' =
        if type == "path" then { path = false; } else
        if type == "git"  then fetchGitW.__functionArgs else
        if type == "tarball" then {
          url     = false;
          narHash = lib.flocoConfig.enableImpureFetchers;
        } else throw "Unrecognized `fetchTree' type: ${type}";
      fc = { type = false; narHash = true; };
      args' = args // ( {
        path    = plock2PathFetchArgs ( removeAttrs args ["type"] );
        tarball = plock2TbFetchArgs   ( removeAttrs args ["type"] );
        git     = plock2GitFetchArgs  ( removeAttrs args ["type"] );
      } ).${type}.builtins.fetchTree;
      # Make `__functionArgs' reflect the right args for filtering by type.
    in callWith ( self // { __functionArgs = fc // fa'; } ) args';
  };


# ---------------------------------------------------------------------------- #

  # A wrapper for your wrapper.
  # This pulls fetchers from your `flocoConfig', and routes inputs to the
  # proper fetcher.
  # Largely relies on `entSubtype', `entries.plock', and `sourceInfo' data.
  # You likely want to create a fetcher for each `lockDir'/`metaSet'; but it
  # will check `entries.plock.lockDir' as a fallback.
  #
  # The following examples will handle `cwd' properly for "dir"/path and
  # "link"/symlink fetchers:
  #   let
  #     lockDir      = toString ../../foo;
  #     plock        = lib.importJSON' "${lockDir}/package-lock.json";
  #     flocoFetcher = lib.mkFlocoFetcher { cwd = lockDir; };
  #   in builtins.mapAttrs ( _: flocoFetcher ) plock.packages
  #
  # With `metaSet' it'll figure out `cwd' from the `entries.plock' attrs.
  #   let
  #     flocoFetcher = lib.mkFlocoFetcher {};
  #     metaSet = lib.libmeta.metaSetFromPlockV3 { lockDir = toString ./.; }
  #   in builtins.mapAttrs ( _: flocoFetcher ) metaSet.__entries
  #
  mkFlocoFetcher = {
    tarballFetcher ? if enableImpureFetchers then tarballFetcherImpure
                                             else tarballFetcherPure
  , tarballFetcherPure   ? fetchers.tarballFetcherPure
  , tarballFetcherImpure ? fetchers.tarballFetcherImpure
  , urlFetcher  ? fetchers.urlFetcher
  , gitFetcher  ? fetchers.gitFetcher
  , dirFetcher  ? fetchers.dirFetcher
  , linkFetcher ? fetchers.linkFetcher
  , fetchers    ? lib.recursiveUpdate lib.libcfg.defaultFlocoConfig.fetchers
                                      ( flocoConfig.fetchers or {} )
  , flocoConfig ? lib.flocoConfig
  , enableImpureFetchers ? flocoConfig.enableImpureFetchers
  , cwd            ? throw "You must set cwd for relative path fetching"
  } @ cargs: args: let
    fetchers = {
      # We don't carry pure/impure past argument handling because we're actually
      # going to fetch.
      inherit
        urlFetcher
        gitFetcher
        dirFetcher
        linkFetcher
        tarballFetcher
      ;
    };
    sourceInfo = if args ? entSubtype then args else args.sourceInfo or {};
    plent = args.entries.plock or args;
    atype = args.type or sourceInfo.type or null;
    type  = if atype != null then atype else
            if builtins.elem entSubtype ["registry-tarball" "source-tarball"]
            then "tarball" else entSubtype;
    entSubtype = let
      fromArgs = args.entSubtype or sourceInfo.entSubtype or null;
      type'    = if atype == "tarball" then "registry-tarball" else atype;
      guess    = typeOfEntry plent;
      fromT    = if atype != null then type' else guess;
    in if fromArgs != null then fromArgs else fromT;
    cwd' = if ! ( builtins.elem type ["path" "symlink"] ) then {} else
      if ( args ? cwd ) || ( cargs ? cwd )
      then { __thunk.cwd = args.cwd or cargs.cwd; }
      else if ( plent ? lockDir ) then { __thunk.cwd = plent.lockDir; } else {};
    fetcher = ( fetcherForType fetchers entSubtype ) // cwd';
    args' = if sourceInfo != {} then sourceInfo else plent;
  in fetcher ( { inherit type; } // args' );


# ---------------------------------------------------------------------------- #

in {
  inherit
    typeOfEntry
    fetcherForType
    plockEntryHashAttr

    plock2TbFetchArgs'    plock2TbFetchArgs
    plock2GitFetchArgs'   plock2GitFetchArgs
    plock2PathFetchArgs'  plock2PathFetchArgs
    plock2LinkFetchArgs'  plock2LinkFetchArgs
    plock2EntryFetchArgs' plock2EntryFetchArgs

    fetchGitW fetchTreeW pathW
    fetchurlDrvW fetchurlUnpackDrvW fetchurlNoteUnpackDrvW
    mkFlocoFetcher
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
