{ lib
, nix
, coreutils
, bash
, system
}: let
  vars = {
    NIX  = "${nix}/bin/nix";
    BASH = "${bash}/bin/bash";
    REALPATH = "${coreutils}/bin/realpath";
    GEN_FLAKE_INPUTS_NIX =
      builtins.path { path = ./generate-flake-inputs.nix; };
  };
in derivation {
  name = "genFlakeInputs";
  inherit system;
  script = let
    raw = builtins.readFile ./genFlakeInputs.in;
    froms = map ( s: "@${s}@" ) ( builtins.attrNames vars );
  in builtins.replaceStrings froms ( builtins.attrValues vars ) raw;
  passAsFile = ["script" "buildCommand"];
  PATH = lib.makeBinPath [coreutils];
  builder = "${bash}/bin/bash";
  buildCommand = ''
    mkdir -p "$out/bin";
    cat "$scriptPath" > "$out/bin/genFlakeInputs";
    chmod +x "$out/bin/genFlakeInputs";
  '';
  args = ["-c" "source \"$buildCommandPath\";"];
}
