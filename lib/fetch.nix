# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt  = lib.ytypes // lib.ytypes.Prim // lib.ytypes.Core;
  plt = yt.NpmLock.Structs // yt.NpmLock;
  inherit (lib.libfetch)
    fetchTreeGithubW
    fetchTreeGitW
    fetchGitW
    fetchTreePathW
  ;

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
    fromTag = builtins.head ( builtins.attrNames tagged );
    fromFetchInfo = let
      t = ent.type or ent.fetchInfo.type or ent.sourceInfo.type or null;
    in if builtins.elem t ["git" "github" "sourcehut"] then "git" else
       if builtins.elem t ["file" "tarball"] then "file" else t;
  in if fromFetchInfo != null then fromFetchInfo else fromTag;


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
    sourceInfo = Structs.sourceInfo;
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
      inherit (lib.libfetch.parseGitUrl resolved) owner rev repo type;
      allRefs' = let
        bname         = baseNameOf ( args.ref or "refs/heads/HEAD" );
        defaultBRefs  = ["HEAD" "master" "main"];
        preferAllRefs = ! ( builtins.elem bname defaultBRefs );
      in if type == "github" then {} else {
        allRefs = args.allRefs or preferAllRefs;
      };
    in {
      inherit type repo owner rev;
      name = repo;
      url  = resolved;
    } // allRefs';
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

  flocoGitFetcher = lib.libfetch.fetchGitW // {
    __functionMeta = {
      name      = "flocoGitFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.<fetchTreeGithubW|fetchGitW>";
      signature = [yt.any Structs.fetched];
    };
    __innerFunction = args:
      if ( args.type or "git" ) == "github"
      then lib.libfetch.fetchTreeGithubW args
      else lib.libfetch.fetchGitW args;
    __functionArgs =
      ( builtins.mapAttrs ( _: _: true ) lib.libfetch.genericGitArgFields ) // {
        resolved = true;
      };
    __thunk = lib.libfetch.fetchGitW.__thunk // { allRefs = true; };
    __processArgs = flocoProcessGitArgs;
    __functor     = self: x: let
      fetchInfo  = self.__processArgs self x;
      sourceInfo = self.__innerFunction fetchInfo;
    in flocoProcessFTResult ( fetchInfo.type or "git" ) fetchInfo sourceInfo;
  };


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
  , ...
  } @ fetchInfo: let
    ftLocked = ( fetchInfo ? narHash ) || lib.flocoConfig.enableImpureFetchers;
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

  flocoTarballFetcher = {
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
      args = {
        type = "tarball";
        url  = x.url or x.resolved;
      } // ( if x ? narHash then { inherit (x) narHash; } else {} );
      args' = self.__thunk // args;
    in builtins.intersectAttrs self.__functionArgs args';
    __functor = self: x: flocoFTFunctor "tarball" self x;
  };


# ---------------------------------------------------------------------------- #

  flocoFileFetcher = {
    __functionMeta = {
      name      = "flocoFileFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.<fetchurlDrvW|fetchTreeFileW>";
      signature = [yt.any Structs.fetched];
    };
    __functionArgs =
      ( lib.functionArgs flocoFileFetcher.__innerFunction ) //
      ( lib.optionalAttrs ( ! lib.flocoConfig.enableImpureFetchers ) {
          integrity = true;
          hash      = true;
          sha1      = true;
          resolved  = true;
        } );
    __innerFunction =
      if lib.flocoConfig.enableImpureFetchers
      then { url, type, narHash ? null, ... } @ args: let
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
    in builtins.intersectAttrs self.__functionArgs args';
    __functor = self: x: let
      rsl = flocoFTFunctor "file" self x;
    in if rsl ? sourceInfo.sourceInfo then rsl.sourceInfo else rsl;
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
  fetchurlDrvMaybeUnpackAfterW = {
    #__functionArgs = hashFields // { name = true; url = false; };
    __functionArgs = ( lib.functionArgs lib.libfetch.fetchurlDrvW ) // {
      unpackAfter = true;  # Allows acting as a `tarballFetcher' in pure mode.
      resolved    = true;
      integritry  = true;
      sha1        = true;
    };

    __thunk = {
      unpack           = false;
      unpackAfter      = false;
      allowSubstitutes = true;
    };

    __innerFunction = lib.libfetch.fetchurlDrvW;

    __processArgs = self: x: let
      rough  = x // {
        url  = x.url or x.resolved;
        hash = x.hash or x.integrity or x.sha1 or x.narHash or x.sha256 or null;
      };
      args = if rough.hash != null then rough else removeAttrs rough ["hash"];
      args' = removeAttrs ( self.__thunk // args ) ["unpackAfter"];
    in builtins.intersectAttrs self.__functionArgs args';

    # Call inner without `unpackAfter' arg, preserving it as a tag in our result
    __functor = self: args: let
      fetched = self.__innerFunction ( self.__processArgs self args );
      # Unpack
      unpacked      = builtins.fetchTarball { url = fetched.outPath; };
      unpackedFull  = unpacked // { passthru.tarball = fetched; };
      doUnpackAfter = args.unpackAfter or self.__thunk.unpackAfter;
    in if doUnpackAfter then unpackedFull else fetched;
  };

  # Fetch a tarball using the given hash, and then unpack.
  # This allows you to use the "packed" hash but still return a store-path to
  # an unpacked tarball.
  fetchurlUnpackDrvW = fetchurlDrvMaybeUnpackAfterW // {
    __thunk.unpackAfter = true;
  };

  # Fetch a tarball using the given hash, and mark it explicitly as needing to
  # be unpacked.
  # FIXME: remove this and instead change logic in builders to look for
  # `source.type == "file";' to detect if unpacking is required.
  fetchurlNoteUnpackDrvW = fetchurlDrvMaybeUnpackAfterW // {
    __functor = self: x:
      ( fetchurlDrvMaybeUnpackAfterW.__functor self x ) // {
        needsUnpack = true;
      };
  };


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
  flocoPathFetcher = {

    __functionMeta = {
      name      = "flocoPathFetcher";
      from      = "at-node-nix#lib.libfetch";
      innerName = "laika#lib.libfetch.pathW";
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

    __functor = self: x: let
      args    = self.__processArgs self x;
      outPath = x.outPath or ( self.__innerFunction args );
      # `filter' is a function so it cannot be added to `fetchInfo' if we want
      # that record to be serialized.
      # Instead we stash it in `passthru'.
      # XXX: if users want to override args, and they had previously overridden
      # the filter they need to refer to `passthru' to actually reproduce the
      # original fetch with their overridden args.
      # In practice I think it's incredibly unlikely that anyone will need to.
      passthru' =
        if args ? filter then { passthru.filter = args.filter; } else {};
    in {
      type      = "path";
      fetchInfo = removeAttrs args ["filter"];
      inherit outPath;
      sourceInfo.outPath = outPath;
    } // passthru';
  };


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
    tarballFetcher ? fetchers.tarballFetcher
  , fileFetcher    ? fetchers.fileFetcher
  , gitFetcher     ? fetchers.gitFetcher
  , pathFetcher    ? fetchers.pathFetcher
  , fetchers       ? lib.recursiveUpdate lib.libcfg.defaultFlocoConfig.fetchers
                                         ( flocoConfig.fetchers or {} )
  , flocoConfig          ? lib.flocoConfig
  , enableImpureFetchers ? flocoConfig.enableImpureFetchers
  , allowSubstitutes     ? flocoConfig.allowSubstitutedFetchers or true
  , basedir              ? null  # Throws in `flocoPathFetcher' if needed.
  } @ cargs: {
    fetchers = {
      # We don't carry pure/impure past argument handling because we're actually
      # going to fetch.
      inherit
        gitFetcher
        tarballFetcher
        fileFetcher
      ;
      # If we are using `flocoPathFetcher', then inject `basedir'.
      pathFetcher =
        if pathFetcher.__functionMeta.name == "flocoPathFetcher" then
        pathFetcher // {
          __thunk = pathFetcher.__thunk // { inherit basedir; };
        } else pathFetcher;
    };

    # FIXME: a hot mess over here.
    __innerFunction = fetchers: x: let
      plent = if yt.NpmLock.package.check x then x else
              x.entries.plock or null;
      # Effectively these are our args.
      fetchInfo = let
        fallback = if plent == null then x else plent;
      in x.fetchInfo or fallback;
      # Determine the `flocoSourceType'.
      type = x.type or fetchInfo.type or ( identifyPlentSourceType plent );
      args = if builtins.isAttrs fetchInfo then { inherit type; } // fetchInfo
                                           else fetchInfo;
      # Select the right fetcher based on `type'.
    in builtins.traceVerbose "using ${type}Fetcher"
       ( lib.apply fetchers."${type}Fetcher" args );

    __functor = self: x: self.__innerFunction self.fetchers x;
  };

# ---------------------------------------------------------------------------- #

in {
  inherit
    identifyResolvedType
    identifyPlentSourceType
    plockEntryHashAttr

    plockEntryToGenericGitArgs

    flocoGitFetcher
    flocoTarballFetcher
    flocoFileFetcher
    flocoPathFetcher

    fetchTreeOrUrlDrv

    fetchurlDrvMaybeUnpackAfterW
    fetchurlUnpackDrvW
    fetchurlNoteUnpackDrvW

    mkFlocoFetcher
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
