{
  inputs.nix.url = "github:NixOS/nix/master";
  inputs.nix.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.utils.url = "github:numtide/flake-utils/master";
  inputs.utils.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.url = "github:aakropotkin/ak-nix/main";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.inputs.utils.follows = "/utils";


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
      pkgsFor = import nixpkgs { inherit (final) system; overlays = [
        ak-nix.overlays.default
      ]; };
    in {

      lib = import ./lib { lib = pkgsFor.lib; };

      pacotecli = pacotecli final.system;

      npm-why = ( import ./pkgs/development/node-packages/npm-why {
        pkgs = pkgsFor;
      } ).npm-why;

      linkModules = { modules ? [] }:
        pkgsFor.callPackage ./pkgs/build-support/link-node-modules-dir.nix {
          inherit (pkgsFor) runCommandNoCC;
          lndir = pkgsFor.xorg.lndir;
        } { inherit modules; };

      inherit ( import ./pkgs/build-support/mkNodeTarball.nix {
        inherit (pkgsFor) linkFarm linkToPath untar tar;
        inherit (final) lib pacotecli;
      } )
        mkNodeTarball
        packNodeTarballAsIs
        unpackNodeTarball
        linkAsNodeModule
        linkAsGlobal
      ;

      yml2json = import ./pkgs/build-support/yml-to-json.nix {
        inherit (pkgsFor) yq runCommandNoCC;
      };

      yarnLock = import ./pkgs/build-support/yarn-lock.nix {
        inherit (pkgsFor) fetchurl yarn writeText;
        inherit (final) lib yml2json;
      };

      genFlakeInputs = import ./pkgs/tools/floco/generate-flake-inputs.nix {
        inherit (pkgsFor) writeText;
        inherit (final) lib;
        enableTraces = false;
      };

    };


/* -------------------------------------------------------------------------- */

    nodeutils = ( eachDefaultSystemMap ( system: let
      _mkNodeTarball = import ./pkgs/build-support/mkNodeTarball.nix {
        inherit lib;
        inherit (nixpkgs.legacyPackages.${system}) linkFarm;
        inherit (ak-nix.trivial.${system}) linkToPath untar tar;
        pacotecli = pacotecli system;
      };
    in {
      linkModules = { modules ? [] }:
        import ./pkgs/build-support/link-node-modules-dir.nix {
          inherit (nixpkgs.legacyPackages.${system}) runCommandNoCC;
          lndir = nixpkgs.legacyPackages.${system}.xorg.lndir;
        } { inherit modules; };

      pacotecli = pacotecli system;

      inherit (_mkNodeTarball)
        mkNodeTarball
        packNodeTarballAsIs
        unpackNodeTarball
        linkAsNodeModule
        linkAsGlobal
      ;

      yml2json = import ./pkgs/build-support/yml-to-json.nix {
        inherit (nixpkgs.legacyPackages.${system}) yq runCommandNoCC;
      };
  
      yarnLock = import ./pkgs/build-support/yarn-lock.nix {
        inherit (nixpkgs.legacyPackages.${system}) fetchurl yarn writeText;
        inherit (self.nodeutils.${system}) yml2json;
        inherit lib;
      };
  
      genFlakeInputs = import ./pkgs/tools/floco/generate-flake-inputs.nix {
        inherit (nixpkgs.legacyPackages.${system}) writeText;
        inherit lib;
        enableTraces = true;
      };
  
    } ) ) // { __functor = nodeutilsSelf: system: nodeutilsSelf.${system}; };


/* -------------------------------------------------------------------------- */

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {

      inherit (pacoteFlake.packages.${system}) pacote;

      npm-why = ( import ./pkgs/development/node-packages/npm-why {
        pkgs = pkgsFor;
      } ).npm-why;

      # I am aware of how goofy this is.
      # I am aware that I could use `prefetch' - this is more convenient
      # considering this isn't a permament fixture.
      genFlakeInputs = pkgsFor.writeScript "genFlakeInputs" ''
        _runnit() {
          ${pkgsFor.nix}/bin/nix                                \
            --extra-experimental-features 'flakes nix-command'  \
            eval --impure --raw --expr "
              import ${toString ./pkgs/tools/floco/generate-flake-inputs.nix} {
                writeText = _: d: d;
                enableTraces = false;
                dir = \"$1\";
              }";
        }
        _abspath() {
          ${pkgsFor.coreutils}/bin/realpath "$1";
        }
        if test "$1" = "-o" || test "$1" = "--out"; then
          _runnit "$( _abspath "$2"; )" > "$2";
        else
          _runnit "$( _abspath "$1"; )";
        fi
      '';

    } );


/* -------------------------------------------------------------------------- */

    apps = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {

      # Yeah, we're recursively calling Nix.
      genFlakeInputs = {
        type = "app";
        program = self.packages.${system}.genFlakeInputs.outPath;
      };

    } );


/* -------------------------------------------------------------------------- */

    checks = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {
      lib = import ./lib/tests {
        # `writeText' and `lib' are the only two attributes which legitimately
        # need to cause retesting.
        # Because these are so quick, the convenience of having them available
        # for iterative development in the REPL outweighs spurrious reruns.
        # XXX: When the APIs in this `flake' stabilize this should be corrected.
        inherit nixpkgs system lib ak-nix;
        pkgs = pkgsFor;
        enableTraces = true;
        inherit (pkgsFor) writeText;
      };
    } );


/* -------------------------------------------------------------------------- */

  };  /* End outputs */
}
