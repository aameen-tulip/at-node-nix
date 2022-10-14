# ============================================================================ #
#
# General tests for `flocoPackages' routines.
# This largely means testing overlays that are used to construct a set of
# `flocoPackages' across multiple projects or files.
#
# ---------------------------------------------------------------------------- #

{ lib
, pkgsFor
}: let

# ---------------------------------------------------------------------------- #

  # An overlay that add `msgpack'.
  # This only depends on the builder `buildGyp', and not any Node.js modules.
  overlays.msgpack = final: prev: {
    flocoPackages = lib.addFlocoPackages prev {
      "msgpack/1.0.3" = import ../build-support/msgpack.nix {
        inherit (final) buildGyp;
      };
      msgpack = final.flocoPackages."msgpack/1.0.3";
    };
  };


# ---------------------------------------------------------------------------- #

  tests = {

    # Test a trivial extension with no previous package set.
    testAddFlocoPackages_0 = {
      expr = removeAttrs ( lib.addFlocoPackages {} { foo = 1; } ) [
        "extend" "__unfix__"
      ];
      expected = { foo = 1; };
    };

    # Test a trivial extension with a previous package set.
    testAddFlocoPackages_1 = {
      expr = removeAttrs ( lib.addFlocoPackages {
        flocoPackages.bar = 2;
      } { foo = 1; } ) [
        "extend" "__unfix__"
      ];
      expected = { foo = 1; bar = 2; };
    };

    # Test a trivial extension with a previous extensible package set.
    testAddFlocoPackages_2 = let
      fp = lib.makeExtensible ( final: { bar = 2; } );
      added = lib.addFlocoPackages { flocoPackages = fp; } { foo = 1; };
    in {
      expr     = removeAttrs added ["extend" "__unfix__"];
      expected = { foo = 1; bar = 2; };
    };

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
