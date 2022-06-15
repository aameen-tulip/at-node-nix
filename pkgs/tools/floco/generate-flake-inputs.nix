{ ann       ? builtins.getFlake "github:aameen-tulip/at-node-nix/main"
, nixpkgs   ? builtins.getFlake "nixpkgs"
, system    ? builtins.currentSystem
, pkgs      ? nixpkgs.legacyPackages.${system}
, lib       ? ann.lib
, writeText ? pkgs.writeText
, ...
} @ args:
let
  inherit (lib.libreg) flakeInputFromManifestTarball; 

  genFlakeInputs = dir: let
    src = builtins.path {
      path = dir;
      filter = name: type:
        ( type != "directory" ) &&
        # Ignore non-release versions
        ( ! ( lib.test ".*-.*" ( baseNameOf name ) ) )
      ;
    };
    process = f: let
      js = lib.importJSON "${src}/${f}";
      fi = flakeInputFromManifestTarball ( js // { withToString = true; } );
    in builtins.trace f toString fi;
    manifests = builtins.attrNames ( builtins.readDir src );
    decls = builtins.concatStringsSep "\n" ( map process manifests );

  in writeText "flake.inputs.nix" decls;
in if args ? dir then genFlakeInputs args.dir else genFlakeInputs
