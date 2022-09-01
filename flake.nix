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

# ============================================================================ #

  outputs = { self, nixpkgs, nix, utils, ak-nix }: let
    inherit (builtins) getFlake;
    inherit (utils.lib) eachDefaultSystemMap mkApp;

    pkgsForSys = system: nixpkgs.legacyPackages.${system};

    lib = import ./lib { inherit (ak-nix) lib; };

    pacoteFlake = let
      raw = import ./pkgs/development/node-packages/pacote/flake.nix;
      lock = lib.importJSON ./pkgs/development/node-packages/pacote/flake.lock;
      final = raw // ( raw.outputs {
        inherit nixpkgs utils;
        self = final;
        pacote-src = builtins.fetchTree lock.nodes.pacote-src.locked;
      } );
    in final;

    pacotecli = system: ( import ./pkgs/tools/floco/pacote.nix {
      inherit nixpkgs system;
      inherit (pacoteFlake.packages.${system}) pacote;
    } ).pacotecli;

  in {

    inherit lib;

    overlays.at-node-nix = final: prev: let
      pkgsFor = nixpkgs.legacyPackages.${prev.system}.extend
                  ak-nix.overlays.default;
      callPackageWith  = autoArgs: lib.callPackageWith  ( final // autoArgs );
      callPackagesWith = autoArgs: lib.callPackagesWith ( final // autoArgs );
      callPackage  = callPackageWith {};
      callPackages = callPackagesWith {};
    in {

      lib = import ./lib { lib = pkgsFor.lib; };

      pacotecli      = pacotecli final.system;
      snapDerivation = callPackage ./pkgs/make-derivation-simple.nix;
      buildGyp       = callPackage ./pkgs/build-support/buildGyp.nix;
      evalScripts    = callPackage ./pkgs/build-support/evalScripts.nix;
      genericInstall = callPackage ./pkgs/build-support/genericInstall.nix;
      runBuild       = callPackage ./pkgs/build-support/runBuild.nix;

      _node-pkg-set = import ./pkgs/node-pkg-set.nix {
        inherit (final) lib evalScripts buildGyp nodejs;
        inherit (final) runBuild genericInstall;
        inherit (pkgsFor) stdenv jq xcbuild linkFarm;
        fetchurl = final.lib.fetchurlDrv;  # For tarballs without unpacking
        doFetch = final._fetcher.fetcher {
          cwd = throw "Override `cwd' to use local fetchers";  # defer to call-site
          preferBuiltins = true;
        };
      };

      # Pass `dir' as an arg.
      genFlakeInputs =
        callPackage ./pkgs/tools/floco/generate-flake-inputs.nix {
          enableTraces = false;
        };

    };


/* -------------------------------------------------------------------------- */

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {

      inherit (pacoteFlake.packages.${system}) pacote;

      tests = ( import ./tests {
        inherit nixpkgs system lib ak-nix pkgsFor;
        inherit (pkgsFor) writeText;
        enableTraces = true;
        fetchurl = lib.fetchurlDrv;
      } ).checkDrv;

      # NOTE: This is a wrapper over the function.
      genFlakeInputs =
        pkgsFor.callPackage ./pkgs/tools/floco/genFlakeInputs.nix {};

    } );


/* -------------------------------------------------------------------------- */

  };  /* End outputs */
}
