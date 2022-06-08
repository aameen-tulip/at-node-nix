{
  inputs.utils.url = "github:numtide/flake-utils/master";
  inputs.utils.inputs.nixpkgs.follows = "/nixpkgs";

  outputs = { self, nixpkgs, utils }: let
    inherit (utils.lib) eachDefaultSystemMap mkApp;
    lib = import ./lib { lib = nixpkgs.lib; };
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
      linkedModules = { modules ? [] }:
        pkgsFor.callPackage ./pkgs/build-support/link-node-modules-dir.nix {
          inherit modules;
          inherit (pkgsFor) runCommandNoCC;
          lndir = pkgsFor.xorg.lndir;
        };
      yml2json = import ./pkgs/build-support/yml-to-json.nix {
        inherit (pkgsFor) yq runCommandNoCC;
      };
      yarnLock = import ./pkgs/build-support/yarn-lock.nix {
        inherit (pkgsFor) fetchurl yarn writeText;
        inherit (final) lib yml2json;
      };
    };

    nodeutils = ( eachDefaultSystemMap ( system: {
      linkedModules = { modules ? [] }:
        import ./pkgs/build-support/link-node-modules-dir.nix {
          inherit modules;
          inherit (nixpkgs.legacyPackages.${system}) runCommandNoCC;
          lndir = nixpkgs.legacyPackages.${system}.xorg.lndir;
        };
      unpackNodeSource = { tarball, pname, scope ? null, version }:
        import ./pkgs/build-support/npm-unpack-source-tarball.nix {
          inherit tarball pname scope version lib system;
          inherit (nixpkgs.legacyPackages.${system}) gnutar coreutils bash;
        };
      yml2json = import ./pkgs/build-support/yml-to-json.nix {
        inherit (nixpkgs.legacyPackages.${system}) yq runCommandNoCC;
      };
      yarnLock = import ./pkgs/build-support/yarn-lock.nix {
        inherit (nixpkgs.legacyPackages.${system}) fetchurl yarn writeText;
        inherit (self.nodeutils.${system}) yml2json;
        inherit lib;
      };
    } ) ) // { __functor = nodeutilsSelf: system: nodeutilsSelf.${system}; };

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
