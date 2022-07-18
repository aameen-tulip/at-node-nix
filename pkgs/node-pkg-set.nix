{ lib
, typeOfEntry
, doFetch      # A configured `fetcher' from `./build-support/fetcher.nix'.
, fetchurl    ? lib.fetchurlDrv
, buildGyp
, evalScripts
, genericInstall
, runBuild
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
 *   passthru     ( Holds the fields above + `nodejs', and a few other drvs )
 *   key          ( `[@SCOPE/]NAME/VERSION' )
 *   meta         ( package info yanked from locks, manifets, etc - no drvs! )
 * }
 *
 */


/* -------------------------------------------------------------------------- */

  inherit (lib.libmeta)
    mkExtInfo
    metaCore
  ;


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

  # v2 package locks normalize most fields, so for example, `bin' will always
  # be an attrset of name -> path, even if the original `project.json' wrote
  # `"bin": "./foo"' or `"direcories": { "bin": "./scripts" }'.
  pkgEntFromPlockV2 = lockDir: pkey: {
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

    meta = let
      core = metaCore { inherit ident version; };
      extras = {
        inherit hasInstallScript hasBin hasBuild;
        entries.__serial = false;
        entries.pl2 = pl2ent // { inherit pkey; };
      } // ( lib.optionalAttrs hasBin { inherit (pl2ent) bin; } );
    in core.__extend ( final: prev: extras );

    tarball = let
      url  = pl2ent.resolved;
      hash = pl2ent.integrity;
    in if entType != "registry-tarball" then null else fetchurl {
      name = meta.names.registryTarball;
      inherit hash url;
      unpack = false;
    };

    doFetch' = globalAttrs.doFetch // { cwd = lockDir; };

    source = doFetch' pkey pl2ent;

    # Assumed to be a git checkout or local tree.
    # These do not run the `install' or `prepare' routines, since those are
    # supposed to run after `install'.
    built = self: if ! ( self.meta.hasBuild or false ) then null else
      self.passthru.runBuild {
        name = meta.names.built;
        src = source;
        inherit version;
        inherit (self.passthru) nodejs jq;
        # Both `dependencies' and `devDependencies' are available for this step.
        # NOTE: `devDependencies' are NOT available during the
        # `install'/`prepare'builder and you should consider how this effects
        # both closures and any "non-standard" fixups you do a package.
        nodeModules = self.passthru.nodeModulesDir-dev;
        # NOTE: I know, "prepublish" I know.
        # It is fucking evil, but you probably already knew that.
        # `prepublish' actually isn't run for publishing or `git' checkouts
        # which aim to mimick the creation of a published tarball.
        # It only exists for backwards compatibility to support a handful of
        # ancient registry tarballs.
        runPrePublish = entType != "git";
      };

    installed = if ! hasInstallScript then null else self:
      self.passthru.genericInstall {
        name = self.meta.names.installed;
        src = self.built or self.source;
        nodeModules = self.passthru.nodeModulesDir;
        inherit version;
        inherit (self) meta;
        inherit (self.passthru) nodejs jq xcbuild stdenv;
      };

    prepared = self: let
      src = self.installed or self.built or self.source;
      prep = self.passthru.evalScripts {
        name = meta.names.prepared;
        inherit version src;
        nodeModules = self.passthru.nodeModulesDir;
        runScripts = ["preprepare" "prepare" "postprepare"];
        inherit (self.passthru) nodejs jq;
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
      self: self.passthru.linkFarm meta.names.bin ( mkBins null self );

    global = self: let
      bindir = if hasBin then ( mkBins "bin" self ) else [];
      gnmdir  = [{
        name = "lib/node_modules/${ident}";
        path = self.prepared.outPath;
      }];
    in self.passthru.linkFarm meta.names.global ( gnmdir ++ bindir );

    module = self: let
      bindir = if hasBin then ( mkBins ".bin" self ) else [];
      lnmdir  = [{ name = ident; path = self.prepared.outPath; }];
    in self.passthru.linkFarm meta.names.module ( lnmdir ++ bindir );

    passthru = {
      doFetch = doFetch';
      inherit
        lib
        fetchurl
        runBuild
        buildGyp
        evalScripts
        genericInstall
        linkFarm
        stdenv  # ( for `isDarwin` )
        xcbuild # ( Darwin only )
        nodejs
        jq
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
      # FIXME: collect `installed.meta.gypfile' in impure mode.
      minst  = lib.optionalAttrs ( installed != null ) { inherit installed; };
      mbin   = lib.optionalAttrs ( bin != null ) { inherit bin; };
    in { inherit prepared module global; } // mbuilt // minst // mbin;

  in basics.__extend buildersOv;


/* -------------------------------------------------------------------------- */

  # FIXME: allow `nodejs' and other `passthru' members to be passed in.
  # XXX: If you expect any local fetchers to actually work you must
  # the argument `lockDir' or `lockPath'.
  pkgSetFromPlockV2 = {
    plock    ? lib.importJSON' lockPath
  , lockDir  ? dirOf lockPath
  , lockPath ? "${lockDir}/package-lock.json"
  }: let
    pl2ents = builtins.mapAttrs ( pkgEntFromPlockV2 lockDir ) plock.packages;
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
