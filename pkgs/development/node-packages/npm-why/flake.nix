{
  description = "explains why an NPM package is needed";

  inputs.utils.url = "github:numtide/flake-utils";
  inputs.utils.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem ( system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nodePackages = import ./default.nix { inherit pkgs; };
        inherit (nodePackages) sources shell nodeDependencies;
        npm-why = nodePackages."npm-why";
        app = utils.lib.mkApp { drv = npm-why; exePath = "/bin/npm-why"; };
        overlays = final: prev: { inherit npm-why; };
      in {
        packages.npm-why = npm-why;
        packages.default = npm-why;
        defaultPackage = npm-why;
        apps.npm-why = app;
        apps.default = app;
        defaultApp = app;
        nodeDependencies = nodeDependencies;
        nodeShell = shell;
        inherit overlays;
      } );
}
