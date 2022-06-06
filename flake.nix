{
  inputs.utils.url = "github:numtide/flake-utils/master";
  inputs.utils.inputs.nixpkgs.follows = "/nixpkgs";

  outputs = { self, nixpkgs, utils }: let
    inherit (utils.lib) eachDefaultSystemMap mkApp;
    lib = import ./lib { nixpkgs-lib = nixpkgs.lib; };
  in {
    inherit lib;

    overlays.at-node-nix = final: prev: let
      pkgsFor = nixpkgs.legacyPackages.${final.system};
    in {
      lib = import ./lib { nixpkgs-lib = pkgsFor.lib; };
      npm-why = ( import ./pkgs/development/node-packages/npm-why {
        pkgs = pkgsFor;
      } ).npm-why;
      unpackNodeSource = { tarball, pname, scope ? null, version }:
        pkgsFor.callPackage ./pkgs/build-support/npm-unpack-source-tarball.nix {
          inherit tarball pname scope version;
          lib = final.lib;
        };
      yml2json = import ./pkgs/build-support/yml-to-json.nix {
        inherit (pkgsFor) yq runCommandNoCC;
      };
      yarnLock = import ./pkgs/build-support/yarn-lock.nix {
        inherit (pkgsFor) fetchurl yarn writeText;
        inherit (final) lib yml2json;
      };
    };

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {
      npm-why = ( import ./pkgs/development/node-packages/npm-why {
        pkgs = pkgsFor;
      } ).npm-why;
    } );

    apps = eachDefaultSystemMap ( system: {
      npm-why = mkApp { drv = self.packages.${system}.npm-why; };
    } );

  };
}
