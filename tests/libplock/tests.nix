# ============================================================================ #
#
# Tests for `libplock' routines related to `package-lock.json(v1)', specifically
# fetchers and dependency graphs.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libplock)
    splitNmToIdentPath
    pathId
    parentPath
    resolveDepForPlockV1
    resolveDepForPlockV3
  ;

  yt = lib.ytypes;

  # V1 Lockfiles
  plv1-big   = lib.importJSON ./data/plv1-big.json;
  plv1-small = lib.importJSON ./data/plv1-small.json;
  plv1-dev   = lib.importJSON ./data/plv1-dev.json;
  plv2-fetch = lib.importJSON ../libfetch/data/proj2/package-lock.json;

  # V2 Lockfiles
  plv2-it = lib.importJSON ./data/plv2-it.json;
  # V2 with minimal fields for a few resolution tests
  plv2-res-phony = {
    name            = "test";
    version         = "1.0.0";
    lockfileVersion = 2;
    packages = {
      "".name    = "test";
      "".version = "1.0.0";
      "node_modules/a".version = "0.0.1";
      "node_modules/a/node_modules/b".version = "0.0.2";
      "node_modules/a/node_modules/c".version = "0.0.3";
      "node_modules/d".version = "0.0.4";
    };
  };


/* -------------------------------------------------------------------------- */

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  tests = {

# ---------------------------------------------------------------------------- #

    testSplitNmToIdentPath = {
      expr = splitNmToIdentPath "node_modules/foo/node_modules/@bar/quux";
      expected = ["foo" "@bar/quux"];
    };

    testPathId = {
      expr = pathId "node_modules/foo/node_modules/@bar/quux";
      expected = "@bar/quux";
    };

    testParentPath = {
      expr = map parentPath [
        "node_modules/foo/node_modules/@bar/quux"
        "node_modules/foo"
        ""
      ];
      expected = [
        "node_modules/foo"
        ""
        null
      ];
    };


# ---------------------------------------------------------------------------- #

    testResolveDepForPlockV3 = {
      expr = let
        res = { from, ident }: resolveDepForPlockV3 plv2-res-phony from ident;
      in map res [
        { from = ""; ident = "a"; }
        { from = ""; ident = "d"; }
        { from = ""; ident = "c"; }
        { from = ""; ident = "test"; }

        { from = "node_modules/a"; ident = "a"; }
        { from = "node_modules/a"; ident = "d"; }
        { from = "node_modules/a"; ident = "c"; }
        { from = "node_modules/a"; ident = "b"; }
        { from = "node_modules/a"; ident = "test"; }
      ];
      expected = [
        # From ""
        { ident = "a"; resolved = "node_modules/a"; value.version = "0.0.1"; }
        { ident = "d"; resolved = "node_modules/d"; value.version = "0.0.4"; }
        null
        { ident         = "test";
          resolved      = "";
          value.version = "1.0.0";
          value.name    = "test";
        }
        # From `node_modules/a'
        { ident = "a"; resolved = "node_modules/a"; value.version = "0.0.1"; }
        { ident = "d"; resolved = "node_modules/d"; value.version = "0.0.4"; }
        { ident         = "c";
          resolved      = "node_modules/a/node_modules/c";
          value.version = "0.0.3";
        }
        { ident         = "b";
          resolved      = "node_modules/a/node_modules/b";
          value.version = "0.0.2";
        }
        { ident         = "test";
          resolved      = "";
          value.version = "1.0.0";
          value.name    = "test";
        }
      ];
    };


# ---------------------------------------------------------------------------- #

    testResolveDepForPlockV1 = {
      expr = let
        res = { ident, ... } @ args: let
          ctx = ( removeAttrs args ["ident"] ) // { plock = plv1-dev; };
          rsl = resolveDepForPlockV1 ctx ident;
        in if rsl == null then null else rsl.resolved;
      in map res [
        { from = ""; ident = "@ampproject/remapping"; }
        { from = ""; ident = "phony"; }
      ];
      expected = [
        "node_modules/@ampproject/remapping"
        null
      ];
    };


# ---------------------------------------------------------------------------- #

    testIdentifyResolvedType_0 = {
      expr = let
        # We know that all of these are registry tarballs.
        haveResolved = lib.filterAttrs ( _: v: v ? resolved ) plv2-it.packages;
        identify = v: lib.libfetch.identifyResolvedType v.resolved;
        idrs = builtins.mapAttrs ( _: identify ) haveResolved;
        types = map builtins.attrNames ( builtins.attrValues idrs );
      in builtins.all ( t: t == ["file"] ) types;
      expected = true;
    };

    # This one has registry tarballs, links, and git.
    # It has paths as well; but those don't have a `resolved' field.
    testIdentifyResolvedType_1 = {
      expr = let
        haveResolved =
          lib.filterAttrs ( _: v: v ? resolved ) plv2-fetch.packages;
        identify = v: lib.libfetch.identifyResolvedType v.resolved;
        idrs = builtins.mapAttrs ( _: identify ) haveResolved;
      in builtins.concatMap builtins.attrNames ( builtins.attrValues idrs );
      expected = ["git" "path" "file"];
    };

    # Test a dir ( should be flagged in the same cases as `link' ).
    testIdentifyResolvedType_2 = {
      expr     = lib.libfetch.identifyResolvedType "../projd";
      expected = { path = "../projd"; };
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
