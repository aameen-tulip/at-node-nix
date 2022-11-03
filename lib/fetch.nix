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

  # Given a `resolved' URI from a `package-lock.json', ROUGHLY discern its
  # `builtins.fetchTree' source "type".
  # NOTE: this is not exact.
  # For example, `git' may refer to either `git', `github', or `sourcehut'.
  # Selecting the correct fetcher for each subtype is deferred to the fetchers.
  # This rough approximation helps us limit the number of fetchers we require
  # users to define - at a minimum they must define at least the 3 named here.
  identifyResolvedType = r: let
    isPath = ( ! ( lib.liburi.Url.isType r ) ) &&
             ( yt.NpmLock.Strings.relative_file_uri.check r );
    isGit = let
      data = ( lib.liburi.Url.fromString r ).scheme.data or null;
    in ( lib.liburi.Url.isType r ) && ( data == "git" );
    isFile = yt.NpmLock.Strings.tarball_uri.check r;
  in if isPath   then { path = r; } else
     if isGit    then { git = r; } else
     if isFile   then { file = r; } else
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
  in builtins.head ( builtins.attrNames tagged );

  # FIXME: don't require `type'
  identifyFetchInfoSourceType = { type, ... } @ fetchInfo:
    if builtins.elem type ["git" "github" "sourcehut"] then "git" else
    if builtins.elem type ["file" "tarball"] then "file" else type;

  identifyMetaEntSourceType = { fetchInfo ? null, entries ? {}, ... } @ me:
    if fetchInfo != null then identifyFetchInfoSourceType fetchInfo else
    if ( entries.plent or null ) != null
    then identifyPlentSourceType entries.plent
    else throw "identifyMetaEntSourceType: Cannot discern 'sourceType'";


# ---------------------------------------------------------------------------- #

  # Essentially an optimized `tagHash'.
  # XXX: I'm unsure of whether or not this works with v1 locks.
  plockEntryHashAttr = {
    __innerFunction = entry:
      if entry ? integrity then lib.libenc.tagHash entry.integrity else
      if entry ? sha1      then { sha1_hash = entry.sha1; } else {};
    __functionArgs = { sha1 = true; integrity = true; };
    __functor = self: self.__innerFunction;
  };


# ---------------------------------------------------------------------------- #

  # path tarball file git github
  # NOTE: `fetchTree { type = "indirect"; id = "foo"; }' works!
  Enums.sourceType = let
    cond = x: ! ( builtins.elem x ["indirect" "sourcehut" "mercurial"] );
  in yt.restrict "floco" cond yt.FlakeRef.Enums.ref_type;

  Structs.fetched = yt.struct "fetchedSource" {
    type       = Enums.sourceType;
    outPath    = yt.FS.store_path;
    sourceInfo = yt.SourceInfo.sourceInfo;
    fetchInfo  = yt.attrs yt.any;
    passthru   = yt.option ( yt.attrs yt.any );
    meta       = yt.option ( yt.attrs yt.any );
  };

  # TODO: types
  #   barename ( no extensions )
  #   relpath  ( string + struct )
  #   path     ( sumtype )
  #   file     ( sumtype )


# ---------------------------------------------------------------------------- #

  # Fixup return value from `builtins.fetchTree' to align with `floco*Fetch'
  # interfaces ( `{ fetchInfo, sourceInfo, outPath, type, passthru, meta }' ).
  flocoProcessFTResult = type: fetchInfo: sourceInfo:
    assert fetchInfo ? type -> type == fetchInfo.type;
    {
      inherit type fetchInfo sourceInfo;
      inherit (sourceInfo) outPath;
    };

  # Generic `builtins.fetchTree' functor for `floco*Fetcher'.
  flocoFTFunctor = type: self: x: let
    fetchInfo  = self.__processArgs self x;
    sourceInfo = self.__innerFunction fetchInfo;
    result     = flocoProcessFTResult type fetchInfo sourceInfo;
    msg = ''
      flocoFetch(${type})
        inputs:     ${builtins.toJSON ( x.__serial or x )}
        fetchInfo:  ${builtins.toJSON fetchInfo}
        sourceInfo: ${builtins.toJSON ( removeAttrs sourceInfo ["outPath"] )}
    '';
  in builtins.deepSeq ( builtins.traceVerbose msg result ) result;


# ---------------------------------------------------------------------------- #

  # NOTE: the fetcher for `git' entries need to distinguish between `git',
  # `github', and `sourcehut' when processing these args.
  # They should not try to interpret the `builtins.fetchTree' type using
  # `identify(Resolved|PlentSource)Type' which conflates all three `git' types.
  # XXX: I'm not sure we can get away with using `type = "github";' unless we
  # are sure that we know the right `ref'/`branch'. Needs testing.
  plockEntryToGenericGitArgs = let
    inner = { resolved, ... } @ args: let
      inherit (lib.libfetch.parseGitUrl resolved) owner rev repo type ref;
      allRefs' = let
        bname        = baseNameOf ref;
        defaultBRefs = ["HEAD" "master" "main"];
        allRefs      = ! ( builtins.elem bname defaultBRefs );
      in if ( type == "github" ) || ( ref == null ) then {} else {
        inherit allRefs;
      };
      owner' = if builtins.elem owner [null "" "."] then {} else
               { inherit owner; };
      ref' = if ref == null then {} else { inherit ref; };
    in {
      inherit type repo rev;
      name = repo;
      # Simplify URL for processing as a struct.
      # `builtins.fetch[Tree]Git' gets pissed off if you include URI params in
      # the `url' string, it wants you to move them to attrs.
      # We strip off the `data' portion of the scheme, and drop any params or
      # fragments to get the "base" URL.
      # NOTE: the `lib.ytypes.NpmLock.pkg_git_v3' expects a `git+<TRANSPORT>://'
      # in the scheme, so keep that in mind if you serialize `fetchInfo' and
      # try to recycle any `resolved' URI -> type discriminators.
      url  = lib.yankN 1 "(git\\+)?([^?#]+).*" resolved;
    } // allRefs' // owner' // ref';
  in yt.defun [yt.NpmLock.Structs.pkg_git_v3
               lib.libfetch.genericGitArgsPure] inner;


# ---------------------------------------------------------------------------- #

  flocoProcessGitArgs = self: x: let
    rough =
      if yt.NpmLock.pkg_git_v3.check x then plockEntryToGenericGitArgs x else
      if x ? rev then x else
      plockEntryToGenericGitArgs ( x // { resolved = x.url or x.resolved; } );
    tas     = ( self.__thunk or {} ) // rough;
    type    = if lib.libfetch.isGithubUrl rough.url then "github" else "git";
    fetcher = if type == "github" then lib.libfetch.fetchTreeGithubW else
              lib.libfetch.fetchGitW;
    args = if type != "github" then tas else
           removeAttrs ( tas // { inherit type; } ) ["url"];
  in lib.canPassStrict fetcher args;


# ---------------------------------------------------------------------------- #

  flocoGitFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }:
    lib.libfetch.fetchGitW // {
      __functionMeta = {
        name      = "flocoGitFetcher";
        from      = "at-node-nix#lib.libfetch";
        innerName = "laika#lib.libfetch.<fetchTreeGithubW|fetchGitW>";
        signature = [yt.any Structs.fetched];
        properties = {
          # Inherit from wrapped
          pure = lib.libfetch.fetchGitW.__functionMeta.properties.pure &&
                lib.libfetch.fetchTreeGithubW.__functionMeta.properties.pure;
          family  = "git";
          builtin = true;
          inherit typecheck;
        };
      };
      __innerFunction = args:
        if ( args.type or "git" ) == "github"
        then lib.libfetch.fetchTreeGithubW args
        else lib.libfetch.fetchGitW args;
      __functionArgs = let
        # Accept all genericGitArgFields as optionals
        tfields = builtins.mapAttrs ( _: _: true )
                                    lib.libfetch.genericGitArgFields;
      in tfields // { resolved = true; };
      __thunk = lib.libfetch.fetchGitW.__thunk // { allRefs = true; };
      __processArgs = flocoProcessGitArgs;
      __functor     = self: x: let
        argt = if typecheck then builtins.head self.__functionMeta.signature
                            else ( y: y );
        rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                            else ( y: y );
        fetchInfo  = argt ( self.__processArgs self x );
        sourceInfo = self.__innerFunction fetchInfo;
        fetched = flocoProcessFTResult ( fetchInfo.type or "git" ) fetchInfo
                                                                   sourceInfo;
      in rslt fetched;
  };

  flocoGitFetcherUntyped = flocoGitFetcher' { typecheck = false; };
  flocoGitFetcherTyped   = flocoGitFetcher' { typecheck = true; };
  flocoGitFetcher        = flocoGitFetcher' {};


# ---------------------------------------------------------------------------- #

  # In impure mode we can use `builtins.fetchTree' which is backed by sha256, or
  # we can use it if `narHash' is given.
  # In impure mode we will use `fetchTree'.
  fetchTreeOrUrlDrv = {
    url       ? fetchInfo.resolved
  , resolved  ? null
  , hash      ? if integrity != null then integrity else ""
  , integrity ? fetchInfo.narHash or fetchInfo.sha1 or fetchInfo.sha256 or
                fetchInfo.sha512 or fetchInfo.md5 or null
  , sha1      ? null
  , type      ? "file"
  , narHash   ? null
  , pure      ? ! lib.inPureEvalMode
  , ...
  } @ fetchInfo: let
    ftLocked = ( fetchInfo ? narHash ) || ( ! pure );
    preferFt = ( fetchInfo ? type ) && ftLocked;
    nh' = if fetchInfo ? narHash then { inherit narHash; } else {};
    # Works in impure mode, or given a `narHash'. Uses tarball TTL. Faster.
    ft = ( lib.libfetch.fetchTreeW { inherit url type; } ) // nh';
    # Works in pure mode and avoids tarball TTL.
    drv = lib.libfetch.fetchurlDrvW {
      inherit url hash;
      unpack = type == "tarball";
    };
  in if preferFt then ft else drv;


# ---------------------------------------------------------------------------- #

  flocoTarballFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: {
    __functionMeta = {
      name = "flocoTarballFetcher";
      from = "at-node-nix#lib.libfetch";
      innerName = "at-node-nix#lib.libfetch.fetchTreeOrUrlDrv";
      signature = [yt.any Structs.fetched];
    };
    __functionArgs = lib.libfetch.fetchurlDrvW.__functionArgs // {
      type       = true;
      url        = true;
      resolved   = true;
      integritry = true;
      sha1       = true;
      narHash    = true;
    };
    __innerFunction = lib.libfetch.fetchTreeOrUrlDrv;
    __thunk = {};

    __processArgs = self: x: let
      pool = self.__thunk // {
        type = "tarball";
        url  = x.url or x.resolved;
        inherit pure;
      } // ( if x ? narHash then { inherit (x) narHash; } else {} );
    in builtins.intersectAttrs ( lib.functionArgs self.__innerFunction ) pool;
    # FIXME: should only wrap for `fetchTree'
    __functor = self: x: flocoFTFunctor "tarball" self x;
  };

  flocoTarballFetcherUntyped = flocoTarballFetcher' { typecheck = false; };
  flocoTarballFetcherTyped   = flocoTarballFetcher' { typecheck = true; };
  flocoTarballFetcher        = flocoTarballFetcher' {};


# ---------------------------------------------------------------------------- #

  flocoFileFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: {
    __functionMeta = {
      name      = "flocoFileFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.<fetchurlDrvW|fetchTreeFileW>";
      signature = [yt.any Structs.fetched];
    };
    __functionArgs =
      ( lib.functionArgs flocoFileFetcher.__innerFunction ) //
      ( lib.optionalAttrs pure {
          integrity = true;
          hash      = true;
          sha1      = true;
          resolved  = true;
        } );

    __innerFunction =
      if ! pure then { url, type, narHash ? null, ... } @ args: let
        fetchInfo  = builtins.intersectAttrs {
          url = false; type = false; narHash = true;
        } args;
        sourceInfo = lib.libfetch.fetchTreeFileW args;
      in {
        type = "file";
        fetchInfo = fetchInfo // { inherit (sourceInfo) narHash; };
        inherit sourceInfo;
        inherit (sourceInfo) outPath;
      } else lib.libfetch.fetchurlDrvW;

    __thunk = {};

    __processArgs = self: x: let
      args = {
        type = "file";
        url  = x.url or x.resolved;
        hash = x.hash or x.integrity or x.shasum or null;
      } // ( if x ? narHash then { inherit (x) narHash; } else {} );
      args' = self.__thunk // (
        if args.hash != null then args else removeAttrs args ["hash"]
      );
    in builtins.intersectAttrs ( lib.functionArgs self.__innerFunction ) args;

    __functor = self: x: let
      rsl = flocoFTFunctor "file" self x;
    in if rsl ? sourceInfo.sourceInfo then rsl.sourceInfo else rsl;
  };

  flocoFileFetcherUntyped = flocoFileFetcher' { typecheck = false; };
  flocoFileFetcherTyped   = flocoFileFetcher' { typecheck = true; };
  flocoFileFetcher        = flocoFileFetcher' {};


# ---------------------------------------------------------------------------- #

  # Wraps `builtins.path' and automatically filters out `node_modules/' dirs.
  # You can always wipe out or redefine that filter.
  # When using this with relative paths you need to set `basedir' to an absolute
  # path before calling:
  #   ( lib.flocoPathFetcher // {
  #       __thunk.basedir = toString ./../../foo; }
  #   ) "./baz"
  #   or
  #   let fetchFromPWD = lib.flocoPathFetcher // {
  #         __thunk.basedir = toString ./.;
  #       };
  #   in builtins.mapAttrs ( k: _: fetchFromPWD k ) ( builtins.readDir ./. );
  #
  # NOTE: If you pass an attrset with `outPath' or `path.outPath' as your args,
  # this is essentially an accessor that just returns that `outPath'.
  # The rationale for this is that it allows users to set `sourceInfo.path' to
  # a derivation using `sourceInfo.type = "path";' as a way to override sources
  # in `metaEnt' data ( this still applies `filter' if it is defined ).
  # If `outPath' is an arg no filtering is applied; the path it taken "as is",
  # which helps avoid needlessly duplicating store paths.
  flocoPathFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: {
    __functionMeta = {
      name      = "flocoPathFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.pathW";
      properties =
        flocoPathFetcher.__innerFunction.__functionMeta.properties // {
          inherit typecheck;
        };
      signature = [yt.any Structs.fetched];
    };
    # Add the arg `basedir'.
    __functionArgs = ( lib.functionArgs flocoPathFetcher.__innerFunction ) // {
      basedir = true;
    };
    __thunk = {
      # XXX: You likely want to set `basedir' here!
      filter = name: type: let
        bname = baseNameOf name;
      in ( type == "directory" -> ( bname != "node_modules" ) ) &&
         ( lib.libfilt.genericFilt name type );
    };
    __innerFunction = lib.libfetch.pathW;
    # Convert relative paths to absolute, and repackage returned store-path into
    # a `sourceInfo:path' struct.
    __processArgs = self: x: let
      # NOTE: `path' may be a set in the case where it is a derivation; so in
      # order to pass to `builtins.path' we need to make it a string.
      p = if builtins.isString x then x else
          x.path or x.resolved or x.outPath or "";
      # Coerce an abspath
      path = let
        msg = "You must provide `flocoPathFetcher.__thunk.basedir', or " +
              "pass `basedir' as an argument to fetch relative paths.";
        basedir = x.basedir or self.__thunk.basedir or ( throw msg );
      in if lib.libpath.isAbspath p then p else "${basedir}/${p}";
      # `lib.libstr.baseName' handles store-path basenames.
      name = x.name or ( lib.libfs.baseName p );
    in lib.canPassStrict self.__innerFunction
                         ( self.__thunk // { inherit name path; } );
    # Convert the store-path returned by `pathW' to a `fetched' struct.
    __processResult = self: args: outPath: let
      # `filter' is a function so it cannot be added to `fetchInfo' if we want
      # that record to be serialized.
      # Instead we stash it in `passthru'.
      # XXX: if users want to override args, and they had previously overridden
      # the filter they need to refer to `passthru' to actually reproduce the
      # original fetch with their overridden args.
      # In practice I think it's incredibly unlikely that anyone will need to.
      passthru' = if ! ( args ? filter ) then {} else {
        passthru = { inherit (args) filter; };
      };
    in {
      type      = "path";
      fetchInfo = removeAttrs args ["filter"];
      inherit outPath;
      sourceInfo = { inherit outPath; };
    } // passthru';
    # Entry point
    __functor = self: x: let
      argt = if typecheck then builtins.head self.__functionMeta.signature
                          else ( y: y );
      rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                          else ( y: y );
      args    = argt ( self.__processArgs self x );
      outPath = self.__innerFunction args;
      fetched = self.__processResult self args outPath;
    in rslt fetched;
  };

  flocoPathFetcherUntyped = flocoPathFetcher' { typecheck = false; };
  flocoPathFetcherTyped   = flocoPathFetcher' { typecheck = true; };
  flocoPathFetcher        = flocoPathFetcher' {};


# ---------------------------------------------------------------------------- #

  # A wrapper for your wrapper.
  # This pulls fetchers from your `flocoConfig', and routes inputs to the
  # proper fetcher.
  # Largely relies on `entSubtype', `entries.plock', and `sourceInfo' data.
  # You likely want to create a fetcher for each `lockDir'/`metaSet'; but it
  # will check `entries.plock.lockDir' as a fallback.
  #
  # The following examples will handle `basedir' properly for "dir"/path and
  # "link"/symlink fetchers:
  #   let
  #     lockDir      = toString ../../foo;
  #     plock        = lib.importJSON' "${lockDir}/package-lock.json";
  #     flocoFetcher = lib.mkFlocoFetcher { basedir = lockDir; };
  #   in builtins.mapAttrs ( _: flocoFetcher ) plock.packages
  #
  # With `metaSet' it'll figure out `basedir' from the `entries.plock' attrs.
  #   let
  #     flocoFetcher = lib.mkFlocoFetcher {};
  #     metaSet = lib.libmeta.metaSetFromPlockV3 { lockDir = toString ./.; }
  #   in builtins.mapAttrs ( _: flocoFetcher ) metaSet.__entries
  #
  mkFlocoFetcher = {

    __functionArgs = {
      flocoConfig      = true;
      fetchers         = true;

      tarballFetcher   = true;
      fileFetcher      = true;
      gitFetcher       = true;
      pathFetcher      = true;

      pure             = true;
      typecheck        = true;
      basedir          = true;
      allowSubstitutes = true;
    };

    __processArgs = _self: x: let
      flocoConfig = x.flocoConfig or lib.flocoConfig or {};
      args = flocoConfig.flocoFetchArgs // x;
      # FIXME: these two aren't currently enforced.
      pure             = args.pure or ( ! lib.inPureEvalMode );
      allowSubstitutes = args.allowSubstitues or true;
      typecheck        = args.typecheck or false;
      defaultFetchers = let
        fa = { inherit typecheck pure; };
      in {
        tarballFetcher = lib.libfetch.flocoTarballFetcher' fa;
        fileFetcher    = lib.libfetch.flocoFileFetcher'    fa;
        gitFetcher     = lib.libfetch.flocoGitFetcher'     fa;
        pathFetcher    = lib.libfetch.flocoPathFetcher'    fa;
      };
      fetchersNoConf = let
        pool = defaultFetchers // ( args.fetchers or {} ) // args;
      in builtins.intersectAttrs defaultFetchers pool;
      fetchers =
        if ! ( fetchersNoConf.pathFetcher ? __thunk.basedir )
        then fetchersNoConf
        else fetchersNoConf // {
          pathFetcher = fetchersNoConf.pathFetcher // {
            __thunk = fetchersNoConf.pathFetcher.__thunk // {
              basedir = x.basedir or null;  # Should throw internally if needed.
            };
          };
        };
    in { inherit typecheck fetchers; };

    __functor = self: x:
      self.__innerFunction ( self.__processArgs x );

    __innerFunction = { typecheck, fetchers }: {
      __functionMeta = {
        name = "flocoFetch";
        from = "at-node-nix#lib.libfetch";
        # Generate `innerName' from sub-fetchers' `__functionMeta.(name|from)'.
        innerName = let
          fromToString = f: ns: let
            getName  = fetcher: fetcher.__functionMeta.name or "?";
            namesToString = ns:
              if ( builtins.length ns ) == 1
              then getName ( builtins.head ns )
              else "<${builtins.concatStringsSep "|" ( map getName ns )}>";
            loc = if f == "_%NONE%_" then "" else f + ".";
          in loc + ( namesToString ns );
          fromStrings = let
            getFrom = fetcher: fetcher.__functionMeta.from or "_%NONE%_";
            froms   = builtins.groupBy getFrom ( builtins.attrValues fetchers );
          in builtins.attrValues ( builtins.mapAttrs fromToString froms );
        in builtins.concatStringsSep "|" fromStrings;
        signature  = [yt.any Structs.fetched];
        properties = {
          inherit typecheck;
          # Detect purity from sub-fetchers.
          pure = let
            isPure = fetcher: fetcher.__functionMeta.properties.pure or false;
          in builtins.all isPure ( builtins.attrValues fetchers );
          # Detect `builtin' property from sub-fetchers.
          builtin = let
            isBuiltin = fetcher:
              fetcher.__functionMeta.properties.builtin or false;
          in builtins.all isBuiltin ( builtins.attrValues fetchers );
          family = "node";
        };
      };

      inherit fetchers;

      __setPathFetcherBasedir = self: basedir:
        assert self.fetchers.pathFetcher ? __thunk.basedir;
        self // {
          fetchers = self.fetchers // {
            pathFetcher = self.fetchers.pathFetcher // {
              __thunk = self.fetchers.pathFetcher.__thunk // {
                inherit basedir;
              };
            };
          };
        };

      __fetchInfoFromArgs = self: x: let
        plent = let
          inherit (lib.ytypes.NpmLock.package) check;
        in if check x then x else
           if x ? entries.plent then x.entries.plent else null;
        type = let
          fromPlent = if plent == null then null else
                      lib.libfetch.identifyPlentSourceType plent;
          # FIXME: parse flake-ref/URI
          fromString =
            if builtins.isString x then identifyResolvedType x else null;
          loc = self.from + "." + self.name;
          pv  = lib.generators.toPretty {} x;
        in if fromPlent != null then fromPlent else
           if fromString != null then fromString else
           throw "(${loc}): Unable to discern fetchInfo type of: '${pv}'";
      in if x ? fetchInfo then x.fetchInfo else
         if builtins.elem type ["git" "github"] then flocoProcessGitArgs x else
         # FIXME
         x // { inherit type; };
         #if builtins.elem type ["file" "tarball"] then

      # FIXME: iterate over signatures with `check'
      __fetcherFromFetchInfo = self: { type, ... } @ fetchInfo: let
        field = if builtins.elem type ["git" "github"] then "gitFetcher" else
                "${type}Fetcher";
      in self.fetchers.${field} or throw "No such fetcher: ${field}";

      __processArgs = self: x: null;  # FIXME

    };
  };

  ##  # FIXME: a hot mess over here.
  ##  __innerFunction = fetchers: x: let
  ##    plent = if yt.NpmLock.package.check x then x else
  ##            x.entries.plock or null;
  ##    # Effectively these are our args.
  ##    fetchInfo = let
  ##      fallback = if plent == null then x else plent;
  ##    in x.fetchInfo or fallback;
  ##    # Determine the `flocoSourceType'.
  ##    type = x.type or fetchInfo.type or ( identifyPlentSourceType plent );
  ##    args = if builtins.isAttrs fetchInfo then { inherit type; } // fetchInfo
  ##                                         else fetchInfo;
  ##    # Select the right fetcher based on `type'.
  ##  in builtins.traceVerbose "using ${type}Fetcher"
  ##     ( lib.apply fetchers."${type}Fetcher" args );

  ##  __functor = self: x: self.__innerFunction self.fetchers x;

# ---------------------------------------------------------------------------- #

in {
  inherit
    identifyResolvedType
    identifyPlentSourceType
    plockEntryHashAttr

    plockEntryToGenericGitArgs

    flocoGitFetcher'     flocoGitFetcherUntyped     flocoGitFetcherTyped
    flocoTarballFetcher' flocoTarballFetcherUntyped flocoTarballFetcherTyped
    flocoFileFetcher'    flocoFileFetcherUntyped    flocoFileFetcherTyped
    flocoPathFetcher'    flocoPathFetcherUntyped    flocoPathFetcherTyped

    fetchTreeOrUrlDrv

    mkFlocoFetcher
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
