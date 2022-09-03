{ lib
, name ? "node_modules"
, tree    # Result of `mkSourceTree'
, mkNmDir # One of the `mkNmDir*' routines
, runCommandNoCC
}: let
  nmd = mkNmDir { inherit tree; };
  cmd = nmd.cmd + ''

    mkdir -p $out;
    installNodeModules;
  '';
in runCommandNoCC name {
  node_modules_path = builtins.placeholder "out";
} cmd
