#
# FIXME: move to top level `tests/' dir.
#
# ============================================================================ #
#
# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build' to see if the test suite passes.
#
# During active/iterative development, maintainters and contributors will almost
# certainly prefer the specialized interfaces of `run.nix' or `check.nix'.
#
# ---------------------------------------------------------------------------- #

{ nixpkgs     ? builtins.getFlake "nixpkgs"
, system      ? builtins.currentSystem
, pkgsFor     ? nixpkgs.legacyPackages.${system}
, writeText   ? pkgsFor.writeText
, ak-nix      ? builtins.getFlake "github:aakropotkin/ak-nix"
, lib         ? import "${toString ../.}" { inherit (ak-nix) lib; }
, outputAttrs ? false
, keepFailed  ? false  # Useful if you run the test explicitly.
, doTrace     ? true   # We want this disabled for `nix flake check'
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  tests = import ./tests.nix ( args // { inherit lib pkgsFor; } );
  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    name = "lib-tests";
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

in if outputAttrs then harness else harness.checkDrv


# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
