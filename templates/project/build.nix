{ lib
, pkgsFor
, flocoPackages
, evalScripts
, src ? builtins.path {
    path   = ./.;
    filter = lib.libfilt.packCore;
  }
}: let
  pjs = lib.importJSON ./package.json;
in evalScripts {
  name    = "${baseNameOf pjs.name}-built-${pjs.version}";
  version = pjs.version;
  nmDirCmd = ''
    mkdir -p "$node_modules_path";
    cp -r --reflink=auto -- ${nan} $node_modules_path/nan;
    chmod -R +w "$node_modules_path";
  '';
  runScripts = [
    "build"
  ];
}
