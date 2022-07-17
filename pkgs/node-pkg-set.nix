{ lib
, typeOfEntry
, doFetch      # A configured `fetcher' from `./build-support/fetcher.nix'.
, fetchurl    ? lib.fetchurlDrv
, buildGyp
, evalScripts
, linkModules
, linkFarm
, stdenv
, xcbuild
, nodejs
, jq
, ...
} @ globalAttrs: let

/* -------------------------------------------------------------------------- */

/**
 *
 * {
 *   [tarball]
 *   source       ( unpacked into "$out" )
 *   [built]      ( `build'/`pre[pare|publish]' )
 *   [installed]  ( `gyp' or `[pre|post]install' )
 *   prepared     ( `[pre|post]prepare', or "most complete" of previous 3 ents )
 *   [bin]        ( bins symlinked to "$out" from `source'/`built'/`installed' )
 *   [global]     ( `lib/node_modules[/@SCOPE]/NAME[/VERSION]' [+ `bin/'] )
 *   module       ( `[/@SCOPE]/NAME' [+ `.bin/'] )
 *   passthru     ( Holds the fields above )
 *   key          ( `[@SCOPE/]NAME/VERSION' )
 *   meta         ( package info yanked from locks, manifets, etc - no drvs! )
 * }
 *
 */


/* -------------------------------------------------------------------------- */

  entryFromTypes = [
    "package.json"
    "package-lock.json"      # Detect version
    "package-lock.json(v1)"
    "package-lock.json(v2)"
    "yarn.lock"              # Detect version
    "yarn.lock(v1)"
    "yarn.lock(v2)"
    "yarn.lock(v3)"
    "manifest"
    "packument"
  ];


/* -------------------------------------------------------------------------- */

  serialAsIs   = self: self;
  serialIgnore = false;
  serialDrop   = self: "__DROP__";

  serialDefault = self: let
    keepF = k: v: let
      inherit (builtins) isAttrs isString typeOf elem;
      keepType = elem ( typeOf v ) ["set" "string" "bool" "list" "int"];
      keepAttrs =
        if v ? __serial then v.__serial != serialIgnore else
          ( ! lib.isDerivation v );
      keepStr = ! lib.hasPrefix "/nix/store/" v;
      keepT =
        if isAttrs  v then keepAttrs else
        if isString v then keepStr   else keepType;
      keepKey = ! lib.hasPrefix "__" k;
    in keepKey && keepT;
    keeps = lib.filterAttrs keepF ( removeAttrs self ["__serial" "passthru"] );
    serializeF = k: v: let
      fromSerial =
        if builtins.isFunction v.__serial then v.__serial v else v.__serial;
      fromAttrs = if v ? __serial then fromSerial else
                  if v ? __toString then toString v else
                  serialDefault v;
    in if builtins.isAttrs v then fromAttrs else v;
    serialized = builtins.mapAttrs serializeF keeps;
  in lib.filterAttrs ( _: v: v != "__DROP__" ) serialized;


/* -------------------------------------------------------------------------- */

  # Make an extensible attrset with functors `__extend', `__entries', and
  # `__serial' which are intended to create a common interface for handling
  # various sorts of package info.
  # `__extend` allow you to apply overlays to add new fields in a fixed point,
  # and is identical to the `nixpkgs.lib.extends' "overlay" function.
  # `__entries' scrubs any "non-entry" fields which is useful for mapping over
  # "real" entries to avoid processing meta fields.
  # `__serial' scrubs any entries or fields of those entries which should not
  # be written to disk in the even that entries are serialized with a function
  # such as `toJSON' - it is recommended that you replace the default
  # implementation for this functor in most cases.
  mkExtInfo = { serialFn ? serialDefault }: info: let
    info' = self: info // {
      __serial  = serialFn self;
      __entries = lib.filterAttrs ( k: _: ! lib.hasPrefix "__" k ) self;
    };
    infoExt = lib.makeExtensibleWithCustomName "__extend" info';
  in infoExt;


/* -------------------------------------------------------------------------- */

  mergeExtInfo = f: g: let
    inherit (builtins) isAttrs intersectAttrs mapAttrs isFunction;
    mergeAttr = k: gv: let
      ext = let
        gOvA = prev: gv.__unfix__ or ( final: gv );
        gOvF = if isFunction ( gv {} ) then gv else ( final: gv );
        gOv  = if isAttrs gv then gOvA else gOvF;
      in if gv ? __extend then mergeExtInfo f.${k} gv else
         f.${k}.__extend gOv;
      reg = if ( isAttrs gv ) && ( f ? ${k} )
            then lib.recursiveUpdate f.${k} gv
            else gv;
      isExt = ( isFunction gv ) || ( f ? ${k}.__extend );
    in if isExt then ext else reg;
    ext = mapAttrs mergeAttr ( intersectAttrs f g );
  in f.__extend ext;


/* -------------------------------------------------------------------------- */

  metaCore = {
    key     ? args.ident + "/" + args.version
  , ident   ? dirOf args.key
  , version ? baseNameOf args.key
  } @ args: let
    em = mkExtInfo {} {
      inherit key ident version;
      entries.__serial = false;
      __type = "ext:meta";
    };
    addNames = final: prev: {
      scoped = ( builtins.substring 0 1 prev.ident ) != "@";
      names = {
        __serial = false;
        bname = baseNameOf prev.ident;
        node2nix =
          ( if final.scoped then "_at_${final.names.scope}_slash_" else "" ) +
          "${final.names.bname}-${prev.version}";
        registryTarball = "${final.names.bname}-${prev.version}.tgz";
        localTarball =
          ( if final.scoped then "${final.names.scope}-" else "" ) +
          final.names.registryTarball;
        tarball   = final.names.registryTarball;
        src       = "${final.names.bname}-source-${prev.version}";
        built     = "${final.names.bname}-built-${prev.version}";
        installed = "${final.names.bname}-inst-${prev.version}";
        prepared  = "${final.names.bname}-prep-${prev.version}";
        bin       = "${final.names.bname}-bin-${prev.version}";
        module    = "${final.names.bname}-module-${prev.version}";
        global    = "${final.names.bname}-${prev.version}";
      } // ( if final.scoped then { scope = dirOf prev.ident; } else {} );
    };
  in em.__extend addNames;


/* -------------------------------------------------------------------------- */

  # v2 package locks normalize most fields, so for example, `bin' will always
  # be an attrset of name -> path, even if the original `project.json' wrote
  # `"bin": "./foo"' or `"direcories": { "bin": "./scripts" }'.
  pkgEntFromPlockV2 = pkey: {
    version
  , hasInstallScript ? false
  , hasBin ? ( pl2ent.bin or {} ) != {}
  , ident  ? pl2ent.name or
             ( lib.libstr.yank' ".*node_modules/((@[^@/]+/)?[^@/]+)" pkey )
  , ...
  } @ pl2ent: let

    key = ident + "/" + version;
    entType  = typeOfEntry pl2ent;
    hasBuild = entType != "registry-tarball";

    meta = ( metaCore { inherit ident version; } ) // {
      inherit hasInstallScript hasBin hasBuild;
      entries.__serial = false;
      entries.pl2 = pl2ent // { inherit pkey; };
    } // ( lib.optionalAttrs hasBin { inherit (pl2ent) bin; } );

    tarball = let
      url  = pl2ent.resolved;
      hash = pl2ent.integrity;
    in if entType != "registry-tarball" then null else fetchurl {
      name = meta.names.registryTarball;
      inherit hash url;
      unpack = false;
    };

    # FIXME: `pkey' is only referenced for local paths, but we need to account
    # for passing in `cwd' as the dir containing the `package-lock.json'.
    source = doFetch pkey pl2ent;

    # FIXME: pass in the whole package set somewhere so we can create the
    # the `passthru' members `nodeModulesDir[-dev]'.

    # Assumed to be a git checkout or local tree.
    # These do not run the `install' or `prepare' routines, since those are
    # supposed to run after `install'.
    built = self: if ! self.meta.hasBuild then null else evalScripts {
      name = meta.names.built;
      src = source;
      inherit version nodejs jq;
      # Both `dependencies' and `devDependencies' are available for this step.
      # NOTE: `devDependencies' are NOT available during the `install'/`prepare'
      # builder and you should consider how this effects both closures and
      # any "non-standard" fixups you do a package.
      nodeModules = self.passthru.nodeModulesDir-dev;
      runScripts = [
        # These aren't supported by NPM, but they are supported by Pacote.
        # Realistically, you want them because of Yarn.
        "prebuild" "build" "postbuild"
        # NOTE: I know, "prepublish" I know.
        # It is fucking evil, but you probably already knew that.
        # `prepublish' actually isn't run for publishing or `git' checkouts
        # which aim to mimick the creation of a published tarball.
        # It only exists for backwards compatibility to support a handful of
        # ancient registry tarballs.
      ] ++ ( lib.optional ( entType != "git" ) "prepublish" );
    };

    installed = if ! hasInstallScript then null else self: let
      # Runs `gyp' and may run `[pre|post]install' if they're defined.
      # You may need to add meta hints to hooks to account for neanderthals that
      # hide the `binding.gyp' file in a subdirectory - because `npmjs.org'
      # does not detect these and will not contain correct `gypfile' fields in
      # registry manifests.
      gyp = buildGyp {
        name = self.meta.names.installed;
        src = self.built or self.source;
        inherit version nodejs jq xcbuild stdenv;
        nodeModules = self.passthru.nodeModulesDir;
      };
      # Plain old install scripts.
      std = evalScripts {
        name = self.meta.names.installed;
        src = self.built or self.source;
        inherit version nodejs jq;
        nodeModules = self.passthru.nodeModulesDir;
      };
      # Add node-gyp "just in case" and check dynamically.
      # This is just to avoid IFD but you should add an overlay with hints
      # to avoid using this builder.
      maybeGyp = let
        runOne = sn: let
          fallback = "// \":\"";
        in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
      in evalScripts {
        name = self.meta.names.installed;
        src = self.built or self.source;
        inherit version nodejs jq;
        nodeModules = self.passthru.nodeModulesDir;
        # `nodejs' and `jq' are added by `evalScripts'
        nativeBuildInputs = [
          nodejs.pkgs.node-gyp
          nodejs.python
        ] ++ ( lib.optional stdenv.isDarwin xcbuild );
        buildType = "Release";
        configurePhase = let
          hasInstJqCmd = "'.scripts.install // false'";
        in lib.withHooks "configure" ''
          node-gyp() { command node-gyp --ensure --nodedir="$nodejs" "$@"; }
          if test -z "''${isGyp+y}" && test -r ./binding.gyp; then
            isGyp=:
            if test "$( jq -r ${hasInstJqCmd} ./package.json; )" != false; then
              export BUILDTYPE="$buildType"
              node-gyp configure
            fi
          else
            isGyp=
          fi
        '';
        buildPhase = lib.withHooks "build" ''
          ${runOne "preinstall"}
          if test -n "$isGyp"; then
            eval "$( jq -r '.scripts.install // \"node-gyp\"' ./package.json; )"
          else
            ${runOne "install"}
          fi
          ${runOne "preinstall"}
        '';
      };
      gypfileKnown = if self.meta.gypfile then gyp else std;
    in if self ? meta.gypfile then gypfileKnown else maybeGyp;

    prepared = self: let
      src = self.installed or self.built or self.source;
      prep = evalScripts {
      name = meta.names.prepared;
      inherit version src nodejs jq;
      nodeModules = self.passthru.nodeModulesDir;
      runScripts = ["preprepare" "prepare" "postprepare"];
    };
    in if ! ( self.hasPrepare or false ) then src else prep;

    mkBins = to: self: let
      ftPair = n: p: {
        name = if to != null then "${to}/${n}" else n;
        path = "${self.prepared}/${p}";
      };
      binList = lib.mapAttrsToList ftPair pl2ent.bin;
    in if ! hasBin then null else binList;

    bin = if ! hasBin then null else
      self: linkFarm meta.names.bin ( mkBins null self );

    global = self: let
      bindir = if hasBin then ( mkBins "bin" self ) else [];
      gnmdir  = [{
        name = "lib/node_modules/${ident}";
        path = self.prepared.outPath;
      }];
    in linkFarm meta.names.global ( gnmdir ++ bindir );

    module = self: let
      bindir = if hasBin then ( mkBins ".bin" self ) else [];
      lnmdir  = [{ name = ident; path = self.prepared.outPath; }];
    in linkFarm meta.names.module ( lnmdir ++ bindir );

    passthru = {
      inherit
        lib
        doFetch
        fetchurl
        buildGyp
        evalScripts
        linkFarm
        stdenv  # ( for `isDarwin` )
        xcbuild # ( Darwin only )
        nodejs
        # nodeModulesDir      ( Must be added by "parent" package set )
        # nodeModulesDir-dev  ( Must be added by "parent" package set )
      ;
    };

    basics = let
      ents = { inherit key ident version meta source passthru; } //
             ( lib.optionalAttrs ( tarball != null ) { inherit tarball; } );
    in mkExtInfo {} ents;

    # XXX: These builders have not been "invoked", they are thunks which
    # must be called with `final' in a later overlay after
    # `nodeModulesDir[-dev]' fields have been added.
    # We cannot do this now because we need the full package set to populate
    # those field after resolution has been performed and derivations can be
    # created/toposorted.
    buildersOv = final: prev: let
      # Optional drvs
      mbuilt = lib.optionalAttrs prev.meta.hasBuild { inherit built; };
      minst  = lib.optionalAttrs ( installed != null ) { inherit installed; };
      mbin   = lib.optionalAttrs ( bin != null ) { inherit bin; };
    in { inherit prepared module global; } // mbuilt // minst // mbin;

  in basics.__extend buildersOv;


/* -------------------------------------------------------------------------- */

  pkgSetFromPlockV2 = plock: let
    pl2ents = builtins.mapAttrs pkgEntFromPlockV2 plock.packages;
    runtimeKeys = lib.libplock.runtimeClosureToPkgAttrsFor plock;
    # These are direct dev deps.
    # Additional keys are inherited in the overlay below.
    devKeys = lib.libplock.depsToPkgAttrsFor [
      "devDependencies" "peerDependencies"
    ] plock;

    # Create a rudimentary extensible entry for each package lock entry.
    extEnts = let
      toKEnt = pkey: { key, ident, version, meta, ... } @ value: {
        name = key;
        value = value // {
          meta = let
            keyArgs = { from = pkey; inherit ident version; };
          in meta // {
            runtimeDepKeys = runtimeKeys keyArgs;
            devDepKeys =
              lib.optionals ( meta.hasBuild or false ) ( devKeys keyArgs );
          };
        };
      };
      kents = let inherit (builtins) listToAttrs mapAttrs attrValues; in
        listToAttrs ( attrValues ( mapAttrs toKEnt pl2ents ) );

      # Add the full closure of `devDependency' keys to entries.
      # The basic entry only lists direct `devDependency' keys at this point.
      # This could technically be done earlier in the basic entry, but waiting
      # until all of the runtime closure key lists are populated makes this a
      # bit less ugly since we can just inherit them for the direct
      # `devDependency' list to create the dev closure.
      withIndirectDevDepKeys = let
        getDepKeys = dkey: kents.${dkey}.meta.runtimeDepKeys;
        extendDevKeys = _: { meta, ... } @ prev: let
          indirects = map getDepKeys meta.devDepKeys;
          all = meta.runtimeDepKeys ++ meta.devDepKeys ++
                ( builtins.concatLists indirects );
        in prev // { meta = meta // { devDepKeys = lib.unique all; }; };
      in builtins.mapAttrs extendDevKeys kents;
    in mkExtInfo {} withIndirectDevDepKeys;

    # Now that the runtime and dev dependency key lists are populated, we can
    # create `node_modules/' derivations from those lists yanking modules from
    # the package set.
    # These derivations need to remain as unevaluated "thunks" until the
    # `prepareOv' is actually applied, because the builders are still functions
    # waiting to be passed the `final' ( "self" ) object to be realised.
    injectNodeModulesDirsOv = final: prev: let
      injectDepsFor = key: plent: let
        nodeModulesDir = linkModules {
          modules = let depKeys = plent.meta.runtimeDepKeys;
          in map ( k: final.${k}.module.outPath ) depKeys;
        };
        nodeModulesDir-dev = linkModules {
          modules = let depKeys = plent.meta.devDepKeys;
          in map ( k: final.${k}.module.outPath ) depKeys;
        };
        mdd = lib.optionalAttrs ( plent.meta.hasBuild or false ) {
          inherit nodeModulesDir-dev;
        };
      in plent // {
        passthru = { inherit nodeModulesDir; } // mdd // plent.passthru;
      };
      # XXX: We cannot use `prev.__entries' inside of an overlay.
      entries = lib.filterAttrs ( k: _: ! lib.hasPrefix "__" k ) prev;
    in builtins.mapAttrs injectDepsFor entries;

    withNodeModulesDirs = extEnts.__extend injectNodeModulesDirsOv;

    # Now we can actually evaluate ( realise ) the builds.
    # We pass the `final' form of each package entry to the builders, allowing
    # the fixed point to perform toposorting "magically" for us.
    # It is still possible to override the builders after this point; but you
    # will want to remember to override the `passthru' to keep them aligned with
    # the real entries.
    # TODO: `passthru' should be created as a final overlay to avoid
    # ugly/tedious overrides like this.
    prepareOv = final: prev: let
      prepareFor = key: plent: let
        built' = if ! ( plent ? built ) then {} else {
          built = plent.built plent;
        };
        install' = if ! ( plent ? installed ) then {} else {
          installed = plent.installed final.${key};
        };
        bin' = if ! ( plent ? bin ) then {} else {
          bin = plent.bin final.${key};
        };
        prepared = plent.prepared final.${key};
        global = plent.global final.${key};
        module = plent.module final.${key};

        mandatory = { inherit prepared global module; };
        maybes = install' // built' // bin';

        passthru = plent.passthru // mandatory // maybes;

      in plent // { inherit passthru; } // mandatory // maybes;
      # XXX: We cannot use `prev.__entries' inside of an overlay.
      entries = lib.filterAttrs ( k: _: ! lib.hasPrefix "__" k ) prev;
    in builtins.mapAttrs prepareFor entries;

    # We're ready to roll y'all!
  in withNodeModulesDirs.__extend prepareOv;


/* -------------------------------------------------------------------------- */

  mkPkgEntry = {
    ident
  , version
  , key           ? ident + "/" + version
  , entryFromType ? null
  } @ fields: let
  in {};


/* -------------------------------------------------------------------------- */

# FIXME: This is only exposed right now for testing.
# This file is only partially complete.
in {
  inherit
    pkgEntFromPlockV2
    pkgSetFromPlockV2
  ;
}


/* -------------------------------------------------------------------------- */
