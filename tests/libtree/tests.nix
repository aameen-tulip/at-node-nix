# ============================================================================ #
#
# General tests for `libtree' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  tests = {

# ---------------------------------------------------------------------------- #

    testGenMkNmDirArgsSimple = {
      expr = lib.libtree.genMkNmDirArgsSimple {
        "node_modules/@foo/bar" = "@foo/bar/1.0.0";
        "node_modules/@foo/quux" = "@foo/quux/4.2.0";
      };
      expected = {
        "@foo/bar"  = false;
        "@foo/quux" = false;
      };
    };


# ---------------------------------------------------------------------------- #

    testParentNmDir_0 = {
      expr = map lib.libtree.parentNmDir [
        "node_modules/foo"
        "node_modules/@foo/bar"
        "node_modules/foo/node_modules/bar"
        "node_modules/@foo/bar/node_modules/baz"
        "node_modules/@foo/bar/node_modules/@baz/quux"
        "node_modules/foo/node_modules/@bar/baz"
        "$node_modules_path/foo"
        "$node_modules_path/@foo/bar"
        "$node_modules_path/foo/node_modules/bar"
        "$node_modules_path/@foo/bar/node_modules/baz"
        "$node_modules_path/@foo/bar/node_modules/@baz/quux"
        "$node_modules_path/foo/node_modules/@bar/baz"
        "node_modules"
        "$node_modules_path"
        "node_modules_path/@foo/bar"
        "node_modules/@foo/node_modules"
      ];
      expected = [
        "node_modules"
        "node_modules"
        "node_modules/foo/node_modules"
        "node_modules/@foo/bar/node_modules"
        "node_modules/@foo/bar/node_modules"
        "node_modules/foo/node_modules"
        "$node_modules_path"
        "$node_modules_path"
        "$node_modules_path/foo/node_modules"
        "$node_modules_path/@foo/bar/node_modules"
        "$node_modules_path/@foo/bar/node_modules"
        "$node_modules_path/foo/node_modules"
        null
        null
        null
      ];
    };

    # Assert failures for all of these
    testParentNmDir_1 = {
      expr = builtins.all ( s: ! ( builtins.tryEval s ).success ) [
        "node_modules/node_modules"
        "node_modules/@foo/bar/node_modules/node_modules"
        "node_modules/bar/node_modules/node_modules"
        "$node_modules_path/node_modules"
      ];
      expected = true;
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
