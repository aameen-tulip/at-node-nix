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

  metaRaw_lfi0  = metaRaw // { lifecycle.install = false; };
  metaRaw_lfi1  = metaRaw // { lifecycle.install = true; };
  metaRaw_lfb   = metaRaw // { ltype = "dir"; lifecycle.build = false; };
  metaRaw_lfmfi = metaRaw // { metaFiles.plock.hasInstallScript = true; };
  metaRaw_lfhi  = metaRaw // { hasInstallScript = true; };
  metaRaw_lfmfs = metaRaw // { metaFiles.pjs.scripts.preinstall = ":"; };

  mefsStrict = lib.libmeta.metaEntFromSerial' {
    ifd = false; pure = true; allowedPaths = []; typecheck = true;
  };
  mefsLc = m: ( mefsStrict m ).__extend lib.libevent.metaEntLifecycleOverlay;


# ---------------------------------------------------------------------------- #

  tests = {

    data = {
      inherit
        metaRaw
        metaRaw_lfi0
        metaRaw_lfi1
        metaRaw_lfb
        metaRaw_lfmfi
        metaRaw_lfhi
        metaRaw_lfmfs
      ;
    };

# ---------------------------------------------------------------------------- #

    testPartialLc_lodash_Deserial_0 = {
      expr = ( mefsLc metaRaw_lfi0 ).lifecycle;
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
      expr = ( mefsLc metaRaw_lfi1 ).lifecycle;
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
      expr = ( mefsLc metaRaw_lfb ).lifecycle;
      expected = {
        build   = true;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = false;
      };
    };

    testPartialLc_lodash_Deserial_3 = {
      expr = ( mefsLc metaRaw_lfmfi ).lifecycle;
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
      expr = ( mefsLc metaRaw_lfhi ).lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = true;
      };
    };

    testPartialLc_lodash_Deserial_5 = {
      expr = ( mefsLc metaRaw_lfmfs ).lifecycle;
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
