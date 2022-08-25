# FIXME: Use new `mkTestHarness'
{
  inputs.utils.url = "github:numtide/flake-utils/master";
  inputs.utils.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.url = "github:aakropotkin/ak-nix/main";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.inputs.utils.follows = "/utils";

  outputs = { self, nixpkgs, utils, ak-nix }: let
    lib = import ../../lib { inherit (ak-nix) lib; };
  in {

    packages = utils.lib.eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system};
    in {
      dependency-closure = ( import ./dependency-closure.nix {
        inherit (pkgsFor) fetchurl writeText;
        inherit lib;
        pkgs = { inherit system; };
      } ).checkDrv;
      resolve = ( import ./resolve.nix {
        inherit (pkgsFor) writeText;
        inherit lib;
        pkgs = { inherit system; };
      } ).checkDrv;
      default = let
        allDrvs = removeAttrs self.packages.${system} ["default"];
      in pkgsFor.linkFarmFromDrvs "all-tests" ( builtins.attrValues allDrvs );
    } );
  };

}
