# Runs tests with tracing, ends in an assertion.
# Tests are considered "passed" if `runner' returns an empty list, and I
# recommend using `nixpkgs.lib.runTests' here.
# I have left `runner' as an import to allow users to provide a customized
# test runtime.`
args @ { lib, checker ? lib.libdbg.checker, name ? "tests", ... }: let
  inputs = args // { inherit lib checker name; };
  run    = import ./run.nix inputs;
  check = checker name run;
in check
