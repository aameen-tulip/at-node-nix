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
# Additional flake outputs expose several utilities through `nodeutils' for more
# direct access with limited closures.
# The tradeoff here is that you aren't realistically able to override most
# functions and derivations "globally", so you might only want to use these in a
# REPL or a small project.
# Also keep in mind that I'm not going to go out of my way to make override
# style argument passing "bullet-proof" with these exposures; doing so is
# tedious and that's literally what overlays are intended for so use the right
# tool for the job.
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
#
# NOTE: At time of writing I am migrating large bodies of "battle tested"
# expressions from the branch `nps-scoped' onto `main', as well as some
# routines which are held in a private repository.
# As these routines are merged to `main' I intend to take that opportunity to
# document them and write test cases.
# If you come across what appears to be a dead end or a missing function, please
# run a quick search on `nps-scoped' or feel free to send me an email
# at <alex.ameen.tx@gmail.com> or contact me on Matrix <growpotkin1:matrix.org>.
#
# ---------------------------------------------------------------------------- #

{

  description = "Node.js+Nix Package Management Expressions";

# ============================================================================ #

  inputs.nix.url = "github:NixOS/nix/master";
  inputs.nix.inputs.nixpkgs.follows = "/nixpkgs";

  inputs.utils.url = "github:numtide/flake-utils/master";
  inputs.utils.inputs.nixpkgs.follows = "/nixpkgs";

  inputs.ak-nix.url = "github:aakropotkin/ak-nix/main";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.inputs.utils.follows = "/utils";

  inputs.pacote-src.url = "github:npm/pacote/v13.3.0";
  inputs.pacote-src.flake = false;

# ============================================================================ #

  outputs = { self, nixpkgs, nix, utils, ak-nix, pacote-src, ... }: let

    inherit (utils.lib) eachDefaultSystemMap;
    pkgsForSys = system: nixpkgs.legacyPackages.${system};
    lib = import ./lib { inherit (ak-nix) lib; };

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
      callPackage =
        lib.callPackageWith ( ( pkgsForSys prev.system ) // final );
      callPackages =
        lib.callPackagesWith ( ( pkgsForSys prev.system ) // final );

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
      pkgsFor = let
        ovs = lib.composeManyExtensions [
          self.overlays.pacote
          ak-nix.overlays.default
        ];
      in ( pkgsForSys prev.system ).extend ovs;
      callPackageWith  = autoArgs:
        lib.callPackageWith  ( pkgsFor // final // autoArgs );
      callPackagesWith = autoArgs:
        lib.callPackagesWith ( pkgsFor // final // autoArgs );
      callPackage  = callPackageWith {};
      callPackages = callPackagesWith {};
    in {

      nodejs = prev.nodejs-14_x;

      lib = import ./lib { lib = prev.lib or pkgsFor.lib; };

      snapDerivation = callPackage ./pkgs/make-derivation-simple.nix;
      # FIXME: `unpackSafe' needs to set bin permissions/patch shebangs
      unpackSafe     = callPackage ./pkgs/build-support/unpackSafe.nix;
      buildGyp       = callPackage ./pkgs/build-support/buildGyp.nix;
      evalScripts    = callPackage ./pkgs/build-support/evalScripts.nix;
      runBuild       = callPackage ./pkgs/build-support/runBuild.nix;
      # FIXME: this still uses the old gross function factory thing
      genericInstall = callPackage ./pkgs/build-support/genericInstall.nix {
        impure = final.flocoConfig.enableImpureMeta;
      };
      patch-shebangs = callPackage ./pkgs/build-support/patch-shebangs.nix {};
      genSetBinPermissionsHook =
        callPackage ./pkgs/pkgEnt/genSetBinPermsCmd.nix {};

      # Most likely this will get populated by `stdenv'
      npmSys = lib.getNpmSys { system = final.system; };
      flocoConfig = final.lib.mkFlocoConfig {};
      flocoFetch  = callPackage lib.libfetch.mkFlocoFetcher {};
      flocoUnpack = {
        name    ? args.meta.names.source
      , tarball ? args.outPath
      , ...
      } @ args: let
        source = final.unpackSafe args;
        meta' = lib.optionalAttrs ( args ? meta ) { inherit (args) meta; };
      in { inherit tarball source; outPath = source.outPath; } // meta';
        #final.pacotecli "extract" { spec = tarball; };

      # Default NmDir builder prefers symlinks
      mkNmDir = final.mkNmDirLinkCmd;

      mkSourceTree = callPackage ./pkgs/mkNmDir/mkSourceTree.nix;
      # { mkNmDir*, tree ( from `mkSourceTree' ) }
      mkSourceTreeDrv = callPackage ./pkgs/mkNmDir/mkSourceTreeDrv.nix;

      inherit (callPackages ./pkgs/pkgEnt/plock.nix {})
        mkPkgEntSource
        buildPkgEnt
        installPkgEnt
      ;

      # Takes `source' ( original ) and `prepared' ( "built" ) as args.
      # Either `name' ( meta.names.tarball ) or `meta' are also required.
      mkTarballFromLocal = callPackage ./pkgs/mkTarballFromLocal.nix;

      _node-pkg-set = callPackages ./pkgs/node-pkg-set.nix {};

      # Pass `dir' as an arg.
      genFlakeInputs =
        callPackage ./pkgs/tools/floco/generate-flake-inputs.nix {
          enableTraces = false;
        };

      inherit (callPackages ./pkgs/mkNmDir/mkNmDirCmd.nix {
        inherit (pkgsFor.xorg) lndir;
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
    };

# ---------------------------------------------------------------------------- #

    # Merged Overlay. Contains Nixpkgs, `ak-nix' and most overlays defined here.
    overlays.default = lib.composeManyExtensions [
      ak-nix.overlays.default
      self.overlays.pacote
      self.overlays.at-node-nix
    ];


# ---------------------------------------------------------------------------- #

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
    in {

      inherit (pkgsFor) pacote;

      tests = ( import ./tests {
        inherit nixpkgs system lib ak-nix pkgsFor;
        inherit (pkgsFor) writeText;
        enableTraces = true;
        fetchurl = lib.fetchurlDrv;
        annPkgs  = self.legacyPackages.${system};
      } ).checkDrv;

      # NOTE: This is a wrapper over the function.
      genFlakeInputs =
        pkgsFor.callPackage ./pkgs/tools/floco/genFlakeInputs.nix {};

    } );


# ---------------------------------------------------------------------------- #

    legacyPackages = eachDefaultSystemMap ( system:
      ( nixpkgs.legacyPackages.${system} ).extend self.overlays.default
    );

# ---------------------------------------------------------------------------- #

  };  /* End outputs */
}
