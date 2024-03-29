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

  callPackageWith  = auto: prev.lib.callPackageWith ( final.flocoEnv // auto );
  callPackagesWith = auto: prev.lib.callPackagesWith ( final.flocoEnv // auto );
  callPackage      = callPackageWith {};
  callPackages     = callPackagesWith {};


# ---------------------------------------------------------------------------- #

in {

  # TODO: This needs to get resolved is a cleaner way.
  # Nixpkgs has a major breaking change to `meta' fields that puts me in
  # a nasty spot... since I have a shitload of custom `meta' fields.
  config = prev.config // { checkMeta = false; };
  lib = prev.lib.extend ( import ./lib/overlay.lib.nix );

  flocoEvalEnvRt = {
    pure         = final.lib.inPureEvalMode;
    ifd          = final.system == ( builtins.currentSystem or null );
    allowedPaths = [];
    typecheck    = false;
  };

  # This will be used as an argument to all functions that are effected by
  # relevant configuration options.
  # TODO: these aren't directed into most libs yet, start making those
  # connections in our libs and with `laika' and `ak-nix'.
  flocoEnv = {
    inherit (final.flocoEvalEnvRt) pure ifd allowedPaths typecheck;
    npmSys = final.lib.getNpmSys' { inherit (final) system; };
    # Default fetchers, prefers `fetchTree' for URLs, `path', and `fetchGit'
    # builtins fetchers ( wrapped by `laika' ).
    # For URLs `sha512' is accepted using `laika#lib.fetchurlDrv'.
    flocoFetch = final.lib.libfetch.mkFlocoFetcher {
      inherit (final.flocoEnv) pure typecheck ifd allowedPaths;
    };
    # Default NmDir builder prefers symlinks
    mkNmDir = final.mkNmDirLinkCmd;
    inherit (final)
      stdenv bash coreutils findutils gnused gnugrep jq xcbuild writeTextFile
      writeText nix-gitignore makeSetupHook runCommandNoCC gnutar makeWrapper
      nix linkFarm xorg
      untarSanPerms copyOut
      lib pacote system
      flocoUnpack
      snapDerivation unpackSafe evalScripts buildGyp coerceDrv
      installGlobal installGlobalNodeModuleHook mkBinPackage
      buildPkgEnt installPkgEnt testPkgEnt
      mkNmDirCmdWith mkNmDirCopyCmd mkNmDirLinkCmd
      pjsUtil patchNodePackageHook
      nodejs-14_x
    ;
    inherit (prev.xorg) lndir;
    inherit (final.flocoEnv.nodejs) python;
    inherit (final.flocoEnv.nodejs.pkgs) node-gyp npm yarn;
    nodejs = prev.nodejs-14_x;

    inherit (import ./pkgs/pkgEnt/mkSrcEnt.nix {
      inherit (final) lib flocoUnpack;
      inherit (final.flocoEnv) pure ifd typecheck allowedPaths flocoFetch;
    } )
      coerceUnpacked' coerceUnpacked
      mkPkgEntSource' mkPkgEntSource
      mkSrcEntFromMetaEnt' mkSrcEntFromMetaEnt
      mkSrcEnt' mkSrcEnt
    ;
  };


# ---------------------------------------------------------------------------- #

  inherit (final.flocoEnv)
    coerceUnpacked'
    mkPkgEntSource'
    mkSrcEntFromMetaEnt'
    mkSrcEnt'
  ;


# ---------------------------------------------------------------------------- #

  flocoUnpack = {
    name
  , tarball
  , setBinPerms      ? true
  , allowSubstitutes ? ( builtins.currentSystem or null ) != final.system
  }: let
    source = final.unpackSafe {
      inherit name tarball setBinPerms allowSubstitutes;
    };
  in { inherit tarball source; inherit (source) outPath; };


# ---------------------------------------------------------------------------- #

  # Trust me, you want to pass the `{}' here.
  snapDerivation = callPackage ./pkgs/make-derivation-simple.nix {};

  # FIXME: `chmod -R +rw' is being used to set bin perms - bad alignment.
  unpackSafe = callPackage ./pkgs/build-support/unpackSafe.nix;

  evalScripts = callPackage ./pkgs/build-support/evalScripts.nix;

  buildGyp = callPackageWith {
    python = prev.python3;
  } ./pkgs/build-support/buildGyp.nix;

  installGlobal = callPackage ./pkgs/pkgEnt/installGlobal.nix;
  mkBinPackage  = callPackage ./pkgs/pkgEnt/mkBinPackage.nix;

  patch-shebangs = callPackage ./pkgs/build-support/patch-shebangs.nix {};

  genSetBinPermissionsHook =
    callPackage ./pkgs/pkgEnt/genSetBinPermsCmd.nix {};

  # NOTE: read the file for some known limitations.
  coerceDrv = callPackage ./pkgs/build-support/coerceDrv.nix;

  inherit (callPackages ./pkgs/pkgEnt/plock.nix {})
    buildPkgEnt
    installPkgEnt
    testPkgEnt
  ;

  # Takes `source' ( original ) and `prepared' ( "built" ) as args.
  # Either `name' ( meta.names.tarball ) or `meta' are also required.
  mkTarballFromLocal = {
    __functionArgs =
      ( final.lib.functionArgs ( import ./pkgs/mkTarballFromLocal.nix ) ) // {
        coreutils      = true;
        pacote         = true;
        snapDerivation = true;
      };
    __functor = _: callPackageWith {
      inherit (final) coreutils pacote snapDerivation;
    } ./pkgs/mkTarballFromLocal.nix;
  };

  inherit (import ./pkgs/optimizeFetchInfo.nix {
    inherit (final) lib urlFetchInfo;
    inherit (final.flocoEnv) pure;
  }) optimizeFetchInfo' optimizeFetchInfo
     optimizeFetchInfoSet' optimizeFetchInfoSet;

  # XXX: impure and IFD
  # You can eliminate impure if you have a use case to justify it; but IFD
  # can't be avoided without creating a Nix plugin.
  inherit (import ./pkgs/collectTarballManifest.nix {
    inherit (final) lib checkTarballPermsImpure;
  }) _collectTarballManifest collectTarballManifest;


  inherit (final.lib.callWith final.flocoEnv ./pkgs/mkNmDir/mkNmDirCmd.nix {
    inherit (prev.xorg) lndir;
  } ) mkNmDirCmdWith mkNmDirCopyCmd mkNmDirLinkCmd ;

  mkNmDirPlockV3 = final.lib.callWith ( final.flocoEnv // {
    inherit (final) mkSrcEnt';
  } ) ./pkgs/mkNmDir/mkNmDirPlockV3.nix;

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
