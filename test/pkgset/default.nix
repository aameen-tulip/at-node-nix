{ lib      ? import ../../lib { inherit (ak-nix) lib; }
, ak-nix   ? builtins.getFlake "github:aakropotkin/ak-nix"

, nodejs   ? pkgs.nodejs-14_x
, linkFarm ? pkgs.linkFarm
, buildGyp ? import ../../pkgs/build-support/buildGyp.nix {
    inherit lib;
    inherit (pkgs) stdenv xcbuild;
  }
, lndir          ? pkgs.xorg.lndir
, runCommandNoCC ? pkgs.runCommandNoCC
, linkModules    ? import ../../pkgs/build-support/link-node-modules-dir.nix {
    inherit lndir runCommandNoCC;
  }
, stdenv   ? pkgs.stdenv
, jq       ? pkgs.jq
, xcbuild  ? pkgs.xcbuild

, nixpkgs  ? builtins.getFlake "nixpkgs"
, system   ? builtins.currentSystem
, pkgs     ? nixpkgs.legacyPackages.${system}
}: let

/* -------------------------------------------------------------------------- */

  inherit (lib.libplock)
    runtimeDepsToPkgAttrsFor
  ;


/* -------------------------------------------------------------------------- */

  foo-lock = lib.importJSON ./pkgs/foo/package-lock.json;

/* -------------------------------------------------------------------------- */

  # This is the part that is actually effected by the v2 lock.
  isRegistryTarball = k: v:
    ( lib.hasPrefix "node_modules/" k ) &&
    ( ! ( v.link or false ) ) &&
    # This really just aims to exclude `git+' protocol resolutions.
    ( lib.hasPrefix "https://registry." v.resolved );

  fromPlockV2 = plock: let
    __meta = {};
    # You can probably support v1 locks by tweaking this and the "node_modules/"
    # check in `isRegistryTarball' above.
    regEntries = lib.filterAttrs isRegistryTarball plock.packages;
    toSrc = { resolved, integrity, version, hasInstallScript ? false, ... }: let
      ident =
        lib.yank "https?://registry\\.[^/]+/(.*)/-/.*\\.tgz" resolved;
    in {
      inherit version ident;
      key = "${ident}/${version}";
      url = resolved;
      hash = integrity;
      # FIXME:
    }; #// ( if hasInstallScript then { inherit hasInstallScript; } else {} );
    toSrcNV = e: let
      value = toSrc e;
    in { name = value.key; inherit value; };
    srcEntriesList = map toSrcNV ( builtins.attrValues regEntries );
    srcEntries = builtins.listToAttrs srcEntriesList;
  in srcEntries // { inherit __meta; };


/* -------------------------------------------------------------------------- */

  registry = fromPlockV2 foo-lock;

  sources = let
    toSrc = k: v: let
      meta = {
        inherit (v) key ident version;
        inherit (registry) __meta;
        sourceAttrs = v;
      };
      sourceInfo = builtins.fetchTree {
        type = "tarball";
        inherit (v) url;
        # XXX: this is impure because I'm lazy.
      };
    in if ( ( builtins.substring 0 2 k ) == "__" ) then v else
       sourceInfo // { inherit meta; };
    srcEntries = builtins.mapAttrs toSrc registry;
  in srcEntries // { __meta = registry.__meta // { inherit registry; }; };


/* -------------------------------------------------------------------------- */

  manifestInfoFromPlockV2 = plock: let
    keeps = {
      name                 = null;
      version              = null;
      bin                  = null;
      # `devDependencies' will not appear in registry dependencies because they
      # are already "built".
      dependencies         = null;
      peerDependencies     = null;
      peerDependenciesMeta = null;
      optionalDependencies = null;
      hasInstallScript     = null;
    };
    # Values from second attrset are preserved.
    filtAttrs = builtins.intersectAttrs keeps;
    mkEntry = k: pe: let
      name = pe.name or
        ( lib.yank "https?://registry\\.[^/]+/(.*)/-/.*\\.tgz" pe.resolved );
      key = name + "/" + pe.version;
    in { name  = key; value = { inherit name key; } // ( filtAttrs pe ); };
    regEntries = lib.filterAttrs isRegistryTarball plock.packages;
    manEntryList = builtins.attrValues ( builtins.mapAttrs mkEntry regEntries );
    manEntries = builtins.listToAttrs manEntryList;
  in manEntries // { __meta.checkedInstallScripts = true; };


/* -------------------------------------------------------------------------- */

  gypOv = final: prev: {
    __meta = ( prev.__meta or {} ) // { checkedGypfiles = true; };
    "@datadog/pprof/0.3.0" = prev."@datadog/pprof/0.3.0" // { gypfile = true; };
    "re2/1.17.7" = prev."re2/1.17.7"  // { gypfile = true; };
    "libpq/1.8.9" = prev."libpq/1.8.9" // {
      gypfile = true;
      # FIXME: this can't access `pkgs' here - you need to pass these in
      # through the overlay somehow.
      # Remember that you can't allow `builderArgs' to accept an argument
      # either, it needs to be "flat" data that can be serialized.
      # you might use an accessor key similar to what you did for node modules.
      builderArgs.buildInputs = [pkgs.postgresql];
    };
  };

  manifest =
    lib.fix ( lib.extends gypOv ( self: ( manifestInfoFromPlockV2 foo-lock ) ) );


/* -------------------------------------------------------------------------- */

  hasGyp    = v: v.gypfile or false;
  hasInst = v: ( v.hasInstallScript or false ) && ( v ? version );
  hasNgInst = v: ( hasInst v ) && ( ! ( hasGyp v ) );
  manGyps   = lib.filterAttrs ( _: hasGyp ) manifest;
  manNgInst = lib.filterAttrs ( _: hasNgInst ) manifest;
  manEasy   = lib.filterAttrs ( _: v: ! ( hasInst v ) ) manifest;


/* -------------------------------------------------------------------------- */

  mkBins = built: key: to: let
    ftPair = n: p: {
      name = "${to}/${n}";
      path = "${built.${key}}/${p}";
    };
    bins = lib.mapAttrsToList ftPair ( manifest.${key}.bin or {} );
  in bins;

  mkModule = built: key: let
    name = manifest.${key}.name or ( dirOf key );
    bname = baseNameOf name;
    version = manifest.${key}.version or ( baseNameOf key );
    lbin = mkBins built key ".bin";
    nmdir = [{ inherit name; path = built.${key}.outPath; }];
    lf = linkFarm "${bname}-${version}-module" ( lbin ++ nmdir );
  in lf // { passthru = ( lf.passthru or {} ) // { built = built.${key}; }; };

  mkGlobal = built: key: let
    name = manifest.${key}.name or ( dirOf key );
    bname = baseNameOf name;
    version = manifest.${key}.version or ( baseNameOf key );
    gbin    = mkBins built key "bin";
    gnmdir = [{
      name = "lib/node_modules/${name}";
      path = built.${key}.outPath;
    }];
    lf = linkFarm "${bname}-${version}" ( gbin ++ gnmdir );
  in lf // { passthru = ( lf.passthru or {} ) // { built = built.${key}; }; };


/* -------------------------------------------------------------------------- */

  stage1-nodeModules = let
    easy = builtins.mapAttrs ( k: v: mkModule sources k ) manEasy;
  in lib.makeExtensibleWithCustomName "__extend" ( self: easy );

  allNodeModules = stage1-nodeModules.__extend ( final: prev: let
    callBuild  = buildSource final;
    callModule = key: mkModule { ${key} = callBuild key; } key;
  in builtins.mapAttrs ( k: _: callModule k ) ( manGyps // manNgInst )
  );

  buildSource = allMods: key: assert ! lib.hasPrefix "__" key; let
    src = sources.${key};
    man = manifest.${key};

    deps = runtimeDepsToPkgAttrsFor foo-lock {
      inherit (man) version;
      ident = man.name;
    };

    nodeDepDrvs = lib.filterAttrs ( k: _: builtins.elem k deps ) allMods;
    nodeModules = linkModules {
      modules = builtins.attrValues ( builtins.mapAttrs ( _: v: v.outPath )
                                                        nodeDepDrvs );
    };

    drvName = ( baseNameOf man.name ) + "-" + man.version;

    gypInstalled = let
      baseArgs = {
        inherit src nodeModules nodejs;
        name = drvName + "-gyp";
      };
      manArgs  = man.builderArgs or {};
      darwinArgs = lib.optionalAttrs stdenv.isDarwin { inherit xcbuild; };
    in buildGyp ( baseArgs // manArgs // darwinArgs );

    stdInstalled = stdenv.mkDerivation ( {
      name = drvName + "-inst";
      inherit src;
      nativeBuildInputs = [
        nodejs
        jq
      ];
      postUnpack = let
        doLink = ! ( man.dontLinkModules or false );
      in lib.optionalString doLink ''
        ln -s -- ${nodeModules} "$sourceRoot/node_modules"
        export PATH="$PATH:$sourceRoot/node_modules/.bin"
      '';
      # XXX: Certain `postInstall' scripts might actually need to be
      # `setupHook's because they sometimes try to poke around the top level
      # package's `node_modules/' directory to sanity check API compatibility
      # when version conflicts exist in a node environment.
      # PERSONALLY - I don't think that they should do this, and I'll point out
      # that every single package that I have seen do this was accompanied by
      # a security audit alert by NPM... but I'm calling this "good enough"
      # until I actually find a package that breaks.
      buildPhase = lib.withHooks "build" ''
        eval "$( jq -r '.scripts.preinstall  // ":"' ./package.json; )"
        eval "$( jq -r '.scripts.install     // ":"' ./package.json; )"
        eval "$( jq -r '.scripts.postinstall // ":"' ./package.json; )"
      '';
      installPhase = lib.withHooks "install" ''
        rm -f -- ./node_modules
        cd "$NIX_BUILD_TOP"
        mv -- "$sourceRoot" "$out"
      '';
      passthru = { inherit src nodejs nodeModules; };
    } // ( man.builderArgs or {} ) );

  in if hasGyp    man then gypInstalled else
     if hasNgInst man then stdInstalled else
     src;


/* -------------------------------------------------------------------------- */

  # This is the `node_modules' dir for `foo'.
  nodeModulesDir = linkModules {
    modules = let
      drvs = lib.filterAttrs ( k: v: ! lib.hasPrefix "__" k ) allNodeModules;
    in map ( x: x.outPath ) ( builtins.attrValues drvs );
  };


/* -------------------------------------------------------------------------- */

in {
  inherit
    foo-lock
    isRegistryTarball
    fromPlockV2

    registry
    sources

    manifestInfoFromPlockV2
    gypOv
    manifest

    hasGyp
    hasInst
    hasNgInst

    manGyps
    manNgInst
    manEasy

    mkBins
    mkModule
    mkGlobal

    stage1-nodeModules

    allNodeModules

    lib
    linkModules
    linkFarm
    buildGyp

    nodeModulesDir
  ;
}
