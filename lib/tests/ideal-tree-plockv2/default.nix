# ============================================================================ #
#
# TODO: Use the real test runner framework.
# TODO: Hook into `nix flake check' or a github action.
# Currently this just has a function `runSimple' that assigns true/false to
# tests which pass/fail.
#
# TODO: ignored(Keys|Idents)
# TODO: CPU/OS filtering
# TODO: CPU/OS filtering using (os|cpu)Cond
# TODO: Preserve `rootKey'
# TODO: Args from `metaSet'
# TODO: Args from `(build|host|target)Platform'
# TODO: "Out of tree" entries for `link' and `path'
# TODO: `git' entries ( I think these are fine, just want to sanity check )
#
# ---------------------------------------------------------------------------- #

{ lib ? import ../../default.nix { inherit (ak-nix) lib; inherit config; }
, config ? {
    enableImpureMeta = ! lib.inPureEvalMode;
  } // ( lib.optionalAttrs ( ! lib.inPureEvalMode ) {
    system = builtins.currentSystem;
  } )
##, writeText ? pkgsFor.writeText
## For fallback
##, pkgsFor ?
##    if ( config ? system ) then ( builtins.getFlake "nixpkgs" ).${config.system}
##                           else import <nixpkgs> {}
, ak-nix ? builtins.getFlake "github:aakropotkin/ak-nix"
} @ args: let

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
        devDependencies.b = "^1.0.0";
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
        resolved  = "https://example.com/b";
        integrity = "sha512-phony=";
      };
    };
    dependencies = {
      a = {
        version    = "1.0.0";
        resolved   = "https://example.com/a";
        integrity  = "sha512-phony=";
        requires.b = "^1.0.0";
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
        resolved  = "https://example.com/b";
        integrity = "sha512-phony=";
      };
    };
  };

  # A real lock.
  plock1 = lib.importJSON' ./package-lock-1.json;


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
      # Just
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
      # Just
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

  };


# ---------------------------------------------------------------------------- #

in {
  inputs = { inherit lib config writeText pkgsFor ak-nix; };
  inherit tests;
  runSimple =
    builtins.mapAttrs ( k: { expr, expected }: expr == expected ) tests;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
