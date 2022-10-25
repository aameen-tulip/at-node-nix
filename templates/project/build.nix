{ lib
, flocoPackages
, evalScripts
, src ? builtins.path {
    path   = ./.;
    filter = name: type:
      ( lib.libfilt.packCore name type ) &&
      ( lib.libfilt.nixFilt name type );
  }
, nmDirs
}: let
  pjs = lib.importJSON ./package.json;
  # A dependency
in evalScripts {
  name       = "${baseNameOf pjs.name}-built-${pjs.version}";
  version    = pjs.version;
  nmDirCmd   = nmDirs.nmDirCmds.devCopy or ( toString nmDirs );
  runScripts = ["build"];
}
