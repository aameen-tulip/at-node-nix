{ lib
, ident
, version
, evalScripts
, src ? builtins.path {
    path   = ./.;
    filter = name: type:
      ( lib.libfilt.packCore name type ) &&
      ( lib.libfilt.nixFilt name type );
  }
, nmDirs
}: evalScripts {
  name = "${baseNameOf ident}-built-${version}";
  inherit version src;
  nmDirCmd   = nmDirs.nmDirCmds.devCopy or ( toString nmDirs );
  runScripts = ["build"];
}
