# ============================================================================ #
#
# General tests for `libevent' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  metaRaw = {
    ident             = "lodash";
    version           = "4.17.21";
    key               = "lodash/4.17.21";
    ltype             = "file";
    entFromtype       = "package.json";
    depInfo           = {};
    sysInfo           = {};
    fetchInfo         = {
      type    = "tarball";
      url     = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz";
      narHash = "sha256-amyN064Yh6psvOfLgcpktd5dRNQStUYHHoIqiI6DMek=";
    };
  };

  mefsLc = m:
    ( lib.libmeta.mkMetaEnt m ).__extend lib.libevent.metaEntLifecycleOverlay;


# ---------------------------------------------------------------------------- #

  tests = {

    env = {
      inherit
        metaRaw
      ;
    };


# ---------------------------------------------------------------------------- #

    testPartialLc_lodash_Deserial_0 = {
      expr = ( mefsLc ( metaRaw // { lifecycle.install = false; } ) ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = false;
      };
    };

    testPartialLc_lodash_Deserial_1 = {
      expr = ( mefsLc ( metaRaw // { lifecycle.install = true; } ) ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = true;
      };
    };

    testPartialLc_lodash_Deserial_2 = {
      expr = ( mefsLc ( metaRaw // {
        ltype           = "dir";
        lifecycle.build = false;
      } ) ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = false;
      };
    };

    testPartialLc_lodash_Deserial_3 = {
      expr = ( mefsLc ( metaRaw // {
        metaFiles.plock.hasInstallScript = true;
      } ) ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = true;
      };
    };

    testPartialLc_lodash_Deserial_4 = {
      expr = ( mefsLc ( metaRaw // {
        metaFiles.pjs.scripts.preinstall = ":";
      } ) ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = true;
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
