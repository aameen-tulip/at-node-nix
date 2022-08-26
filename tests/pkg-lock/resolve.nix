# ============================================================================ #
#
# Tests for `libplock' routines related to NPM resolution detection in
# `package-lock.json(v1)' files.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib) libplock;

# ---------------------------------------------------------------------------- #

  biglock = lib.importJSON ./data/big-package-lock.json;
  smlock  = lib.importJSON ./data/small-package-lock.json;

  resolvedDep = {
    name = "@jest/schemas";
    value = {
      version = "28.0.2";
      resolved = "https://registry.npmjs.org/@jest/schemas/-/schemas-28.0.2.tgz";
      integrity = "sha512-YVDJZjd4izeTDkij00vHHAymNXQ6WWsdChFRK86qck6Jpr3DCL5W3Is3vslviRlP+bLuMYRLbdp98amMvqudhA==";
    };
  };

  githubDep = {
    name = "lodash";
    value = {
      version = "git+https://github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c";
      from = "git+https://github.com/lodash/lodash.git";
    };
  };


# ---------------------------------------------------------------------------- #

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  tests = {

    testWasResolved = lib.testAllTrue [
      ( libplock.wasResolved resolvedDep.name resolvedDep.value )
      ( ! ( libplock.wasResolved githubDep.name githubDep.value ) )
      ( ! ( libplock.wasResolved "fake" {} ) )
    ];

    testPartitionResolvedSmall = {
      expr = libplock.partitionResolved smlock;
      expected = import ./data/expected-partition-res-small.nix;
    };

  };


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
