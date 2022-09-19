# ============================================================================ #
#
# General tests for `libdep' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib)
    depInfoEntFromPlockV3
    depInfoTreeFromPlockV3
  ;

# ---------------------------------------------------------------------------- #

  # A `package-lock.json(V2)'
  lockDir0 = toString ../pkg-set/data;
  plock0   = lib.importJSON "${lockDir0}/package-lock.json";


# ---------------------------------------------------------------------------- #

  tests = {

    # Just see if the routine runs clean
    testDepInfoTreeFromPlockV3_0 = {
      expr     = builtins.deepSeq ( depInfoTreeFromPlockV3 plock0 ) true;
      expected = true;
    };

    testDepInfoTreeFromPlockV3_1 = {
      expr     = ( depInfoTreeFromPlockV3 plock0 )."";
      expected = {
        "@types/jest" = {
          descriptor = "^27.5.1";
          dev = true;
          peer = true;
          peerDescriptor = ">= 27.0.0";
        };
        "@types/node" = {
          descriptor = "^14.18.22";
          dev = true;
          peer = true;
          peerDescriptor = ">= 14.0.0";
        };
        memfs = {
          descriptor = "^3.4.4";
          dev = true;
          runtime = true;
        };
        typescript = {
          descriptor = "^4.7.4";
          dev = true;
        };
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
