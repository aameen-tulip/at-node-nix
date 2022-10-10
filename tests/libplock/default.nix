# ============================================================================ #
#
# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build -f .' to see if the test suite passes.
#
# ---------------------------------------------------------------------------- #

{ system     ? builtins.currentSystem
, pkgsFor    ? ( builtins.getFlake ( toString ../.. ) ).legacyPackages.${system}
, writeText  ? pkgsFor.writeText
, rime       ? builtins.getFlake "github:aakropotkin/rime"
, lib        ? import ../../lib { inherit (rime) lib; }
, keepFailed ? false  # Useful if you run the test explicitly.
, doTrace    ? true   # We want this disabled for `nix flake check'
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  # Used to import test files.
  autoArgs = { inherit lib; } // args;

  tests = let
    testsFrom = file: let
      fn    = import file;
      fargs = builtins.functionArgs fn;
      ts    = fn ( builtins.intersectAttrs fargs autoArgs );
    in assert builtins.isAttrs ts;
       ts;
  in builtins.foldl' ( ts: file: ts // ( testsFrom file ) ) {} [
    ./tests.nix
    ./ideal-tree-v3.nix
    ./pin-lock-v3.nix
  ];

# ---------------------------------------------------------------------------- #

  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    name = "libplock-tests";
  in lib.libdbg.mkTestHarness {
    inherit name keepFailed tests writeText;
    mkCheckerDrv = args: lib.libdbg.mkCheckerDrv {
      inherit name keepFailed writeText;
      check = lib.libdbg.checkerReport name harness.run;
    };
    checker = name: run: let
      msg = lib.libdbg.checkerMsg name run;
      rsl = lib.libdbg.checkerDefault name run;
    in if doTrace then builtins.trace msg rsl else rsl;
  };


# ---------------------------------------------------------------------------- #

in harness


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
