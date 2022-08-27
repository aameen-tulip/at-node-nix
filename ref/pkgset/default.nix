# ============================================================================ #
#
# NOTE: This test case basically served as the proof-of-concept for a new wave
# of builders and the `(meta|pkg)Set' constructs that have been developed in the
# `nps-scoped' branch over the last few months ( currently being merged in ).
#
# After pruning redundant or dead code from `libplock' some routines this test
# depended on were removed ( they contained bugs in edge cases which are fixed
# in new routines, and upgrading this test case was not worth the effort ).
#
#
# ---------------------------------------------------------------------------- #

{ lib      ? import ../../lib { inherit (ak-nix) lib; }
, ak-nix   ? builtins.getFlake "github:aakropotkin/ak-nix"

, nodejs   ? pkgs.nodejs-14_x
, linkFarm ? pkgs.linkFarm
, buildGyp ? import ../../pkgs/build-support/buildGyp.nix {
    inherit lib nodejs;
    inherit (pkgs) stdenv xcbuild jq;
  }
, lndir          ? pkgs.xorg.lndir
, runCommandNoCC ? pkgs.runCommandNoCC
, linkModules    ? import ../../pkgs/build-support/link-node-modules-dir.nix {
    inherit lndir runCommandNoCC;
  }
, evalScripts ? import ../../pkgs/build-support/evalScripts.nix {
    inherit lib stdenv nodejs jq;
  }
, stdenv   ? pkgs.stdenv
, jq       ? pkgs.jq
, xcbuild  ? pkgs.xcbuild

, nixpkgs  ? builtins.getFlake "nixpkgs"
, system   ? builtins.currentSystem
, pkgs     ? nixpkgs.legacyPackages.${system}
}: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libplock)
    runtimeDepsToPkgAttrsFor
    manifestInfoFromPlockV2
    isRegistryTarball
    fromPlockV2
  ;


# ---------------------------------------------------------------------------- #

  foo-lock = lib.importJSON ./pkgs/foo/package-lock.json;

# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

  hasGyp    = v: v.gypfile or false;
  hasInst = v: ( v.hasInstallScript or false ) && ( v ? version );
  hasNgInst = v: ( hasInst v ) && ( ! ( hasGyp v ) );
  manGyps   = lib.filterAttrs ( _: hasGyp ) manifest;
  manNgInst = lib.filterAttrs ( _: hasNgInst ) manifest;
  manEasy   = lib.filterAttrs ( _: v: ! ( hasInst v ) ) manifest;


# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

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
        inherit src nodeModules;
        name = drvName + "-gyp";
      };
      manArgs  = man.builderArgs or {};
      darwinArgs = lib.optionalAttrs stdenv.isDarwin { inherit xcbuild; };
    in buildGyp ( baseArgs // manArgs // darwinArgs );

    stdInstalled = evalScripts ( {
      name = drvName + "-inst";
      inherit nodeModules src;
    } // ( man.builderArgs or {} ) );

  in if hasGyp    man then gypInstalled else
     if hasNgInst man then stdInstalled else
     src;


# ---------------------------------------------------------------------------- #

  # This is the `node_modules' dir for `foo'.
  nodeModulesDir = linkModules {
    modules = let
      drvs = lib.filterAttrs ( k: v: ! lib.hasPrefix "__" k ) allNodeModules;
    in map ( x: x.outPath ) ( builtins.attrValues drvs );
  };


# ---------------------------------------------------------------------------- #

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
