args @ { lib, ... }: let

  inherit (builtins) typeOf tryEval mapAttrs toJSON;

# A set of test cases to be run by `run.nix'.
# Test cases are simple pairs of expressions and expected results.
# A "runner", such as `nixpkgs.lib.runTests' or `./run.nix' will process this
# set of tests to produce a list of "failures" where the expected result was
# not produced; these failures are returned as a list of
# `{ expected, name, result }' attrsets.
#
# I have made `runner' an argument here in several of my own test dirs
# which default to `lib.runTests' ( refering to the Nixpkgs implementation ).
# However in these templates I have opted to leave the `tests.nix' file to be
# as simple as possible so that it may be processed by a variety of more
# specialized harnesses.
#
# Think of this as a dead simple data file, and process it however you'd
# like elsewhere.
#
# NOTE: Conventionally test runners ignore attributes whose name does not begin
# with "test" - this is why we can add the field `inputs' here without
# interfering with the test runner.
# If this is a problem for your use case, you write your own test runner you can
# modify this behavior.
#
# Keep this in mind when you are adding new tests with this templates' runner:
#   XXX: Test names must being with "test".
in {

  # Stash our inputs in case we'd like to refer to them later.
  # Think of these as "read-only", since overriding this attribute won't have
  # any effect on the tests themselves.
  inputs = args // { inherit lib; };

  testTrivial = {
    expr = let x = 0; in x;
    expected = 0;
  };

}
