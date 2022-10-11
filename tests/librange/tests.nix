# ============================================================================ #
#
# General tests for `librange' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib.librange)
    versionRE
    parseVersionConstraint'
    parseSemver

    sortVersions'
    sortVersionsD
    sortVersionsA

    isRelease
    latestRelease

    normalizeVersion
  ;

# ---------------------------------------------------------------------------- #

  tests = {

    testParseSemver0 = {
      expr = parseSemver "1";
      expected = {
        major     = "1";
        minor     = "0";
        patch     = "0";
        preTag    = "0";
        preVer    = null;
        buildMeta = null;
      };
    };

    testParseSemver1 = {
      expr = parseSemver "1.2";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "0";
        preTag    = "0";
        preVer    = null;
        buildMeta = null;
      };
    };

    testParseSemver2 = {
      expr = parseSemver "1.2.3";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = null;
        preVer    = null;
        buildMeta = null;
      };
    };

    testParseSemver3 = {
      expr = parseSemver "1.2.3-pre";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = null;
        buildMeta = null;
      };
    };

    testParseSemver4 = {
      expr = parseSemver "1.2.3-pre.0";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = "0";
        buildMeta = null;
      };
    };

    testParseSemver5 = {
      expr = parseSemver "1.2.3-pre+a4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = null;
        buildMeta = "a4";
      };
    };

    testParseSemver6 = {
      expr = parseSemver "1.2.3-pre.0+a4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = "0";
        buildMeta = "a4";
      };
    };

    testParseSemver7 = {
      expr = parseSemver "1.2.3-pre+4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = null;
        buildMeta = "4";
      };
    };

    testParseSemver8 = {
      expr = parseSemver "1.2.3-pre.0+4";
      expected = {
        major     = "1";
        minor     = "2";
        patch     = "3";
        preTag    = "pre";
        preVer    = "0";
        buildMeta = "4";
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
