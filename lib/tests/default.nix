# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build' to see if the test suite passes.
# This will produce a dummy derivation if tests pass, or will throw an eval
# time error if they fail.
# From the perspective of a CI system or `nix flake check' - this is the desired
# behavior for a failing test suite.
#
# During active/iterative development, maintainters and contributors will almost
# certainly prefer the specialized interfaces of `run.nix' or `check.nix'.
{ nixpkgs     ? builtins.getFlake "nixpkgs"
, system      ? builtins.currentSystem
, pkgs        ? nixpkgs.legacyPackages.${system}
, writeText   ? pkgs.writeText
, ak-nix      ? builtins.getFlake "github:aakropotkin/ak-nix"
, lib         ? import ../. { inherit (ak-nix) lib; }
, outputAttrs ? false
, ...
} @ args: let
  inputs = args // { inherit lib; };
  check  = import ./check.nix inputs;
  checkerDrv = writeText "test.log" check;
in if outputAttrs then { inherit inputs check checkerDrv; } else checkerDrv

# NOTE: this file's output/behavior is identical to `lib.libdbg.checkerDrv'.
# The definition has been inlined for the benefit of readers.
# Just know that a `flake.nix' file that uses `checkerDrv' or `mkTestHarness'
# is equivalent.
# XXX: Obviously delete the above comment if you modify the output in a way that
# doesn't align with `lib.libdbg.checkerDrv'.
