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
    splitNmToIdentPath
    pathId
    parentPath
  ;

  # V1 lockfiles
  plv1-big   = lib.importJSON ./data/plv1-big.json;
  plv1-small = lib.importJSON ./data/plv1-small.json;
  plv2-it    = lib.importJSON ./data/plv2-it.json;

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

    testSplitNmToIdentPath = {
      expr = splitNmToIdentPath "node_modules/foo/node_modules/@bar/quux";
      expected = ["foo" "@bar/quux"];
    };

    testPathId = {
      expr = pathId "node_modules/foo/node_modules/@bar/quux";
      expected = "@bar/quux";
    };

    testParentPath = {
      expr = map parentPath [
        "node_modules/foo/node_modules/@bar/quux"
        "node_modules/foo"
        ""
      ];
      expected = [
        "node_modules/foo"
        ""
        null
      ];
    };

    testResolveDepForPlockV3 = {
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
