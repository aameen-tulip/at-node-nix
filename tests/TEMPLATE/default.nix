# ============================================================================ #
#
# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build -f .' to see if the test suite passes.
#
# ---------------------------------------------------------------------------- #

{ system      ? builtins.currentSystem
, at-node-nix ? builtins.getFlake ( toString ../.. )
, pkgsFor     ? at-node-nix.legacyPackages.${system}
, writeText   ? pkgsFor.writeText
, lib         ? at-node-nix.lib
, keepFailed  ? false  # Useful if you run the test explicitly.
, doTrace     ? true   # We want this disabled for `nix flake check'
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  # Used to import test files.
  auto = { inherit lib; } // args;

  tests = let
    testsFrom = file: let
      fn    = import file;
      fargs = builtins.functionArgs fn;
      ts    = fn ( builtins.intersectAttrs fargs auto );
    in assert builtins.isAttrs ts;
       ts.tests or ts;
  in builtins.foldl' ( ts: file: ts // ( testsFrom file ) ) {} [
    ./tests.nix
  ];

# ---------------------------------------------------------------------------- #

  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    purity = if lib.inPureEvalMode then "pure" else "impure";
    name = "@NAME@-tests (${system}, ${purity})";
  in lib.libdbg.mkTestHarness {
    inherit name keepFailed tests writeText;
    mkCheckerDrv = {
      __functionArgs  = lib.functionArgs lib.libdbg.mkCheckerDrv;
      __innerFunction = lib.libdbg.mkCheckerDrv;
      __processArgs   = self: args: self.__thunk // args;
      __thunk = { inherit name keepFailed writeText; };
      __functor = self: x: self.__innerFunction ( self.__processArgs self x );
    };
    checker = name: run: let
      rsl = lib.libdbg.checkerReport name run;
      msg = builtins.trace rsl null;
    in builtins.deepSeq msg rsl;
  };

# ---------------------------------------------------------------------------- #

in harness

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
