# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{

  description = "a simple JS project with Floco";

  inputs.at-node-nix.url = "github:aameen-tulip/at-node-nix";
  inputs.nixpkgs.follows = "/at-node-nix/nixpkgs";

# ---------------------------------------------------------------------------- #

  outputs = { self, nixpkgs, at-node-nix, ... } @ inputs: let
    inherit (at-node-nix) lib;
    pjs = lib.importJSON ./package.json;
  in {

# ---------------------------------------------------------------------------- #

    overlays.default = self.overlays.${baseNameOf pjs.name};
    overlays.${baseNameOf pjs.name} = final: prev: {
      flocoPackages = lib.addFlocoPackages prev {
        "${pjs.name}/${pjs.version}" =
          lib.callPackageWith final ./build.nix {};
        "${pjs.name}" = final.flocoPackages."${pjs.name}/${pjs.version}";
      };
    };


# ---------------------------------------------------------------------------- #

    packages = lib.eachDefaultSystemMap ( system: let
      pkgsFor = at-node-nix.legacyPackages.${system}.extend
                  self.overlays.default;
    in {
      ${baseNameOf pjs.name} = pkgsFor.flocoPackages.${baseNameOf pjs.name};
      default = self.packages.${system}.${baseNameOf pjs.name};
    } );


# ---------------------------------------------------------------------------- #

  };  # End Outputs

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
