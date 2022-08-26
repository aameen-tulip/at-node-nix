# ============================================================================ #
#
# Tests for `libplock' routines related to `package-lock.json(v1)', specifically
# fetchers and dependency graphs.
#
# ---------------------------------------------------------------------------- #

{ lib, fetchurl }: let

# ---------------------------------------------------------------------------- #

  inherit (lib) libplock;

  # V1 lockfiles
  biglock = lib.importJSON ./data/big-package-lock.json;
  smlock  = lib.importJSON ./data/small-package-lock.json;

/* -------------------------------------------------------------------------- */

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  tests = {

    testGenFetchersSmall = {
      expr = let
        fetchers = libplock.resolvedFetchersFromLock fetchurl smlock;
      in builtins.all lib.isDerivation ( builtins.attrValues fetchers );
      expected = true;
    };

  };


# ---------------------------------------------------------------------------- #

in tests

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
