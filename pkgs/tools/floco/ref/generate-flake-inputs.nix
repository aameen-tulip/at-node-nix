{ nixpkgs      ? builtins.getFlake "nixpkgs"
, system       ? builtins.currentSystem
, pkgs         ? nixpkgs.legacyPackages.${system}
, lib          ? ( builtins.getFlake ( toString ../../.. ) ).lib
, writeText    ? pkgs.writeText
# This prints each manifest filepath before processing it.
, enableTraces ? true
, ...
} @ args:
let
  inherit (lib.libreg) flakeInputFromManifestTarball;

  _trace = if enableTraces then builtins.trace else ( _: x: x );

  genFlakeInputs = dir: let
    src = builtins.path {
      path = dir;
      filter = name: type:
        ( type != "directory" ) &&
        # Ignore non-release versions
        ( ( builtins.match ".*-.*" ( baseNameOf name ) ) == null )
      ;
    };
    process = f: let
      js = lib.importJSON' "${src}/${f}";
      fi = flakeInputFromManifestTarball ( js // { withToString = true; } );
    in _trace f toString fi;
    manifests = builtins.attrNames ( builtins.readDir src );
    decls = builtins.concatStringsSep "\n" ( map process manifests );
  in writeText "flake.inputs.nix" decls;

# If `dir' isn't passed in initially, return the funtion.
# This lets us capture the function as a closure in case we run it repeatedly.
# If `dir' is passed in, just runnit!
in if args ? dir then genFlakeInputs args.dir else genFlakeInputs
