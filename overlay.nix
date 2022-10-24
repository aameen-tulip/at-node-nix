# ============================================================================ #
#
# Nixpkgs overlay.
#
# Depends on `rime.lib' which is an extension of `ak-nix' and `nixpkgs' libs.
#
#
# ---------------------------------------------------------------------------- #

final: prev: let

# ---------------------------------------------------------------------------- #

  # FIXME: this obfuscates the real dependency scope.
  callPackageWith  = auto: prev.lib.callPackageWith ( final // {
    inherit (final.lib) flocoConfig;
    nodejs = prev.nodejs-14_x;
  } // auto );
  callPackagesWith = auto: prev.lib.callPackagesWith ( final // {
    inherit (final.lib) flocoConfig;
    nodejs = prev.nodejs-14_x;
  } // auto );
  callPackage  = callPackageWith {};
  callPackages = callPackagesWith {};


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
      allowSubstitutedFetchers =
        ( builtins.currentSystem or null ) != final.system;
      enableImpureFetchers = false;
    };
  } );

  inherit (final.lib.flocoConfig) npmSys;


# ---------------------------------------------------------------------------- #

  snapDerivation = callPackage ./pkgs/make-derivation-simple.nix;

  # FIXME: `unpackSafe' needs to set bin permissions/patch shebangs
  unpackSafe  = callPackage ./pkgs/build-support/unpackSafe.nix;

  evalScripts = callPackage ./pkgs/build-support/evalScripts.nix;

  buildGyp    = callPackageWith {
    python = prev.python3;
  } ./pkgs/build-support/buildGyp.nix;

  # FIXME: the alignment with `buildGyp' is bad.
  genericInstall = callPackageWith {
    flocoConfig = final.flocoConfig;
    impure      = final.flocoConfig.enableImpureMeta;
    python      = prev.python3;
  } ./pkgs/build-support/genericInstall.nix;

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
  , allowSubstitutes ? flocoConfig.allowSubstitutedFetchers
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
  pjsUtil = callPackage ./pkgs/build-support/setup-hooks/pjs-util.nix {};
  mkNmDirSetupHook = callPackage ./pkgs/mkNmDir/mkNmDirSetupHook.nix;

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
