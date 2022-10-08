# ============================================================================ #
#
# General tests for `libfetch' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  lockDir = toString ./data/proj2;
  metaSet = lib.libmeta.metaSetFromPlockV3 { inherit lockDir; };
  proj2   = metaSet."proj2/1.0.0";
  lodash  = metaSet."lodash/5.0.0";
  ts      = metaSet."typescript/4.8.2";
  projd   = metaSet."projd/1.0.0";


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
        # NOTE: This test case will fail in GitHub Actions if you don't set up
        #       an SSH key authorized for your repo.
        #       If you fork this repo and it crashes here, setup a key, auth it,
        #       and add it to secrets.
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
 
    testCwdFlocoFetcher = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher { cwd = lockDir; };
        mapFetch = builtins.mapAttrs ( _: flocoFetcher );
      in builtins.mapAttrs ( _: v: builtins.deepSeq v true ) {
        plents = mapFetch metaSet.__meta.plock.packages;
        msents = mapFetch metaSet.__entries;
      };
      expected = {
        plents = true;
        msents = true;
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
