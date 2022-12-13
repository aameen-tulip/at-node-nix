# ============================================================================ #
#
# General tests for `libmeta' routines.
#
# ---------------------------------------------------------------------------- #

{ lib } @ args: let

  yt = lib.ytypes;

# ---------------------------------------------------------------------------- #

  # Minimal `metaEnt' from "raw" info.
  # Omitting any of these fields from should result in an error.
  # NOTE: `key' is omitted because it is derived from `ident' and `version'.
  metaRaw = {
    ident       = "lodash";
    version     = "4.17.21";
    ltype       = "file";
    entFromtype = "package.json";
    depInfo     = {};
    sysInfo     = {};
    lifecycle   = { install = false; build = false; };
    fetchInfo   = {
      type    = "tarball";
      url     = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz";
      narHash = "sha256-amyN064Yh6psvOfLgcpktd5dRNQStUYHHoIqiI6DMek=";
    };
  };
  metaEnt = lib.libmeta.mkMetaEnt metaRaw;

# ---------------------------------------------------------------------------- #

  tests = {
    env = {
      inherit args lib metaRaw metaEnt;
    };

# ---------------------------------------------------------------------------- #

    testMkMetaEnt_0 = {
      expr        = yt.FlocoMeta.meta_ent_info.checkType metaEnt;
      expected.ok = true;
    };

    # Check that `key' can be derived from `ident' + `version'.
    testMkMetaEnt_1 = {
      expr = let
        m = ( removeAttrs metaRaw ["ident" "version"] ) // {
          key = metaRaw.ident + "/" + metaRaw.version;
        };
      in yt.FlocoMeta.meta_ent_info.checkType ( lib.libmeta.mkMetaEnt m );
      expected.ok = true;
    };


# ---------------------------------------------------------------------------- #

    testGetKey_0 = {
      expr     = lib.libmeta.getKey metaEnt;
      expected = "lodash/4.17.21";
    };

    testGetIdent_0 = {
      expr     = lib.libmeta.getIdent metaEnt;
      expected = "lodash";
    };

    testGetVersion_0 = {
      expr     = lib.libmeta.getVersion metaEnt;
      expected = "4.17.21";
    };

    testGetEntFromtype_0 = {
      expr     = lib.libmeta.getEntFromtype metaEnt;
      expected = "raw";
    };

    testGetLtype_0 = {
      expr     = lib.libmeta.getLtype metaEnt;
      expected = "file";
    };

    testGetMetaFiles_0 = {
      expr     = lib.libmeta.getMetaFiles metaEnt;
      expected = {};
    };

    testGetScripts_0 = {
      expr     = lib.libmeta.getScripts metaEnt;
      expected = null;
    };

    testGetGypfile_0 = {
      expr     = lib.libmeta.getGypfile metaEnt;
      expected = null;
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
