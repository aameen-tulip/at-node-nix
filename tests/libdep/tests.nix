# ============================================================================ #
#
# General tests for `libdep' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib.libdep)
    depInfoEntFromPlockV3
    depInfoTreeFromPlockV3
  ;

# ---------------------------------------------------------------------------- #

  # A `package-lock.json(V2)'
  lockDir0 = toString ../pkg-set/data;
  plock0   = lib.importJSON "${lockDir0}/package-lock.json";

  # Has symlinks
  plock1 = {
    name = "phony";
    version = "0.0.0";
    requires = true;
    lockfileVersion = 3;
    packages = {
      "../dir".version = "2.0.0";
      "../dir".dependencies.foo = "^1.0.0";
      "".dependencies.bar = "^2.0.0";
      "node_modules/bar".link = true;
      "node_modules/bar".resolved = "../dir";
    };
  };


# ---------------------------------------------------------------------------- #

  tests = {
    inherit lib plock0 plock1;

    # Just see if the routine runs clean
    testDepInfoTreeFromPlockV3_0 = {
      expr     = builtins.deepSeq ( depInfoTreeFromPlockV3 plock0 ) true;
      expected = true;
    };

    # Check real info
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

    # Check that symlinks work
    testDepInfoTreeFromPlockV3_2 = let
      dt = depInfoTreeFromPlockV3 plock1;
    in {
      expr     = dt."../dir";
      expected = dt."node_modules/bar";
    };

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
