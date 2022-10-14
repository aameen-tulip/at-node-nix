# ============================================================================ #
#
# General tests for YANTS types.
#
# ---------------------------------------------------------------------------- #

{ lib
, limit ? 1000  # Limit the number of entries used for testing.
                # In the top level flake we don't want to check 1,000 packuments
}: let

# ---------------------------------------------------------------------------- #

  allPacks = import ../data/packuments.nix;
  inherit (import ../../types/packument.nix { inherit lib; }) packument;

  packs = if limit < 1000 then lib.take limit allPacks else allPacks;

# ---------------------------------------------------------------------------- #

  tests = let

    # Test our type spec against 1,000 packuments.
    # The data set is the top 1,000 on NPM's registry from ~2019.
    # NOTE:
    # `registry.npmjs.org' is just one registry, and others may have
    # different specs.
    # The type we've specificied is meant to be expanded over time.
    npmTop1000 = let
      proc = acc: p:
        acc // {
          "testPackumentSpec_${p._id}" = {
            expr     = let c = packument.checkType p; in if c.ok then p else c;
            expected = p;
          };

           "testIdentifierSpec_${p._id}" = {
            expr     = let c = lib.ytypes.PkgInfo.identifier.checkType p;
                       in if c.ok then p else c;
            expected = p;
          };
        };
    in builtins.foldl' ( acc: p: acc // {} ) {} packs;

  in npmTop1000 // {

# ---------------------------------------------------------------------------- #


# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
