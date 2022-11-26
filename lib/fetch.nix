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

  defaultFlocoEnv = {
    pure      = lib.inPureEvalMode or true;
    typecheck = false;
    # TODO: ifd
  };


# ---------------------------------------------------------------------------- #

  # Given a `resolved' URI from a `package-lock.json', ROUGHLY discern its
  # `builtins.fetchTree' source "type".
  # NOTE: this is not exact.
  # For example, `git' may refer to either `git', `github', or `sourcehut'.
  # Selecting the correct fetcher for each subtype is deferred to the fetchers.
  # This rough approximation helps us limit the number of fetchers we require
  # users to define - at a minimum they must define at least the 3 named here.
  identifyResolvedFetcherFamily = resolved:
    lib.tagName ( lib.libtypes.discrTypes {
      git  = yt.NpmLock.Strings.git_uri;
      file = yt.NpmLock.Strings.file_uri;
      path = yt.NpmLock.Strings.path_uri;
    } resolved );


# ---------------------------------------------------------------------------- #

  # TODO: don't require `type', just use it as one of many fields that can be
  # used to infer.
  identifyFetchInfoFetcherFamily = fetchInfo: let
    pp = lib.generators.toPretty { allowPrettyValue = true; };
    fromType =
      if builtins.elem fetchInfo.type ["git" "github" "sourcehut"] then "git"
      else if builtins.elem fetchInfo.type ["file" "tarball"] then "file" else
      fetchInfo.type;
  in if fetchInfo ? type then fromType else
     if fetchInfo ? path then "path" else
     if fetchInfo ? rev  then "git" else
     if fetchInfo ? ref  then "git" else
     if fetchInfo ? unpack then "file" else
     throw "Cannot detect fetchInfo Fetcher Family: ${pp fetchInfo}";

  fi2ff = identifyFetchInfoFetcherFamily;


# ---------------------------------------------------------------------------- #

  flocoProcessGitArgs' = { typecheck, pure } @ fenv: self: x: let
    # TODO: `resolved' should be handled by `libplock', not here.
    rough =
      if yt.NpmLock.pkg_git_v3.check x
      then lib.libplock.plockEntryToGenericGitArgs' fenv x
      else if x ? rev then x else
      lib.libplock.plockEntryToGenericGitArgs' fenv ( x // {
        resolved = x.url or x.resolved;
      } );
    tas     = ( self.__thunk or {} ) // rough;
    type    = if lib.libfetch.isGithubUrl rough.url then "github" else "git";
    fetcher = if type == "github" then lib.libfetch.fetchTreeGithubW else
              lib.libfetch.fetchGitW;
    args = if type != "github" then tas else
           removeAttrs ( tas // { inherit type; } ) ["url"];
  in lib.canPassStrict fetcher args;


# ---------------------------------------------------------------------------- #

  flocoGitFetcher' = { typecheck, pure } @ fenv: let
    lfc = lib.libfetch.laikaFetchersConfigured fenv;
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
      __processArgs = flocoProcessGitArgs' { inherit typecheck pure; };
      __functor     = self: x: let
        argt = if typecheck then builtins.head self.__functionMeta.signature
                            else ( y: y );
        rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                            else ( y: y );
        fetchInfo  = argt ( self.__processArgs self x );
        sourceInfo = self.__innerFunction fetchInfo;
        fetched = {
          _type   = "fetched";
          ffamily = "git";
          ltype   = "git";
          inherit fetchInfo sourceInfo;
          inherit (sourceInfo) outPath;
        };
      in rslt fetched;
  };

  flocoGitFetcherUntyped = flocoGitFetcher' ( defaultFlocoEnv // {
    typecheck = false;
  } );
  flocoGitFetcherTyped = flocoGitFetcher' ( defaultFlocoEnv // {
    typecheck = true;
  } );
  flocoGitFetcher = flocoGitFetcher' defaultFlocoEnv;


# ---------------------------------------------------------------------------- #

  # Common core shared by `flocoFileFetcher' and `flocoTarballFetcher'.
  # This aligns with NPM's `fileFetcher' in `pacote', except that NPM doesn't
  # split the fetch/unpack processes into two parts.
  # In our case we /can/ and sometimes want to, so we have two distinct fetchers
  # for each flow.
  flocoUrlFetcher' = { typecheck, pure } @ fenv: let
    lfc = lib.libfetch.laikaFetchersConfigured fenv;
    loc = "at-node-nix#lib.libfetch.flocoUrlFetcher";
  in {
    __functionMeta = {
      name       = "flocoUrlFetcher";
      from       = "at-node-nix#lib.libfetch";
      innerName  = "laika#lib.libfetch.<fetchTreeW|fetchurlDrvW>";
      signature  = [yt.any yt.FlocoFetch.fetched];
      properties = fenv;
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

    __innerFunction = { fetcher, ... } @ fargs:
      fetcher ( removeAttrs fargs ["fetcher"] );

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
      plArgs = lib.libplock.plockEntryToGenericUrlArgs' {
        inherit typecheck pure;
        postFn = lib.libfetch.asGenericUrlArgsImpure;
      } ( self.__thunk // x );
      rawArgs = lib.libfetch.asGenericUrlArgsImpure ( self.__thunk // x );
      args    = if x ? resolved then plArgs else rawArgs;
      fetcher = self.__pickFetcher self ( self.__thunk // args );
    in ( lib.canPassStrict fetcher args ) // { inherit fetcher; };

    # If we hit `fetchurlDrvW' we won't have a `sourceInfo' return.
    # XXX: honestly we do more post-processing in `__functor'
    __postProcess = result:
      if yt.FlocoFetch.source_info_floco.check result then result else {
        inherit (result) outPath;
        # In impure mode we can fill missing `narHash'.
        # This is sometimes used to output metadata to stash it for a later
        # pure run.
        narHash = let
          ft = builtins.fetchTree { type = "path"; path = result.outPath; };
        in if yt.Hash.nar_hash.check result.outputHash
           then result.outputHash
           else if ! pure then ft.narHash else null;
      };

    __functor = self: x: let
      argt = if typecheck then builtins.head self.__functionMeta.signature
                          else ( y: y );
      rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                          else ( y: y );
      args       = self.__processArgs self x;
      result     = self.__innerFunction args;
      fetchInfo  = argt ( removeAttrs args ["fetcher"] );
      sourceInfo = self.__postProcess result;
      wasFT      = fetchInfo ? type;
      fetched = {
        _type     = "fetched";
        ffamily   = "file";
        ltype     = "file";
        fetchInfo = fetchInfo // {
          type = if fetchInfo.unpack or false then "tarball" else "file";
        };
        inherit (sourceInfo) outPath;
        sourceInfo = if sourceInfo.narHash != null then sourceInfo else
                     removeAttrs sourceInfo ["narHash"];
        passthru = ( if ! wasFT then { drv = result; } else {} ) // {
          inherit (args) fetcher;
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
  flocoTarballFetcher' = { typecheck, pure } @ fenv: {
    __functionMeta = {
      name      = "flocoTarballFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "at-node-nix#lib.libfetch.flocoUrlFetcher";
      properties = { inherit typecheck pure; };
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
    inherit (flocoUrlFetcher' fenv) __thunk;
    __innerFunction = flocoUrlFetcher' fenv;
    __processArgs = self: x: let
      ta = if builtins.isString x then { type = "tarball"; url = x; } else
           { type = "tarball"; } // x;
    in self.__thunk // ta;
    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };

  flocoTarballFetcherUntyped = flocoTarballFetcher' ( defaultFlocoEnv // {
    typecheck = false;
  } );
  flocoTarballFetcherTyped = flocoTarballFetcher' ( defaultFlocoEnv // {
    typecheck = true;
  } );
  flocoTarballFetcher = flocoTarballFetcher' defaultFlocoEnv;


# ---------------------------------------------------------------------------- #

  flocoFileFetcher' = { typecheck, pure } @ fenv: {
    __functionMeta = {
      name      = "flocoFileFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "at-node-nix#lib.libfetch.flocoUrlFetcher";
      properties = { inherit typecheck pure; };
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
    inherit (flocoUrlFetcher' fenv) __thunk;
    __innerFunction = flocoUrlFetcher' fenv;

    __processArgs = self: x: let
      ta = if builtins.isString x then { type = "file"; url = x; } else
           { type = "file"; } // x;
    in self.__thunk // ta;

    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };

  flocoFileFetcherUntyped = flocoFileFetcher' ( defaultFlocoEnv // {
    typecheck = false;
  } );
  flocoFileFetcherTyped = flocoFileFetcher' ( defaultFlocoEnv // {
    typecheck = true;
  } );
  flocoFileFetcher = flocoFileFetcher' defaultFlocoEnv;


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
  flocoPathFetcher' = { typecheck, pure } @ fenv: let
    lfc = lib.libfetch.laikaFetchersConfigured fenv;
  in {
    __functionMeta = {
      name      = "flocoPathFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.pathW";
      properties = { inherit typecheck pure; };
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
      # `lib.libstr.baseName' handles store-path basenames.
      name = x.name or ( lib.libfs.baseName p );
    in ( lib.canPassStrict self.__innerFunction ( self.__thunk // {
      inherit name;
      # Coerce an abspath
      path = let
        msg = "You must provide `flocoPathFetcher.__thunk.basedir', or " +
              "pass `basedir' as an argument to fetch relative paths.";
        basedir = x.basedir or self.__thunk.basedir or ( throw msg );
      in if lib.libpath.isAbspath p then p else basedir + "/" + p;
    } ) ) // {
      ltype = if x.link or false then "link" else
              if lib.hasPrefix "file:" ( x.resolved or "" ) then "file" else
              "dir";
    };
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
      _type = "fetched";
      inherit (args) ltype;
      ffamily   = "path";
      fetchInfo = removeAttrs args ["filter" "ltype"];
      inherit outPath;
      sourceInfo = { inherit outPath; };
    } // passthru';
    # Entry point
    __functor = self: x: let
      argt = if typecheck then builtins.head self.__functionMeta.signature
                          else ( y: y );
      rslt = if typecheck then builtins.elemAt self.__functionMeta.signature 1
                          else ( y: y );
      args    = self.__processArgs self x;
      argsi   = argt ( removeAttrs args ["ltype"] );
      outPath = self.__innerFunction argsi;
      fetched = self.__processResult self args outPath;
    in rslt fetched;
  };

  flocoPathFetcherUntyped = flocoPathFetcher' ( defaultFlocoEnv // {
    typecheck = false;
  } );
  flocoPathFetcherTyped = flocoPathFetcher' ( defaultFlocoEnv // {
    typecheck = true;
  } );
  flocoPathFetcher = flocoPathFetcher' defaultFlocoEnv;


# ---------------------------------------------------------------------------- #

  # A wrapper for your wrapper.
  # This pulls fetchers from your `flocoConfig', and routes inputs to the
  # proper fetcher.
  # Largely relies on `ffamily', `fetchInfo', and `<PLENT>.resolved' data.
  # You likely want to create a fetcher for each `lockDir'/`metaSet' if you
  # are trying to fetch "raw" `package-lock.json' or `package.json' sources -
  # although I strongly recommend using `lib.metaSetFrom*' for this since it
  # handles relative path resolution for you, making it harder to shoot
  # yourself in the foot.
  #
  # The following examples will handle `basedir' properly for "dir"/path and
  # "link"/symlink fetchers:
  #
  # With `metaSet' you can omit `basedir' since the `metaEnt' handles this -
  # `<META-ENT>.fetchInfo.path' already sets an absolute path ( ".." persists ).
  # This is the recommended pattern.
  #   let
  #     flocoFetcher = lib.mkFlocoFetcher {};
  #     metaSet      = lib.metaSetFromPlockV3 { lockDir = toString ./.; }
  #   in builtins.mapAttrs ( _: flocoFetcher ) metaSet.__entries
  #
  # You can use `flocoFetch' directly on package metadata, but you need to
  # provide enough information for relative paths to be resolved.
  # I do NOT recommend using this over `lib.metaSetFrom*' unless you really have
  # a need for it.
  #   let
  #     lockDir      = toString ../../foo;
  #     plock        = lib.importJSON' "${lockDir}/package-lock.json";
  #     flocoFetcher = lib.mkFlocoFetcher { basedir = lockDir; };
  #     # Push down `pkey' so that `dir' entries can be fetched.
  #     # Existing `resolved' fields clobber, so this works out.
  #     doFetch = pkey: plent: flocoFetcher ( { resolved = pkey; } // plent );
  #   in builtins.mapAttrs doFetch plock.packages

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
      flocoConfig      = x.flocoConfig or lib.flocoConfig or {};
      args             = flocoConfig.flocoFetchArgs // x;
      allowSubstitutes = args.allowSubstitues or true;
      pure             = args.pure or defaultFlocoEnv.pure;
      typecheck        = args.typecheck or defaultFlocoEnv.typecheck;
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
            __thunk   = fetchersNoConf.pathFetcher.__thunk // {
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
      forPlent = lib.libplock.identifyPlentFetcherFamily x;
      forMeta  = lib.libmeta.identifyMetaEntFetcherFamily x;
      st =
        if x ? fetchInfo then identifyFetchInfoFetcherFamily x.fetchInfo else
        if x ? type then identifyFetchInfoFetcherFamily x else
        if yt.NpmLock.package.check x then forPlent else
        if ( x._type or null ) == "metaEnt" then forMeta else
        throw "flocoFetch: cannot discern source type of value '${pp x}'";
      ft = x.fetchInfo.type or x.ffamily or st;
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
    identifyResolvedFetcherFamily
    identifyFetchInfoFetcherFamily

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
