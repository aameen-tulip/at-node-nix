# ============================================================================ #
#
# Tests for `libplock' routines related to `package-lock.json(v1)', specifically
# fetchers and dependency graphs.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libplock)
    pinVersionsFromPlockV3
  ;


# ---------------------------------------------------------------------------- #

  # V2 Lockfiles
  plv2-it = lib.importJSON ./data/plv2-it.json;
  # V2 with minimal fields for a few resolution tests
  plv2-simple-phony = {
    name            = "test";
    version         = "1.0.0";
    lockfileVersion = 2;
    packages = {
      "" = {
        name = "test";
        version = "1.0.0";
        dependencies = {
          a = "^0.0.1";
        };
        devDependencies = {
          d = "^0.0.4";
        };
        peerDependencies."e" = "^0.0.5";  # Shouldn't be pinned.
      };
      "node_modules/a" = {
        version = "0.0.1";
        dependencies = {
          b = "^0.0.2";
          c = "^0.0.3";
        };
      };
      "node_modules/a/node_modules/b".version = "0.0.2";
      "node_modules/a/node_modules/c".version = "0.0.3";
      "node_modules/d" = {
        version = "0.0.4";
        dev = true;
        requires.a = "*";
      };
    };
  };

  # V2 with subidrs sensitive to `requires'
  plv2-req-phony = {
    name            = "test";
    version         = "1.0.0";
    lockfileVersion = 2;
    packages = {
      "" = {
        name = "test";
        version = "1.0.0";
        dependencies = {
          a = "^0.0.1";
        };
        devDependencies = {
          d = "^1.0.4";
        };
        peerDependencies."e" = "^0.0.5";  # Shouldn't be pinned.
      };
      "node_modules/a" = {
        version = "0.0.1";
        dependencies = {
          b = "^0.0.2";
          c = "^0.0.3";
        };
      };
      "node_modules/a/node_modules/b" = {
        version = "0.0.2";
        dependencies.d = "^1.0.4";  # Conflicts with the one needed by `test'
      };
      "node_modules/a/node_modules/b/node_modules/d".version = "1.0.4";
      "node_modules/a/node_modules/c" = {
        version = "0.0.3";
        requires.d = "^0.0.4";  # Conflicts with version used by `b' and `test'.
      };
      "node_modules/d" = {
        version = "0.0.4";
        dev = true;
        requires.a = "*";
      };
    };
  };


/* -------------------------------------------------------------------------- */

  keeps  = {
    dependencies         = true;
    devDependencies      = true;
    optionalDependencies = true;
    peerDependencies     = true;
    requires             = true;
  };

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  tests = {

    testPinSimplePhony = {
      expr = let
        pinned = pinVersionsFromPlockV3 plv2-simple-phony;
        flt = _: builtins.intersectAttrs keeps;
      in builtins.mapAttrs flt pinned.packages;
      expected = {
        "".dependencies.a               = "0.0.1";
        "".devDependencies.d            = "0.0.4";
        "".peerDependencies.e           = "^0.0.5";
        "node_modules/a".dependencies.b = "0.0.2";
        "node_modules/a".dependencies.c = "0.0.3";
        "node_modules/d".requires.a     = "0.0.1";
        "node_modules/a/node_modules/b" = {};
        "node_modules/a/node_modules/c" = {};
      };
    };

    testPinRequiresPhony = {
      expr = let
        pinned = pinVersionsFromPlockV3 plv2-req-phony;
        flt = _: builtins.intersectAttrs keeps;
      in builtins.mapAttrs flt pinned.packages;
      expected = {
        "".dependencies.a               = "0.0.1";
        "".devDependencies.d            = "0.0.4";
        "".peerDependencies.e           = "^0.0.5";
        "node_modules/a".dependencies.b = "0.0.2";
        "node_modules/a".dependencies.c = "0.0.3";
        "node_modules/d".requires.a     = "0.0.1";
        "node_modules/a/node_modules/b".dependencies.d = "1.0.4";
        "node_modules/a/node_modules/b/node_modules/d" = {};
        "node_modules/a/node_modules/c".requires.d = "0.0.4";
      };
    };

  };


# ---------------------------------------------------------------------------- #

in tests

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
