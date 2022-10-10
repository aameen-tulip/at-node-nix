# ============================================================================ #
#
# General tests for `build-support' derivations.
#
# ---------------------------------------------------------------------------- #

{ lib
, system
, flocoConfig
, flocoFetch
, flocoUnpack
, pkgsFor
, buildGyp ? pkgsFor.buildGyp
}: let

# ---------------------------------------------------------------------------- #

  isSameSystem =
    ( builtins ? currentSystem ) && ( system == builtins.currentSystem );

  # `optionalAttrsSameSystem'
  # hide attributes in cross-system mode.
  optASS = lib.optionalAttrs isSameSystem;

  # Forces builds, but only if `system' matches the current system.
  readDirIfSameSystem = dir:
    if isSameSystem then builtins.readDir dir else builtins.deepSeq dir dir;

  pathExistsIfSameSystem = path:
    if isSameSystem then builtins.pathExists path
                    else builtins.deepSeq path true;


# ---------------------------------------------------------------------------- #

  tests = {

# ---------------------------------------------------------------------------- #

    # Run a simple build that just creates a file `greeting.txt' with `echo'.
    testBuildGypMsgpack = let
      msgpack = import ./msgpack.nix { inherit (pkgsFor) buildGyp lib; };
    in {
      # Make sure that the file `greeting.txt' was created.
      # Also check that our `node_modules/' were installed to the expected path.
      expr     = readDirIfSameSystem "${msgpack}/build";
      expected = {
        Makefile                   = "regular";
        Release                    = "directory";
        "binding.Makefile"         = "regular";
        "config.gypi"              = "regular";
        deps                       = "directory";
        gyp-mac-tool               = "regular";
        "msgpackBinding.target.mk" = "regular";
        node_gyp_bins              = "directory";
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
