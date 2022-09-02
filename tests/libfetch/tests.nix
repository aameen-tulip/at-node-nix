# ============================================================================ #
#
# General tests for `libfetch' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  metaSet = lib.libmeta.metaSetFromPlockV3 {
    lockDir = toString ./data/proj2;
  };
  proj2  = metaSet."proj2/1.0.0";
  lodash = metaSet."lodash/5.0.0";
  ts     = metaSet."typescript/4.8.2";
  projd  = metaSet."projd/1.0.0";


# ---------------------------------------------------------------------------- #

  tests = {

    env = {
      inherit metaSet proj2 lodash ts projd;
    };

    testFlocoFetcher = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher {};
      in builtins.mapAttrs ( _: v: v ? outPath ) {
        dir  = flocoFetcher proj2;
        git  = flocoFetcher lodash;
        tar  = flocoFetcher ts;
        link = flocoFetcher projd;
      };
      expected = {
        dir  = true;
        git  = true;
        tar  = true;
        link = true;
      };
    };

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
