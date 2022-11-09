# ============================================================================ #
#
# General tests for `librange' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib.librange)
    parseVersionConstraint'

    parseSemverStrict
    parseSemverRoundDown
    parseSemverRoundUp

    sortVersions'
    sortVersionsD
    sortVersionsA

    isRelease
    latestRelease

    normalizeVersion
  ;

# ---------------------------------------------------------------------------- #

  tests = {

    testParseSemverRoundDown_0 = {
      expr = parseSemverRoundDown "1";
      expected = {
        major     = "1";
        minor     = "0";
        patch     = "0";
        preTag    = null;
        buildMeta = null;
      };
    };

    testParseSemverRoundDown_1 = {
      expr = parseSemverRoundDown "1.2";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "0";
        preTag    = null;
        buildMeta = null;
      };
    };

    testParseSemverRoundDown_2 = {
      expr = parseSemverRoundDown "1.2.3";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = null;
        buildMeta = null;
      };
    };

    testParseSemverRoundDown_3 = {
      expr = parseSemverRoundDown "1.2.3-pre";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        buildMeta = null;
      };
    };

    testParseSemverRoundDown_4 = {
      expr = parseSemverRoundDown "1.2.3-pre.0";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre.0";
        buildMeta = null;
      };
    };

    testParseSemverRoundDown_5 = {
      expr = parseSemverRoundDown "1.2.3-pre+a4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        buildMeta = "a4";
      };
    };

    testParseSemverRoundDown_6 = {
      expr = parseSemverRoundDown "1.2.3-pre.0+a4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre.0";
        buildMeta = "a4";
      };
    };

    testParseSemverRoundDown_7 = {
      expr = parseSemverRoundDown "1.2.3-pre+4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        buildMeta = "4";
      };
    };

    testParseSemverRoundDown_8 = {
      expr = parseSemverRoundDown "1.2.3-pre.0+4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre.0";
        buildMeta = "4";
      };
    };

# ---------------------------------------------------------------------------- #

    testParseSemver_0 = {
      expr     = lib.librange.parseSemver ">3.0.0" "3.1.0";
      expected = true;
    };

    testParseSemver_1 = {
      expr     = lib.librange.parseSemver "<3.0.0" "3.1.0";
      expected = false;
    };
  
    testParseSemver_2 = {
      expr     = lib.librange.parseSemver "<=3.0.0" "3.0.0";
      expected = true;
    };

    testParseSemver_3 = {
      expr     = lib.librange.parseSemver "3.x" "3.0.0";
      expected = true;
    };

    testParseSemver_4 = {
      expr     = lib.librange.parseSemver "3.x" "4.0.0";
      expected = false;
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
