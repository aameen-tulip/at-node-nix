{
  description = "npm fetcher utility";

  inputs.pacote-src.url = "github:npm/pacote/v13.3.0";
  inputs.pacote-src.flake = false;

  outputs = { self, nixpkgs, utils, pacote-src }: {
    overlays.pacote = final: prev: let
      pacoteFull = nixpkgs.lib.callPackageWith final ./. {
        nodejs = final.nodejs-14_x;
        src = pacote-src;
      };
    in {
      pacote = pacoteFull.package // {
        # Passthru carries: sources shell nodeDependencies
        passthru = removeAttrs pacoteFull ["package"];
      };
    };
    packages = builtins.foldl' ( acc: system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend self.overlays.pacote;
    in acc // {
      ${system} = {
        inherit (pkgsFor) pacote;
        default = self.packages.${system}.pacote;
      };
    } ) {} [
      "x86_64-linux" "aarch64-linux" "i686-linux"
      "x86_64-darwin" "aarch64-darwin"
    ];
  };
}
