{ lib
, flocoPackages
, evalScripts
}: let
  pjs = lib.importJSON ./package.json;
  # A dependency
  nan = builtins.fetchTree {
    type    = "tarball";
    url     = "https://registry.npmjs.org/nan/-/nan-2.16.0.tgz";
    narHash = "sha256-wqj1iyBB6KCNPGztsJOXYq/1P/SGvf1ob6uuxYgH4a8=";
  };
in evalScripts {
  name    = "${baseNameOf pjs.name}-built-${pjs.version}";
  version = pjs.version;
  src = builtins.path {
    path   = ./.;
    filter = name: type:
      ( lib.libfilt.packCore name type ) &&
      ( lib.libfilt.nixFilt name type );
  };
  nmDirCmd = ''
    mkdir -p "$node_modules_path";
    cp -r --reflink=auto -- ${nan} "$node_modules_path/nan";
    chmod -R +w "$node_modules_path";
  '';
  runScripts = [
    "build"
  ];
}
