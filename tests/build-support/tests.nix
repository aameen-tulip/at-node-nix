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

  drvs = {
    msgpackGyp  = import ./msgpack.nix { inherit (pkgsFor) buildGyp; };
    msgpackEval = import ./simple.nix { inherit (pkgsFor) evalScripts; };
  };


# ---------------------------------------------------------------------------- #

  tests = {

    inherit drvs;

# ---------------------------------------------------------------------------- #

    # Run a simple build that just creates a `build/' dir.
    testEvalScriptsMsgpack = let
      msgpack = drvs.msgpackEval;
      read    = readDirIfSameSystem "${msgpack}";
    in {
      # Ensure `build/' looks right, but drop a Darwin only file. 
      expr = if builtins.isAttrs read then removeAttrs read ["gyp-mac-tool"]
                                      else read;
      expected = if isSameSystem then {
        ".travis.yml" = "regular";
        LICENSE = "regular";
        "README.md" = "regular";
        bin = "directory";
        "binding.gyp" = "regular";
        deps = "directory";
        lib = "directory";
        "package.json" = "regular";
        run_tests = "regular";
        src = "directory";
        test = "directory";
      } else "${msgpack}";
    };


# ---------------------------------------------------------------------------- #

    # Run a simple build that just creates a `build/' dir.
    testBuildGypMsgpack = let
      msgpack = drvs.msgpackGyp;
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

    # Run a simple build that just creates a `build/' dir.
    testCoerceDrvNan = let
      nan = import ./nan.nix { inherit lib pkgsFor system; };
    in {
      # Ensure `build/' looks right, but drop a Darwin only file. 
      expr = if isSameSystem then builtins.pathExists "${nan}/package.json" else
             lib.isDerivation nan;
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    testPjsUtil = let
      checkPjsUtil = import ./pjs-util.nix {
        inherit (pkgsFor) stdenv pjsUtil jq nodejs;
      };
      log   = builtins.readFile "${checkPjsUtil}";
      lines = builtins.filter builtins.isString ( builtins.split "\n" log );
      passp = l: ( builtins.match "FAIL:.*" l ) == null;
      dumpLog  = builtins.traceVerbose "\n${log}";
      otherSys = checkPjsUtil ? outPath;
      sameSys  = dumpLog ( builtins.all passp lines );
    in {
      expr     = if isSameSystem then sameSys else otherSys;
      expected = true;
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
