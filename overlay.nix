# ============================================================================ #
#
# Nixpkgs overlay.
#
# Depends on `laika.lib' which is an extension of
# `rime', `ak-nix', and `nixpkgs' libs.
#
#
# ---------------------------------------------------------------------------- #

final: prev: let

# ---------------------------------------------------------------------------- #

  # Only these attrs are available for auto-calling.
  # This helps eliminate accidental arg passing for things like `tree'.
  flocoEnv = {
    inherit (final)
      config  # Nixpkgs config
      stdenv
      bash
      coreutils
      findutils
      gnused
      gnugrep
      jq
      xcbuild
      writeTextFile
      writeText
      nix-gitignore
      makeSetupHook
      runCommandNoCC
      gnutar
      makeWrapper
      nix
      linkFarm
      xorg

      untarSanPerms
      copyOut

      lib
      flocoConfig
      pacote
      system
      npmSys

      snapDerivation
      unpackSafe
      evalScripts
      buildGyp
      genericInstall
      patch-shebangs
      genSetBinPermissionsHook
      coerceDrv

      installGlobal
      mkBinPackage

      flocoFetch
      flocoUnpack

      mkNmDir

      mkSourceTreeDrv
      mkPkgEntSource
      buildPkgEnt
      installPkgEnt
      testPkgEnt

      _mkNmDirCopyCmd
      _mkNmDirLinkCmd
      _mkNmDirAddBinWithDirCmd
      _mkNmDirAddBinNoDirsCmd
      _mkNmDirAddBinCmd
      mkNmDirCmdWith
      mkNmDirCopyCmd
      mkNmDirLinkCmd

      mkNmDirPlockV3
      mkNmDirSetupHook

      pjsUtil
      patchNodePackageHook
      installGlobalNodeModuleHook

      nodejs-14_x
    ;

    inherit (prev.xorg) lndir;
    inherit (flocoEnv.nodejs) python;
    inherit (flocoEnv.nodejs.pkgs) node-gyp npm yarn;
    nodejs = prev.nodejs-14_x;

  };

  # FIXME: this obfuscates the real dependency scope.
  callPackageWith  = auto: prev.lib.callPackageWith ( flocoEnv // auto );
  callPackagesWith = auto: prev.lib.callPackagesWith ( flocoEnv // auto );
  callPackage      = callPackageWith {};
  callPackages     = callPackagesWith {};


# ---------------------------------------------------------------------------- #

in {

  # FIXME: This needs to get resolved is a cleaner way.
  # Nixpkgs has a major breaking change to `meta' fields that puts me in
  # a nasty spot... since I have a shitload of custom `meta' fields.
  config = prev.config // { checkMeta = false; };

  lib = let
    unconfigured = prev.lib.extend ( import ./lib/overlay.lib.nix );
  in unconfigured.extend ( libFinal: libPrev: {

    flocoConfig = libPrev.mkFlocoConfig {
      # Most likely this will get populated by `stdenv'
      npmSys = libPrev.libsys.getNpmSys' { inherit (final) system; };
      # Prefer fetching from original host rather than substitute.
      # NOTE: This only applies to fetchers that use derivations.
      #       Builtins won't be effected by this.
      enableImpure = false;
    };

  } );

  inherit (final.lib.flocoConfig) npmSys;
  inherit (final.lib) flocoConfig;


# ---------------------------------------------------------------------------- #

  snapDerivation = callPackage ./pkgs/make-derivation-simple.nix;

  # FIXME: `unpackSafe' needs to set bin permissions/patch shebangs
  unpackSafe  = callPackage ./pkgs/build-support/unpackSafe.nix;

  evalScripts = callPackage ./pkgs/build-support/evalScripts.nix;

  buildGyp = callPackageWith {
    python = prev.python3;
  } ./pkgs/build-support/buildGyp.nix;

  # FIXME: the alignment with `buildGyp' is bad.
  genericInstall = callPackageWith {
    flocoConfig = final.flocoConfig;
    impure      = final.flocoConfig.enableImpureMeta;
    python      = prev.python3;
  } ./pkgs/build-support/genericInstall.nix;

  installGlobal = callPackage ./pkgs/pkgEnt/installGlobal.nix;
  mkBinPackage  = callPackage ./pkgs/pkgEnt/mkBinPackage.nix;

  patch-shebangs = callPackage ./pkgs/build-support/patch-shebangs.nix {};

  genSetBinPermissionsHook =
    callPackage ./pkgs/pkgEnt/genSetBinPermsCmd.nix {};

  # NOTE: read the file for some known limitations.
  coerceDrv = callPackage ./pkgs/build-support/coerceDrv.nix;

  flocoFetch  = callPackage final.lib.libfetch.mkFlocoFetcher {};
  flocoUnpack = {
    name             ? args.meta.names.source
  , tarball          ? args.outPath
  , flocoConfig      ? final.flocoConfig
  , allowSubstitutes ? ( builtins.currentSystem or null ) != final.system
  , ...
  } @ args: let
    source = final.unpackSafe ( args // { inherit allowSubstitutes; } );
    meta'  = prev.lib.optionalAttrs ( args ? meta ) { inherit (args) meta; };
  in { inherit tarball source; outPath = source.outPath; } // meta';

  # Default NmDir builder prefers symlinks
  mkNmDir = final.mkNmDirLinkCmd;

  mkSourceTree = prev.lib.callPackageWith {
    inherit (final)
      lib npmSys system stdenv
      _mkNmDirCopyCmd _mkNmDirLinkCmd _mkNmDirAddBinNoDirsCmd _mkNmDirWith
      mkNmDirCmdWith
      flocoUnpack flocoConfig flocoFetch
    ;
  } ./pkgs/mkNmDir/mkSourceTree.nix;

  # { mkNmDir*, tree ( from `mkSourceTree' ) }
  mkSourceTreeDrv = prev.lib.callPackageWith {
    inherit (final)
      lib npmSys system stdenv runCommandNoCC mkSourceTree mkNmDir
      _mkNmDirCopyCmd _mkNmDirLinkCmd _mkNmDirAddBinNoDirsCmd _mkNmDirWith
      mkNmDirCmdWith
      flocoUnpack flocoConfig flocoFetch
    ;
  } ./pkgs/mkNmDir/mkSourceTreeDrv.nix;

  inherit (callPackages ./pkgs/pkgEnt/plock.nix {})
    mkPkgEntSource
    buildPkgEnt
    installPkgEnt
    testPkgEnt
  ;

  # Takes `source' ( original ) and `prepared' ( "built" ) as args.
  # Either `name' ( meta.names.tarball ) or `meta' are also required.
  mkTarballFromLocal = callPackage ./pkgs/mkTarballFromLocal.nix;

  inherit (callPackages ./pkgs/mkNmDir/mkNmDirCmd.nix {
    inherit (prev.xorg) lndir;
  })
    _mkNmDirCopyCmd
    _mkNmDirLinkCmd
    _mkNmDirAddBinWithDirCmd
    _mkNmDirAddBinNoDirsCmd
    _mkNmDirAddBinCmd
    mkNmDirCmdWith
    mkNmDirCopyCmd
    mkNmDirLinkCmd
  ;

  mkNmDirPlockV3 = callPackage ./pkgs/mkNmDir/mkNmDirPlockV3.nix;
  mkNmDirSetupHook = callPackage ./pkgs/mkNmDir/mkNmDirSetupHook.nix;

  inherit (callPackages ./pkgs/build-support/setup-hooks {})
    pjsUtil
    patchNodePackageHook
    installGlobalNodeModuleHook
  ;

  # NOTE: this package accepts `flakeRef' as an argument which should be set to
  # `self.sourceInfo.outPath' when exposed by the top level flake.
  # The fallback is an unlocked ref to the `main' branch.
  genMeta = callPackage ./pkgs/tools/genMeta {
    inherit (prev) pacote;
  };

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
