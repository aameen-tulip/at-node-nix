# ============================================================================ #
#
# A test derivation for `buildGyp'.
#
# ---------------------------------------------------------------------------- #

{ lib, buildGyp }: let

  # Our only dependency.
  nan = builtins.fetchTree {
    type    = "tarball";
    url     = "https://registry.npmjs.org/nan/-/nan-2.16.0.tgz";
    narHash = "sha256-wqj1iyBB6KCNPGztsJOXYq/1P/SGvf1ob6uuxYgH4a8=";
  };

in buildGyp {
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
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
