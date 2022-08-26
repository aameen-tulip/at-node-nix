# ============================================================================ #
#
# Currently this just has a function `runSimple' that assigns true/false to
# tests which pass/fail.
#
# TODO: ignored(Keys|Idents)
# TODO: Preserve `rootKey'
# TODO: Args from `metaSet'
# TODO: Args from `(build|host|target)Platform'
# TODO: "Out of tree" entries for `link' and `path'
# TODO: `git' entries ( I think these are fine, just want to sanity check )
#
# ---------------------------------------------------------------------------- #

{ lib, flocoConfig ? {}, ...  } @ args: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libtree)
    idealTreeMetaSetPlockV2
  ;

# ---------------------------------------------------------------------------- #

  # A trivially simple lock written manually.
  plock0 = {
    name            = "test";
    version         = "0.0.1";
    lockfileVersion = 2;
    requires        = true;
    packages = {
      "" = {
        name              = "test";
        version           = "0.0.1";
        dependencies.a    = "^1.0.0";
        devDependencies.b = "^1.0.0";
      };
      "node_modules/a" = {
        version = "1.0.0";
        resolved = "https://example.com/a";
        integrity = "sha512-phony=";
      };
      "node_modules/b" = {
        version        = "1.0.1";
        dependencies.c = "^2.0.0";
        dev            = true;
        resolved       = "https://example.com/b";
        integrity      = "sha512-phony=";
      };
      "node_modules/c" = {
        version   = "2.1.1";
        dev       = true;
        resolved  = "https://example.com/c";
        integrity = "sha512-phony=";
      };
    };
    dependencies = {
      a = {
        version    = "1.0.0";
        resolved   = "https://example.com/a";
        integrity  = "sha512-phony=";
      };
      b = {
        version    = "1.0.1";
        dev        = true;
        resolved   = "https://example.com/b";
        integrity  = "sha512-phony=";
        requires.c = "^2.0.0";
      };
      c = {
        version   = "2.1.1";
        dev       = true;
        resolved  = "https://example.com/c";
        integrity = "sha512-phony=";
      };
    };
  };

  # A real lock.
  plock1 = lib.importJSON' ./data/it2-package-lock.json;

  # A lock with nested optionals.
  # We use this to ensure that if a package if dropped, any subdirs are also
  # dropped ( even if they lack a system conditional ).
  # I trimmed this lock down to only the required fields.
  # NOTE: In the test runner we hard code `x86_64-linux' as the host system, so
  # these values are written to be included/filtered base on that.
  # That system setting is just used for filtering and is more or less arbitrary
  # for the purposes of this test.
  plock2 = {
    name    = "test";
    version = "2.0.0";
    packages = {
      # Keep
      "node_modules/a" = {
        optional = true;
        version  = "1.0.0";
        os       = ["linux"];
        cpu      = ["x64"];
      };
      "node_modules/a/node_modules/c" = {
        optional = true;
        version  = "1.0.0";
      };
      "node_modules/e" = {
        optional = true;
        version  = "1.0.0";
        os       = ["linux"];
      };
      "node_modules/f" = {
        optional = true;
        version  = "1.0.0";
        cpu      = ["x64"];
      };
      # Drop
      "node_modules/b" = {
        optional = true;
        version  = "1.0.0";
        os       = ["darwin"];
        cpu      = ["x64"];
      };
      "node_modules/b/node_modules/d" = {
        optional = true;
        version  = "1.0.0";
      };
      "node_modules/g" = {
        optional = true;
        version  = "1.0.0";
        os       = ["darwin"];
      };
      "node_modules/h" = {
        optional = true;
        version  = "1.0.0";
        cpu      = ["arm64"];
      };
    };
  };


# ---------------------------------------------------------------------------- #

  # NOTE: the `config' default at the top supplies system; but we won't assume
  # that we're running in impure mode.
  # With that in mind we explicitly pass `system' in most test cases.
  tests = {

    # Dead simple test.
    testNoMetaDev0 = {
      expr = idealTreeMetaSetPlockV2 {
        plock  = plock0;
        system = "x86_64-linux";  # remember this is just filler.
      };
      expected = {
        "node_modules/a" = "a/1.0.0";
        "node_modules/b" = "b/1.0.1";
        "node_modules/c" = "c/2.1.1";
      };
    };

    # Drop `dev'
    testNoMetaProd0 = {
      expr = idealTreeMetaSetPlockV2 {
        plock  = plock0;
        system = "x86_64-linux";  # remember this is just filler.
        dev    = false;
      };
      expected = {
        "node_modules/a" = "a/1.0.0";
      };
    };

    # Just make sure this doesn't crash.
    # We just ensure that the paths match up using `deepSeq' to force eval.
    testNoMetaDev1 = {
      expr = let
        rsl' = idealTreeMetaSetPlockV2 {
          plock  = plock1;
          system = "x86_64-linux";  # remember this is just filler.
        };
        rsl = builtins.deepSeq rsl' rsl';
      in builtins.attrNames rsl;
      expected = builtins.attrNames ( removeAttrs plock1.packages [""] );
    };

    # Just make sure this doesn't crash.
    # We just ensure that the paths match up using `deepSeq' to force eval.
    testNoMetaProd1 = {
      expr = let
        rsl' = idealTreeMetaSetPlockV2 {
          plock  = plock1;
          system = "x86_64-linux";  # remember this is just filler.
          dev    = false;
        };
        rsl = builtins.deepSeq rsl' rsl';
      in builtins.attrNames rsl;
      expected = let
        nd = lib.filterAttrs ( _: v: ! ( v.dev or false ) ) plock1.packages;
      in builtins.attrNames ( removeAttrs nd [""] );
    };

    testNoMetaSys = {
      expr = idealTreeMetaSetPlockV2 {
        plock  = plock2;
        system = "x86_64-linux";
      };
      expected = {
        "node_modules/a"                = "a/1.0.0";
        "node_modules/a/node_modules/c" = "c/1.0.0";
        "node_modules/e"                = "e/1.0.0";
        "node_modules/f"                = "f/1.0.0";
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
