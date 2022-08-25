# ============================================================================ #

{ lib, ... } @ args: let

# ---------------------------------------------------------------------------- #

  inherit (builtins) typeOf tryEval mapAttrs toJSON;

  inherit (lib) libpkginfo;

  # Tests for some libs are in dedicated subdirs with data files.
  idealTreeTests = ( import ./ideal-tree-plockv2 { inherit lib; } ).tests;

  subdirTests = idealTreeTests;

# ---------------------------------------------------------------------------- #

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

  # Confirm various type of path-likes produce paths to `package.json'.
  # Note that this function remains consistent with relative/absolute inputs.
  # The "interesting" case here is tested first, which is how the empty string
  # is handled, and how it differs from ".".
  # This is a piece of implementation minutae, but I have a hunch that in a few
  # weeks I'll be glad I tested this explicitly.
  testPkgJsonForPath = let pwd = ( toString ./. ); in {
    expr = map libpkginfo.pkgJsonForPath [
      "" "./" "." ./.
      ( toString ./. )
      ( ( toString ./. ) + "/" )
      "package.json"
      "./package.json"
      ( ./. + "/package.json" )
      ( ( toString ./. ) + "/package.json" )
    ];
    expected = [
      "package.json" "./package.json" "./package.json"
      "${pwd}/package.json" "${pwd}/package.json" "${pwd}/package.json"
      "package.json" "./package.json" "${pwd}/package.json"
      "${pwd}/package.json"
    ];
  };

  testRewriteDescriptors = let
    data = {
      name = "test-pkg";
      version = "0.0.1";
      dependencies.foo = "^1.0.0";
      dependencies.bar = "~1.0.0";
      dependencies.baz = "github:fake/repo";
      devDependencies.foo = "^1.0.0";
    };
    xform = {
      foo = "2.0.0";
      bar = d: let m = builtins.match "[~=^]([0-9.]+)" d; in
               if m == null then d else builtins.head m;
      baz = "/nix/store/XXXXXXX-repo.tgz";
      quux = "4.0.0";
    };
  in {
    expr = libpkginfo.rewriteDescriptors { pjs = data; resolves = xform; };
    expected = {
      name = "test-pkg";
      version = "0.0.1";
      dependencies.foo = "2.0.0";
      dependencies.bar = "1.0.0";
      dependencies.baz = "/nix/store/XXXXXXX-repo.tgz";
      devDependencies.foo = "^1.0.0";
    };
  };

  # Inherit tests from subdirs
} // subdirTests
# End tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
