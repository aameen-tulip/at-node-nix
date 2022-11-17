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

  # FIXME: move to `laika'

  # Return configured `laika' fetchers with explicitly specified settings.
  # These differ from the default `lib.libfetch' routines which may depend on
  # `laikaConfig' or runtime context.
  laikaFetchersConfigured = { pure, typecheck }: let
    pf = if pure      then "Pure"  else "Impure";
    tf = if typecheck then "Typed" else "Untyped";
  in lib.libfetch."${pf}${tf}";


# ---------------------------------------------------------------------------- #

  # Fixup return value from `builtins.fetchTree' to align with `floco*Fetch'
  # interfaces ( `{ fetchInfo, sourceInfo, outPath, type, passthru, meta }' ).
  flocoProcessFTResult = type: fetchInfo: sourceInfo:
    assert fetchInfo ? type -> type == fetchInfo.type;
    {
      _type = "fetched";
      type  = if type == "github" then "git" else
              if type == "tarball" then "file" else
              type;
      inherit fetchInfo sourceInfo;
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
  in builtins.traceVerbose msg result;


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

  flocoGitFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: let
    lfc = laikaFetchersConfigured { inherit typecheck pure; };
  in lfc.fetchGitW // {
      __functionMeta = {
        name      = "flocoGitFetcher";
        from      = "at-node-nix#lib.libfetch";
        innerName = "laika#lib.libfetch.<fetchTreeGithubW|fetchGitW>";
        signature = [yt.any yt.FlocoFetch.fetched];
        properties = {
          family  = "git";
          builtin = true;
          inherit typecheck pure;
        };
      };
      __innerFunction = args:
        if ( args.type or "git" ) == "github"
        then lfc.fetchTreeGithubW args
        else lfc.fetchGitW args;
      __functionArgs = let
        # Accept all genericGitArgFields as optionals
        tfields = builtins.mapAttrs ( _: _: true )
                                    lib.libfetch.genericGitArgFields;
      in tfields // { resolved = true; };
      __thunk       = lfc.fetchGitW.__thunk // { allRefs = true; };
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

  # NOTE: works for either "file" or "tarball".
  # You can pick a specialized form using the `postFn' arg.
  # I recommend `asGeneric*ArgsImpure' here since those routines
  # doesn't use a real type checker.
  # They just have an assert that freaks out if you're missing a hash field.
  # Our inner fetchers will catch that anyway so don't sweat it.
  plockEntryToGenericUrlArgs' = {
    postFn    ? lib.libfetch.asGenericUrlArgsImpure
  , typecheck ? false
  }: let
    inner = {
      resolved
    , sha1_hash ? plent.sha1 or null
    , integrity ? null  # Almost always `sha512_sri` BUT NOT ALWAYS!
    , ...
    } @ plent: let
      rough   = { url = resolved; inherit sha1_hash integrity; };
      args    = lib.filterAttrs ( _: x: x != null ) rough;
    in postFn args;
    rtype = let
      # Typecheck generic arg fields ( optional ).
      cond = x: let
        # Collect matching typecheckers and run them as we exit.
        # The outer checker can just focus on fields.
        tcs = builtins.intersectAttrs x lib.libfetch.genericUrlArgFields;
        proc = acc: f: acc && ( tcs.${f}.check x.${f} );
      in builtins.foldl' proc true ( builtins.attrNames tcs );
    in if ! typecheck then yt.any else
       yt.restrict "fetchInfo:generic:url:rough" cond ( yt.attrs yt.any );
  in yt.defun [yt.NpmLock.Structs.pkg_tarball_v3 rtype] inner;


# ---------------------------------------------------------------------------- #

  # Common core shared by `flocoFileFetcher' and `flocoTarballFetcher'.
  # This aligns with NPM's `fileFetcher' in `pacote', except that NPM doesn't
  # split the fetch/unpack processes into two parts.
  # In our case we /can/ and sometimes want to, so we have two distinct fetchers
  # for each flow.
  flocoUrlFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: let
    lfc = laikaFetchersConfigured { inherit typecheck pure; };
    loc = "at-node-nix#lib.libfetch.flocoUrlFetcher";
  in {
    __functionMeta = {
      name      = "flocoUrlFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.<fetchTreeW|fetchurlDrvW>";
      signature = [yt.any yt.FlocoFetch.fetched];
    };

    __functionArgs = {
      type       = true;
      url        = true;
      unpack     = true;
      resolved   = true;
      integritry = true;
      sha1       = true;
      narHash    = true;
    };

    # You can set the tie breaker for cases when either fetcher could be used.
    # In practice this will almost only be relevant in impure mode, but there's
    # definitely cases where you want to set it.
    __thunk = { preferFetchTree = true; };

    __innerFunction = if pure then lfc.fetchurlDrvW else lfc.fetchTreeW;

    __pickFetcher = self: args: let
      canUseFetchTree =
        ( builtins.elem ( args.type ) ["file" "tarball"] ) &&
        ( ( ! pure ) || ( args ? narHash ) );
      # We need some hash attribute
      canUseFetchurlDrv =
        builtins.any yt.Hash.hash.check ( builtins.attrValues args );
      forFetchTree = if args.type == "file" then lfc.fetchTreeFileW else
                     lfc.fetchTreeTarballW;
      canUseAny = canUseFetchTree && canUseFetchurlDrv;
      preferred =
        if ( args.preferFetchTree or false ) then lfc.fetchTreeW else
        lfc.fetchurlDrvW;
    in if canUseAny then preferred else
       if canUseFetchTree then forFetchTree else
       if canUseFetchurlDrv then lfc.fetchurlDrvW else
       throw "(${loc}): Args are not suitable for any available fetcher";

    __processArgs = self: x: let
      plArgs = plockEntryToGenericUrlArgs' {
        inherit typecheck;
        postFn = lib.libfetch.asGenericUrlArgsImpure;
      } ( self.__thunk // x );
      rawArgs = lib.libfetch.asGenericUrlArgsImpure ( self.__thunk // x );
      args    = if x ? resolved then plArgs else rawArgs;
      fetcher = self.__pickFetcher self ( self.__thunk // args );
    in ( lib.canPassStrict fetcher args ) // { inherit fetcher; };

    # If we hit `fetchurlDrvW' we won't have a `sourceInfo' return.
    # XXX: honestly we do more post-processing in `__functor'
    __postProcess = result:
      if yt.SourceInfo.sourceInfo.check result then result else {
        inherit (result) outPath;
        # In impure mode we can fill missing `narHash'.
        # This is sometimes used to output metadata to stash it for a later
        # pure run.
        narHash = let
          ft = builtins.fetchTree { type = "path"; path = result.outPath; };
        in if yt.Hash.narHash.check result.outputHash
           then result.outputHash
           else if ! pure then ft.narHash else null;
      };

    __functor = self: x: let
      argt = if typecheck then builtins.head self.__functionMeta.signature
                          else ( y: y );
      rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                          else ( y: y );
      args       = self.__processArgs self x;
      fetchInfo  = argt ( removeAttrs args ["fetcher"] );
      result     = args.fetcher fetchInfo;
      sourceInfo = self.__postProcess result;
      wasFT = fetchInfo ? type;
      fetched = {
        _type = "fetched";
        type  = "file";
        fetchInfo = fetchInfo // {
          type = if fetchInfo.unpack or false then "tarball" else "file";
        };
        inherit (sourceInfo) outPath;
        sourceInfo = if sourceInfo.narHash != null then sourceInfo else
                     removeAttrs sourceInfo ["narHash"];
        passthru = ( if ! wasFT then { drv = result; } else {} ) // {
          fetcher = if wasFT then lfc.fetchTreeW else lfc.fetchurlDrvW;
          unpacked =
            if fetchInfo ? type then fetchInfo.type == "tarball" else
            fetchInfo.unpack or false;
        };
      };
    in rslt fetched;
  };


# ---------------------------------------------------------------------------- #

  # NOTE: in `passthru' the `fetcher' field will be `fetchTreeW' not
  # `fetchTreeTarballW' beacuse it is set by the wrapped function.
  flocoTarballFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: {
    __functionMeta = {
      name      = "flocoTarballFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "at-node-nix#lib.libfetch.flocoUrlFetcher";
      signature = [yt.any yt.FlocoFetch.fetched];
    };
    __functionArgs = {
      type       = true;
      url        = true;
      resolved   = true;
      integritry = true;
      sha1       = true;
      narHash    = true;
    };
    inherit (flocoUrlFetcher' { inherit typecheck pure; }) __thunk;
    __innerFunction = flocoUrlFetcher' { inherit typecheck pure; };
    __processArgs = self: x: let
      ta = if builtins.isString x then { type = "tarball"; url = x; } else
           { type = "tarball"; } // x;
    in self.__thunk // ta;
    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };

  flocoTarballFetcherUntyped = flocoTarballFetcher' { typecheck = false; };
  flocoTarballFetcherTyped   = flocoTarballFetcher' { typecheck = true; };
  flocoTarballFetcher        = flocoTarballFetcher' {};


# ---------------------------------------------------------------------------- #

  flocoFileFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: {
    __functionMeta = {
      name      = "flocoFileFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "at-node-nix#lib.libfetch.flocoUrlFetcher";
      signature = [yt.any yt.FlocoFetch.fetched];
    };
    __functionArgs = {
      type       = true;
      url        = true;
      resolved   = true;
      integritry = true;
      sha1       = true;
      narHash    = true;
    };
    inherit (flocoUrlFetcher' { inherit typecheck pure; }) __thunk;
    __innerFunction = flocoUrlFetcher' { inherit typecheck pure; };

    __processArgs = self: x: let
      ta = if builtins.isString x then { type = "file"; url = x; } else
           { type = "file"; } // x;
    in self.__thunk // ta;

    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
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
  flocoPathFetcher' = { typecheck ? false, pure ? ! lib.inPureEvalMode }: let
    lfc = laikaFetchersConfigured { inherit typecheck pure; };
  in {
    __functionMeta = {
      name      = "flocoPathFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.pathW";
      properties =
        flocoPathFetcher.__innerFunction.__functionMeta.properties // {
          inherit typecheck pure;
        };
      signature = [yt.any yt.FlocoFetch.fetched];
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
    __innerFunction = lfc.pathW;
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
      _type     = "fetched";
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

  # XXX: This basically just processes args and merged configs.
  mkFlocoFetchers' = {
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

    __functor = self: x: let
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
        if ! ( fetchersNoConf.pathFetcher.__functionArgs ? basedir )
        then fetchersNoConf
        else fetchersNoConf // {
          pathFetcher = fetchersNoConf.pathFetcher // {
            __thunk = fetchersNoConf.pathFetcher.__thunk // {
              basedir = x.basedir or null;  # Should throw internally if needed.
            };
          };
        };
    in { inherit typecheck pure fetchers; };
  };  # End `mkFlocoFetchers''`


# ---------------------------------------------------------------------------- #

  mkFlocoFetcher' = { fetchers, pure, typecheck }: {
    __functor = self: x: let
      pp = lib.generators.toPretty {};
      st =
        if x ? fetchInfo then identifyFetchInfoSourceType x.fetchInfo else
        if x ? type then identifyFetchInfoSourceType x else
        if yt.NpmLock.package.check x then identifyPlentSourceType x else
        if ( x._type or null ) == "metaEnt" then identifyMetaEntSourceType x
        else throw "flocoFetch: cannot discern source typeof : ${pp x}";
      ft = x.fetchInfo.type or x.type or st;
    in self."${ft}Fetcher" ( x.fetchInfo or x );
  } // fetchers;

  mkFlocoFetcher = {
    inherit (mkFlocoFetchers') __functionArgs;
    __processArgs   = self: mkFlocoFetchers';
    __innerFunction = mkFlocoFetcher';
    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    identifyResolvedType
    identifyPlentSourceType
    identifyFetchInfoSourceType
    identifyMetaEntSourceType

    plockEntryHashAttr

    plockEntryToGenericGitArgs
    plockEntryToGenericUrlArgs'

    flocoUrlFetcher'

    flocoGitFetcher'     flocoGitFetcherUntyped     flocoGitFetcherTyped
    flocoTarballFetcher' flocoTarballFetcherUntyped flocoTarballFetcherTyped
    flocoFileFetcher'    flocoFileFetcherUntyped    flocoFileFetcherTyped
    flocoPathFetcher'    flocoPathFetcherUntyped    flocoPathFetcherTyped
    flocoGitFetcher flocoTarballFetcher flocoFileFetcher flocoPathFetcher

    mkFlocoFetchers'
    mkFlocoFetcher
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
