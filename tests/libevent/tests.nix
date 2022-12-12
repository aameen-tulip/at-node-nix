# ============================================================================ #
#
# General tests for `libevent' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  data = {

    partialLcRaw = {
      "lodash/4.17.21" = {
        ident             = "lodash";
        version           = "4.17.21";
        key               = "lodash/4.17.21";
        ltype             = "file";
        entFromtype       = "package.json";
        lifecycle.install = false;
        depInfo           = {};
        sysInfo           = {};
        fetchInfo         = {
          type    = "tarball";
          url     = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz";
          narHash = "sha256-amyN064Yh6psvOfLgcpktd5dRNQStUYHHoIqiI6DMek=";
        };
      };
    };  # End Partial

    partialLcMe_lodash = lib.libmeta.metaEntFromSerial' {
      ifd = false; pure = true; allowedPaths = []; typecheck = false;
    } data.partialLcRaw."lodash/4.17.21";

  };

# ---------------------------------------------------------------------------- #

  tests = {

# ---------------------------------------------------------------------------- #

    testPartialLc_lodash_Deserial = {
      expr = let
        me =
          data.partialLcMe_lodash.__extend lib.libevent.metaEntLifecycleOverlay;
      in me.lifecycle;
      expected = {
        build   = false;
        prepare = false;
        pack    = false;
        test    = false;
        publish = false;
        install = false;
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
