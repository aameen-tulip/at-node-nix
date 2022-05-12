{ pkgs           ? import <nixpkgs> {}
, yq             ? pkgs.yq
, runCommandNoCC ? pkgs.runCommandNoCC
}:
let
  writeYmlToJSON = file:
    runCommandNoCC "file.json" {} ''cat ${file}|${yq}/bin/yq -c > $out'';

  readYML = file:
    builtins.fromJSON ( builtins.readFile ( writeYmlToJSON file ) );
in {
  inherit writeYmlToJSON readYML;
  fromYML = str:
    let
      file = runCommandNoCC "file.json" { inherit str; passAsFile = ["str"]; }
                                        ''cat $strPath|${yq}/bin/yq -c > $out'';
    in builtins.fromJSON ( builtins.readFile file );
}
