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

  # Generic Nix helpers
  inputs.ak-nix.url = "github:aakropotkin/ak-nix/main";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";

  # URI helpers
  inputs.rime.url = "github:aakropotkin/rime";
  inputs.rime.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.rime.inputs.ak-nix.follows  = "/ak-nix";

  # Fetchers and Filesystem helpers.
  inputs.laika.url = "github:aakropotkin/laika/main";
  inputs.laika.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.laika.inputs.rime.follows    = "/rime";

# ---------------------------------------------------------------------------- #

  outputs = { self, nixpkgs, ak-nix, rime, laika }: let

# ---------------------------------------------------------------------------- #

    # `lib' overlays.
    libOverlays.deps = laika.libOverlays.default;  # carries other deps.
    libOverlays.at-node-nix = import ./lib/overlay.lib.nix;
    libOverlays.default = nixpkgs.lib.composeExtensions libOverlays.deps
                                                        libOverlays.at-node-nix;


# ---------------------------------------------------------------------------- #

    # This is included in `lib.ytypes' already.
    # Ignore this unless you were considering vendoring `at-node-nix' types
    # in your project.
    # It is exposed here because it is sometimes useful for complex overrides
    # where vendoring would otherwise be the only "clean" solution.
    ytOverlays.deps        = laika.ytOverlays.default;
    ytOverlays.at-node-nix = import ./types/overlay.yt.nix;
    ytOverlays.default = nixpkgs.lib.composeExtensions ytOverlays.deps
                                                       ytOverlays.at-node-nix;
    # NOTE: see comment above in `libOverlays'.


# ---------------------------------------------------------------------------- #

    # NPM's `fetcher' and `packer'.
    # We use this to pack tarballs just to ease any headaches with file perms.
    # NOTE: This is just a CLI tool and the `nodejs' version isn't really
    # important to other members of the package set.
    # Avoid overriding the `nodejs' version just because you are building other
    # packages which require a specific `nodejs' version.
    overlays.pacote = final: prev: let
      callPackageWith  = auto: nixpkgs.lib.callPackageWith ( final // {
        nodejs = prev.nodejs-14_x;
      } // auto );
      callPackagesWith = auto: nixpkgs.lib.callPackagesWith ( final // {
        nodejs = prev.nodejs-14_x;
      } // auto );
      callPackage  = callPackageWith {};
      callPackages = callPackagesWith {};
      pacoteModule = callPackage ./pkgs/tools/pacote/pacote.nix {
        mkNmDir = final.mkNmDirCopyCmd;
      };
      pacoteUtil   = callPackages ./pkgs/tools/pacote/pacote-cli.nix {};
    in {
      flocoPackages.pacote = final.lib.addFlocoPackages ( _: _: {
        "pacote/${pacoteModule.version}" = pacoteModule;
        pacote = pacoteModule;
      } );
      inherit pacoteModule;
      pacote = pacoteModule.global;
      inherit (pacoteUtil) pacotecli pacote-manifest;
    };


# ---------------------------------------------------------------------------- #

    # Nixpkgs Overlays

    # Deps of our default overlay
    overlays.deps = nixpkgs.lib.composeExtensions laika.overlays.default
                                                  overlays.pacote;

    overlays.at-node-nix = let
      base = import ./overlay.nix;
      fixGenMeta = final: prev: {
        # Generates `metaSet' file from a package descriptor.
        # Particularly useful for generating flakes for registry tarballs with
        # install scripts since these rarely need to be dynamically generated.
        # NOTE: This isn't really recommended for projects that are under active
        #       development ( because their lockfiles change frequently ).
        genMeta = prev.genMeta.override {
          flakeRef = self.sourceInfo.outPath;
          inherit (prev) pacote;
        };
      };
    in nixpkgs.lib.composeExtensions base fixGenMeta;

# ---------------------------------------------------------------------------- #

    # Merged Overlay. Contains Nixpkgs, `ak-nix' and most overlays defined here.
    overlays.default = nixpkgs.lib.composeExtensions overlays.deps
                                                     overlays.at-node-nix;


# ---------------------------------------------------------------------------- #

    packages = ak-nix.lib.eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend overlays.default;
    in {

      inherit (pkgsFor) pacote pacoteModule genMeta;

      tests = let
        pf = pkgsFor.extend ( final: prev: {
          # Use typechecks for tests.
          lib = pkgsFor.lib.extend ( _: prevLib: {
            laikaConfig.typecheck = true;
          } );
          flocoEnv = prev.flocoEnv // { typecheck = true; };
        } );
      in ( import ./tests {
        inherit system rime;
        inherit (pf)
          lib
          writeText
          flocoUnpack
          flocoConfig
          flocoFetch
        ;
        pkgsFor    = pf;
        keepFailed = false;
        doTrace    = true;
        limit      = 100;
      } ).checkDrv;

    } );


# ---------------------------------------------------------------------------- #

  in {  # Real Outputs

    inherit overlays libOverlays ytOverlays packages;

# ---------------------------------------------------------------------------- #

    # Realized/Closed lib and package sets for direct consumption.
    # These are great to use if you aren't composing a large set of overlays
    # and are just building flake outputs.

    lib = nixpkgs.lib.extend libOverlays.default;

    legacyPackages = ak-nix.lib.eachDefaultSystemMap ( system:
      nixpkgs.legacyPackages.${system}.extend overlays.default
    );

# ---------------------------------------------------------------------------- #

    # Made a function to block `nix flake check' from fetching.
    testData = { ... }: import ./tests/data;

# ---------------------------------------------------------------------------- #

    checks = ak-nix.lib.eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend overlays.default;
    in {
      inherit (packages.${system}) tests;
    } );

# ---------------------------------------------------------------------------- #

    templates = let
      project.path        = ./templates/project;
      project.description = "a package-lock.json(v3) project with Floco";
    in {
      default = project;
      inherit project;

      simple.path        = ./templates/project-trivial;
      simple.description = "a simple JS project with Floco";

      simple-bin.path        = ./templates/simple-bin;
      simple-bin.description = "a simple JS executable with no deps";

      tree-bin.path        = ./templates/tree-bin;
      tree-bin.description = "a simple JS executable with tree.json file";
    };

# ---------------------------------------------------------------------------- #

  };  /* End outputs */
}
