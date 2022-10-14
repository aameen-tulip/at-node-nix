# ============================================================================ #
#
# The purpose of this flake is to provide you with useful utilities for building
# Node.js+Nix projects in whatever context or toolkit you choose; while the
# `pkgSet' interfaces use pure Nix+Bash builders, you should view `pkgSet' and
# `metaSet' as abstractions which may be used with any setup - you just need to
# provide the bindings/implementations for their prototypes.
#
# This flake provides an overlay which extends `ak-nix' and `nixpkgs' which is
# the preferred avenue for using these routines.
#
# The `lib' output contains routines which are not system dependendant and these
# never reference derivations, so you can freely access them "purely" even when
# `system' is unknown.
# In some cases these routines may bottom out into routines which accent
# derivations or `system' as args so that they can provide common interfaces for
# various routines ( `libfetch' for example ); but the expressions themselves
# are not system dependant.
#
# Beyond that the `lib' and several `pkgs/' builders were designed for
# general-purpose use, or use with NPM and Yarn rather than `pkgSet' or
# `metaSet', while I may not focus too much on documenting those expressions
# I do advise readers to take a look at them, because they may save you a lot of
# pain and suffering if you were to try and implement similar routines
# from scratch.
#
# ---------------------------------------------------------------------------- #

{

  description = "Node.js+Nix Package Management Expressions";

  inputs.ak-nix.url = "github:aakropotkin/ak-nix/main";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";

  inputs.pacote-src.url = "github:npm/pacote/v13.3.0";
  inputs.pacote-src.flake = false;

  inputs.rime.url = "github:aakropotkin/rime/main";
  inputs.rime.inputs.ak-nix.follows = "/ak-nix";
  inputs.rime.inputs.nixpkgs.follows = "/nixpkgs";

# ---------------------------------------------------------------------------- #

  outputs = { self, nixpkgs, ak-nix, pacote-src, rime }: let

    inherit (ak-nix.lib) eachDefaultSystemMap;
    pkgsForSys = system: nixpkgs.legacyPackages.${system};
    lib = import ./lib { lib = ak-nix.lib.extend rime.overlays.lib; };

# ---------------------------------------------------------------------------- #

  in {  # Real Outputs

    inherit lib;
    flocoFetch = lib.makeOverridable lib.mkFlocoFetcher {
      flocoConfig = lib.libcfg.mkFlocoConfig {};
    };

# ---------------------------------------------------------------------------- #

    # NPM's `fetcher' and `packer'.
    # We use this to pack tarballs just to ease any headaches with file perms.
    # NOTE: This is just a CLI tool and the `nodejs' version isn't really
    # important to other members of the package set.
    # Avoid overriding the `nodejs' version just because you are building other
    # packages which require a specific `nodejs' version.
    overlays.pacote = final: prev: let
      callPackage  = lib.callPackageWith ( final // {
        nodejs = prev.nodejs-14_x;
      } );
      callPackages = lib.callPackagesWith ( final // {
        nodejs = prev.nodejs-14_x;
      } );
      nodeEnv =
        callPackage ./pkgs/development/node-packages/pacote/node-env.nix {
          libtool =
            if final.stdenv.isDarwin then final.darwin.cctools else null;
        };
      pacotePkgs =
        callPackage ./pkgs/development/node-packages/pacote/node-packages.nix {
          inherit nodeEnv;
          src = pacote-src;
        };
    in {
      pacote = pacotePkgs.package;
      inherit (callPackages ./pkgs/tools/floco/pacote.nix {})
        pacotecli pacote-manifest
      ;
    };


# ---------------------------------------------------------------------------- #

    overlays.at-node-nix = final: prev: let
      # FIXME: this obfuscates the real dependency scope.
      callPackageWith  = auto:
        lib.callPackageWith ( final // { nodejs = prev.nodejs-14_x; } // auto );
      callPackagesWith = auto:
        lib.callPackagesWith ( final // {
          nodejs = prev.nodejs-14_x;
        } // auto );
      callPackage  = callPackageWith {};
      callPackages = callPackagesWith {};
    in {

      # FIXME: This needs to get resolved is a cleaner way.
      # Nixpkgs has a major breaking change to `meta' fields that puts me in
      # a nasty spot... since I have a shitload of custom `meta' fields.
      config = prev.config // { checkMeta = false; };
      # XXX: ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

      lib = let
        base = import ./lib { lib = ak-nix.lib.extend rime.overlays.lib; };
      in base.extend ( _: _: {
        flocoConfig = base.mkFlocoConfig {
          # Most likely this will get populated by `stdenv'
          npmSys = base.getNpmSys { system = final.system; };
          # Prefer fetching from original host rather than substitute.
          # NOTE: This only applies to fetchers that use derivations.
          #       Builtins won't be effected by this.
          allowSubstitutedFetchers =
            ( builtins.currentSystem or null ) != final.system;
          enableImpureFetchers = false;
        };
      } );

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

      inherit (final.lib) flocoConfig;
      inherit (final.flocoConfig) npmSys;
      flocoFetch  = callPackage final.lib.libfetch.mkFlocoFetcher {};
      flocoUnpack = {
        name             ? args.meta.names.source
      , tarball          ? args.outPath
      , flocoConfig      ? final.flocoConfig
      , allowSubstitutes ? flocoConfig.allowSubstitutedFetchers
      , ...
      } @ args: let
        source = final.unpackSafe ( args // { inherit allowSubstitutes; } );
        meta'  = lib.optionalAttrs ( args ? meta ) { inherit (args) meta; };
      in { inherit tarball source; outPath = source.outPath; } // meta';

      # Default NmDir builder prefers symlinks
      mkNmDir = final.mkNmDirLinkCmd;

      mkSourceTree = lib.callPackageWith {
        inherit (final)
          lib npmSys system stdenv
          _mkNmDirCopyCmd _mkNmDirLinkCmd _mkNmDirAddBinNoDirsCmd _mkNmDirWith
          mkNmDirCmdWith
          flocoUnpack flocoConfig flocoFetch
        ;
      } ./pkgs/mkNmDir/mkSourceTree.nix;
      # { mkNmDir*, tree ( from `mkSourceTree' ) }
      mkSourceTreeDrv = lib.callPackageWith {
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
    };

# ---------------------------------------------------------------------------- #

    # Merged Overlay. Contains Nixpkgs, `ak-nix' and most overlays defined here.
    overlays.default = lib.composeManyExtensions [
      ak-nix.overlays.default
      self.overlays.pacote
      self.overlays.at-node-nix
    ];


# ---------------------------------------------------------------------------- #

    # Made a function to block `nix flake check' from fetching.
    testData = { ... }: import ./tests/data;

# ---------------------------------------------------------------------------- #

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
    in {

      inherit (pkgsFor) pacote;

      tests = ( import ./tests {
        inherit system pkgsFor rime lib;
        inherit (pkgsFor)
          writeText
          flocoUnpack
          flocoConfig
          flocoFetch
        ;
        keepFailed = false;
        doTrace    = true;
        limit      = 100;
      } ).checkDrv;

    } );


# ---------------------------------------------------------------------------- #

    checks = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
    in {
      inherit (self.packages.${system}) tests;
    } );

# ---------------------------------------------------------------------------- #

    apps = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
    in {
      # Generates `metaSet' file from a package descriptor.
      # Particularly useful for generating flakes for registry tarballs with
      # install scripts since these rarely need to be dynamically generated.
      # NOTE: This isn't really recommended for projects that are under active
      #       development ( because their lockfiles change frequently ).
      genMeta = {
        type = "app";
        program = let
          script = pkgsFor.runCommandNoCC "genMeta.sh" {
            NIX      = "${pkgsFor.nix}/bin/nix";
            MKTEMP   = "${pkgsFor.coreutils}/bin/mktemp";
            CAT      = "${pkgsFor.coreutils}/bin/cat";
            REALPATH = "${pkgsFor.coreutils}/bin/realpath";
            PACOTE   = "${pkgsFor.pacote}/bin/pacote";
            NPM      = "${pkgsFor.nodejs-14_x.pkgs.npm}/bin/npm";
            JQ       = "${pkgsFor.jq}/bin/jq";
            WC       = "${pkgsFor.coreutils}/bin/wc";
            CUT      = "${pkgsFor.coreutils}/bin/cut";
            nativeBuildInputs = [pkgsFor.makeWrapper];
          } ''
            mkdir -p "$out/bin";
            cp ${builtins.path { path = ./bin/genMeta.sh; } }  \
               "$out/bin/genMeta";
            wrapProgram "$out/bin/genMeta"                        \
              --set-default FLAKE_REF ${self.sourceInfo.outPath}  \
              --set-default NIX       "$NIX"                      \
              --set-default MKTEMP    "$MKTEMP"                   \
              --set-default CAT       "$CAT"                      \
              --set-default REALPATH  "$REALPATH"                 \
              --set-default PACOTE    "$PACOTE"                   \
              --set-default NPM       "$NPM"                      \
              --set-default JQ        "$JQ"                       \
              --set-default WC        "$WC"                       \
              --set-default WC        "$CUT"                      \
            ;
          '';
        in "${script}/bin/genMeta";
      };
    } );


# ---------------------------------------------------------------------------- #

    templates = {
      default = self.templates.project;
      project.path = ./templates/project;
      project.description = "a simple JS project with Floco";
    };

# ---------------------------------------------------------------------------- #

    legacyPackages = eachDefaultSystemMap ( system:
      ( nixpkgs.legacyPackages.${system} ).extend self.overlays.default
    );

# ---------------------------------------------------------------------------- #

  };  /* End outputs */
}
