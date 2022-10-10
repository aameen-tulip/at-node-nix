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

    # Run a simple build that just creates a `build/' dir.
    testBuildGypMsgpack = let
      msgpack = import ./msgpack.nix { inherit (pkgsFor) buildGyp lib; };
      read    = readDirIfSameSystem "${msgpack}/build";
    in {
      # Ensure `build/' looks right, but drop a Darwin only file. 
      expr = if builtins.isAttrs read then removeAttrs read ["gyp-mac-tool"]
                                      else read;
      expected = if isSameSystem then {
        Makefile                   = "regular";
        Release                    = "directory";
        "binding.Makefile"         = "regular";
        "config.gypi"              = "regular";
        deps                       = "directory";
        "msgpackBinding.target.mk" = "regular";
        node_gyp_bins              = "directory";
      } else "${msgpack}/build";
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
