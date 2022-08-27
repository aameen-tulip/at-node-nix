# ============================================================================ #
#
# Tests for `libplock' routines related to `package-lock.json(v1)', specifically
# fetchers and dependency graphs.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libplock)
    pinVersionsFromPlockV2
  ;

  # V1 lockfiles
  #biglock = lib.importJSON ./data/big-package-lock.json;
  #smlock  = lib.importJSON ./data/small-package-lock.json;

/* -------------------------------------------------------------------------- */

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  tests = {

    # FIXME
    testPinVersionsFromPlockV2 = {
      expr = {};
      expected = {};
    };

  };


# ---------------------------------------------------------------------------- #

in tests

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
