# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt  = lib.ytypes // lib.ytypes.Prim // lib.ytypes.Core;
  plt = yt.NpmLock.Structs // yt.NpmLock;

# ---------------------------------------------------------------------------- #
#
# Abstracts builtin fetchers for compatibility with `nixpkgs' forms, and
# identifies the correct fetcher for various types of Node.js/NPM source trees.
#
# ---------------------------------------------------------------------------- #

  # Given a `resolved' URI from a `package-lock.json', discern its
  # `builtins.fetchTree' source "type".
  identifyResolvedType = r: let
    isPath = ( ! ( lib.liburi.Url.isType r ) ) &&
             ( yt.NpmLock.Strings.relative_file_uri.check r );
    isGit  = let
      data = ( lib.liburi.Url.fromString r ).scheme.data or null;
    in ( lib.liburi.Url.isType r ) && ( data == "git" );
    isFile = lib.libstr.isTarballUrl r;
  in if isPath then { path = r; } else
     if isGit  then { git = r; } else
     if isFile then { file = r; } else
     throw "(identifyResolvedType) unable to determine type of ${r}";


# ---------------------------------------------------------------------------- #

  # Given a package entry from a `package-lock.json(v[23])', return one of
  # "file", "path", or "git" indicating the source type.
  identifyPlentSourceType = ent: let
    tagged = lib.libtypes.discrTypes {
      path = yt.NpmLock.Structs.pkg_path_v3;
      git  = yt.NpmLock.Structs.pkg_git_v3;
      file = yt.NpmLock.Structs.pkg_tarball_v3;
    } ent;
  in if ! ( ent ? resolved ) then "path" else  # FIXME type is broken
     builtins.head ( builtins.attrNames tagged );


# ---------------------------------------------------------------------------- #

  # XXX: I'm unsure of whether or not this works with v1 locks.
  plockEntryHashAttr = {
    __innerFunction = entry: let
      integrity2Sha = integrity: let
        m = builtins.match "(sha(512|256|1))-(.*)" integrity;
        shaSet = { ${builtins.head m} = builtins.elemAt m 2; };
      in if m == null then { hash = integrity; } else shaSet;
      fromInteg = integrity2Sha entry.integrity;
    in if entry ? integrity then fromInteg else
       if entry ? sha1      then { inherit (entry) sha1; } else {};
    __functionArgs = {
      sha1      = true;
      sha256    = true;
      sha512    = true;
      integrity = true;
      hash      = true;
      narHash   = true;
    };
    __functor = self: self.__innerFunction;
  };


# ---------------------------------------------------------------------------- #

  # FIXME: move these

  Strings = {
    filename = yt.restrict "filename" ( lib.test "[^/\\]+" ) yt.string;
    abspath  = yt.restrict "abspath" ( lib.test "/.*" ) yt.string;
  };

  Eithers = {
    abspath = yt.either yt.path Strings.abspath;
  };

  Sums.hash = yt.sum {
    md5       = yt.Strings.md5_hash;
    sha1      = yt.Strings.sha1_hash;
    sha256    = yt.Strings.sha256_hash;
    narHash   = yt.Strings.sha256_hash;  # FIXME: this uses a different charset
    sha512    = yt.Strings.sha512_hash;
    integrity = yt.eitherN [
      yt.Strings.sha1_sri
      yt.Strings.sha256_sri
      yt.Strings.sha512_sri
    ];
  };

  # TODO: types
  #   abspath
  #   filename
  #   barename ( no extensions )
  #   relpath  ( string + struct )
  #   path     ( sumtype )
  #   file     ( sumtype )
  #   md5 sri
  #   narHash  ( check charset )
  #   git reponame
  #   fetchTree sourceInfo


# ---------------------------------------------------------------------------- #

  # Tarball Fetcher Argsets.

  nixpkgsFetchurlArgs = {
    name          = true;   # defaults to url basename
    url           = false;  # real one is optional but only with `urls = [...]'
    executable    = true;
    recursiveHash = true;   # for a single file choose "false"
    # One of the following
    sha1          = true;
    sha256        = true;
    sha512        = true;
    hash          = true;
    md5           = true;
    # ...
  };

  nixpkgsFetchzipArgs      = { url = false; sha256 = false; };
  builtinsFetchTarballArgs = { url = false; sha256 = false; };
  # XXX: accepts as a string not an attrset.
  builtinsFetchurlArgs = { url = false; };

  # This super-set can support any tarball/file fetcher.
  genericTarballArgs = {
    name  = Strings.filename;
    type  = yt.enum ["file" "tarball"];
    url   = yt.Uri.Strings.uri_ref;
    flake = yt.option yt.bool;
    inherit (Sums) hash;
    unpack     = yt.option yt.bool;
    executable = yt.option yt.bool;
  };


# ---------------------------------------------------------------------------- #

  nixpkgsFetchgitArgs = {
    name = true;
    url  = false;
    # Options
    branchName = true;
    deepClone  = true;
    fetchLFS   = true;
    fetchSubmodules = true;
    leaveDotGit     = true;
    sparseCheckout  = true;
    # One of
    hash   = true;
    sha256 = true;
    md5    = true;
    rev    = true;
    # ...
  };

  builtinsFetchgitArgs = {
    url     = false;
    rev     = true;  # can be parsed from URL
    allRefs = true;  # Defaults to false
    shallow = true;  # "deepClone"
  };


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

  genericGitArgs = {
    name  = Strings.filename;  # dirname
    type  = yt.enum ["git" "github" "sourcehut"];
    url   = yt.FlakeRef.Strings.git_ref;
    flake = yt.option yt.bool;
    inherit (yt.Git) rev ref;
    inherit (Sums) hash;
    allRefs    = yt.bool;
    submodules = yt.bool;  # fetchSubmodules
    shallow    = yt.bool;  # deepClone?
    repo       = yt.Git.Strings.ref_component;
    owner      = yt.Git.Strings.owner;
  };

  plockEntryToGitArgs = let
    inner = { resolved, ... }: let
      parsed = lib.liburi.parseFullUrl resolved;
      repo   = lib.yank "(.*)\\.git" ( baseNameOf parsed.path );
      owner  = baseNameOf ( dirOf parsed.path );
    in {
      inherit repo owner;
      name = repo;
      url  = resolved;
      rev  = parsed.fragment;
      type = if parsed.authority == "git@github.com" then "github" else
             "git";
      allRefs = true;
    };
  # FIXME: return type
  in defun [yt.NpmLock.Structs.pkg_git_v3 ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  builtinsPathArgs = {
    name   = Strings.filename;
    path   = yt.either Strings.abspath yt.path;
    filter = yt.function;
  };

  genericPathArgs = {
    inherit (builtinsPathArgs) name path filter;
    type  = yt.enum ["path"];
    flake = yt.bool;
    url   = yt.FlakeRef.Strings.path_ref;
    # I made these up
    basedir = Eithers.abspath;
    relpath = yt.NpmLock.relative_file_uri;  # FIXME: move this type
  };


# ---------------------------------------------------------------------------- #

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
    __thunk = {
      unpack           = false;
      unpackAfter      = false;
      allowSubstitutes = true;
    };
    __fetcher = lib.fetchurlDrv;
    __functor = self: args: let
      args' = removeAttrs args ["unpackAfter"];
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


# ---------------------------------------------------------------------------- #

  fetchGitW = {
    __functionArgs = {
      url        = false;
      name       = true;
      rev        = true;
      ref        = true;
      allRefs    = true;
      shallow    = true;
      submodules = true;
    };
    __thunk   = {
      ref        = "HEAD";
      submodules = false;
      shallow    = false;
      allRefs    = true;
    };
    __innerFunction = builtins.fetchGit;
    __processArgs = self: args:
      if yt.NpmLock.Structs.pkg_git_v3.check args
      then ( removeAttrs self.__thunk ["ref"] ) // ( plockEntryToGitArgs args )
      else self.__thunk // args;
    __functor = self: args:
      lib.apply self.__innerFunction ( self.__processArgs self args );
  };


# ---------------------------------------------------------------------------- #

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
      in type == "directory" -> ( bname != "node_modules" );
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


# ---------------------------------------------------------------------------- #

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
    inherit (fetchGitW) __thunk;
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
      args' = args // { inherit type; };
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
    tarballFetcher ? fetchers.tarballFetcher
  , fileFetcher    ? fetchers.fileFetcher
  , gitFetcher     ? fetchers.gitFetcher
  , pathFetcher    ? fetchers.pathFetcher
  , fetchers       ? lib.recursiveUpdate lib.libcfg.defaultFlocoConfig.fetchers
                                         ( flocoConfig.fetchers or {} )
  , flocoConfig          ? lib.flocoConfig
  , enableImpureFetchers ? flocoConfig.enableImpureFetchers
  , allowSubstitutes     ? flocoConfig.allowSubstitutedFetchers or true
  , cwd                  ? throw "You must set cwd for relative path fetching"
  } @ cargs: args: let
    fetchers = {
      # We don't carry pure/impure past argument handling because we're actually
      # going to fetch.
      inherit
        pathFetcher
        gitFetcher
        tarballFetcher
        fileFetcher
      ;
    };
    sourceInfo = if args ? type then args else args.sourceInfo or {};
    plent = if yt.NpmLock.package.check args then args else
            args.entries.plock;
    type = args.type or sourceInfo.type or ( identifyPlentSourceType plent );
    cwd'  =
      if type != "path" then {} else
      if ( args ? cwd ) || ( cargs ? cwd ) then {
        __thunk.cwd = args.cwd or cargs.cwd;
      } else if ( plent ? lockDir ) then { __thunk.cwd = plent.lockDir; } else
      {};
    fetcher = fetchers."${type}Fetcher" // cwd';
    args' = if sourceInfo != {} then sourceInfo else plent;
    fetched = fetcher ( { inherit type; } // args' );
  # Don't refetch if `outPath' is defined ( basically only happens for flakes ).
  in if sourceInfo ? outPath then sourceInfo else fetched;


# ---------------------------------------------------------------------------- #

in {
  inherit
    identifyResolvedType
    identifyPlentSourceType
    plockEntryHashAttr

    plockEntryToGitArgs

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
