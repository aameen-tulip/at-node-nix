# ============================================================================ #
#
# A test derivation for `evalScripts'.
# NOTE: this install is bogus and the package wouldn't actually pass tests
# because it needs `node-gyp' to compile stuff.
# We are just testing to see if file copying and nmDirCmd works as expected.
# The only reason to use these sources is because they're used in other tests.
#
# ---------------------------------------------------------------------------- #

{ evalScripts }: let

  # Our src dependency.
  nan = builtins.fetchTree {
    type    = "tarball";
    url     = "https://registry.npmjs.org/nan/-/nan-2.16.0.tgz";
    narHash = "sha256-wqj1iyBB6KCNPGztsJOXYq/1P/SGvf1ob6uuxYgH4a8=";
  };

in evalScripts {
  name    = "msgpack-1.0.3";
  version = "1.0.3";
  src = builtins.fetchTree {
    type    = "tarball";
    url     = "https://registry.npmjs.org/msgpack/-/msgpack-1.0.3.tgz";
    narHash = "sha256-pZlSuooFP0HeU0kU9jUPsf4TYuQ3rRqG8tvbbdMoZS8=";
  };
  nmDirCmd = ''
    mkdir -p "$node_modules_path";
    cp -r --reflink=auto -- ${nan} $node_modules_path/nan;
    chmod -R +w "$node_modules_path";
  '';
  globalNmDirCmd.cmd = ''
    installNodeModules() {
      mkdir -p "$node_modules_path";
      cp -r --reflink=auto -- ${nan} $node_modules_path/nan2;
      chmod -R +w "$node_modules_path";
    }
  '';
  globalInstall = true;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
