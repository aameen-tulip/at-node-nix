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
    throw "(fetcherForType) Unrecognized entry type: ${type}";


# ---------------------------------------------------------------------------- #

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
  plock2TbFetchArgs' = impure: { resolved, ... } @ entry: let
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
  plock2GitFetchArgs' = impure: { resolved, ... } @ entry: let
    # I'm pretty sure you can pass this "as is" to `fetchTree'.
    # I'm also pretty sure that Eelco implemented `fetchTree' and Flake refs
    # based on NPM's URIs to support Node.js at Target - the commonality is
    # uncanny even for NPM's extended URIs.
    #   0: protocol ( ssh, http(s), etc )
    #   1: host     ( git@github.com, github.com, gitlab.com, etc )
    #   2: owner
    #   3: repo
    #   4: rev
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
  , key # relative path
  }: let
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
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
