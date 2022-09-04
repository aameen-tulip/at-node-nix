# ============================================================================ #
#
# General tests for builders.
#
#
# ---------------------------------------------------------------------------- #

{ lib
, system
, flocoConfig
, flocoFetch
, flocoUnpack
, pkgsFor
}: let

# ---------------------------------------------------------------------------- #

  inherit (pkgsFor)
    mkPkgEntSource
  ;

# ---------------------------------------------------------------------------- #

  lockDir = toString ./data;
  metaSet = lib.libmeta.metaSetFromPlockV3 { inherit lockDir; };

  # An arbitrary tarball to fetch.
  # We know this one doesn't have the directory permissions issue.
  tsMeta    = metaSet."typescript/4.7.4";
  fetchedTs = flocoFetch tsMeta;


# ---------------------------------------------------------------------------- #

  tests = {

    inherit lockDir metaSet;

# ---------------------------------------------------------------------------- #

    testMkPkgEntSource = let
      pkgEnt   = mkPkgEntSource tsMeta;
      srcFiles = builtins.readDir pkgEnt.source.outPath;
    in {
      expr = {
        srcValid = ( builtins.tryEval srcFiles ) ? success;
        tbValid  = pkgEnt ? tarball.outPath;
      };
      expected = {
        srcValid = true;
        tbValid  = true;
      };
    };


# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
