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
  # We'll use `devCopy' for our build.
  nmDirCmd   = nmDirs.nmDirCmds.devCopy;
  runScripts = ["build"];
  passthru   = { inherit nmDirs; };
}
