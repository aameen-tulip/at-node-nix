{ system         ? builtins.currentSystem
, nixpkgs        ? builtins.getFlake "nixpkgs"
, pkgs           ? nixpkgs.legacyPackages.${system}
, yq             ? pkgs.yq
, runCommandNoCC ? pkgs.runCommandNoCC
}:
let

  # FIXME: You don't need `runCommand', invoke `yq' directly without `cat'.

  writeYML2JSON = file:
    runCommandNoCC "file.json" {} ''cat ${file}|${yq}/bin/yq -c > $out'';

  readYML2JSON = file:
    builtins.fromJSON ( builtins.readFile ( writeYML2JSON file ) );

in {
  inherit writeYML2JSON readYML2JSON;
  fromYML = str: let
    file = runCommandNoCC "file.json" { inherit str; passAsFile = ["str"]; } ''
      cat $strPath|${yq}/bin/yq -c > $out
    '';
  in builtins.fromJSON ( builtins.readFile file );
}
