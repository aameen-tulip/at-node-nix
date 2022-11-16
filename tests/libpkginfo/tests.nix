# ============================================================================ #
#
# General tests for `libpkginfo' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib) libpkginfo;

# ---------------------------------------------------------------------------- #

  tests = {

    # Confirm various type of path-likes produce paths to `package.json'.
    # Note that this function remains consistent with relative/absolute inputs.
    # The "interesting" case here is tested first, which is how the empty string
    # is handled, and how it differs from ".".
    # This is a piece of implementation minutae, but I have a hunch that I'll
    # be glad I tested this explicitly.
    testPkgJsonForPath = let
      pwd = ( toString ./. );
    in {
      expr = map lib.libpkginfo.pjsForPath [
        "" "./" "." ./.
        ( toString ./. )
        ( ( toString ./. ) + "/" )
        "package.json"
        "./package.json"
        ( ./. + "/package.json" )
        ( ( toString ./. ) + "/package.json" )
      ];
      expected = [
        "package.json" "package.json" "package.json"
        "${pwd}/package.json" "${pwd}/package.json" "${pwd}/package.json"
        "package.json" "package.json" "${pwd}/package.json"
        "${pwd}/package.json"
      ];
    };

    testRewriteDescriptors = let
      data = {
        name                = "test-pkg";
        version             = "0.0.1";
        dependencies.foo    = "^1.0.0";
        dependencies.bar    = "~1.0.0";
        dependencies.baz    = "github:fake/repo";
        devDependencies.foo = "^1.0.0";
      };
      xform = {
        foo = "2.0.0";
        bar = d: let
          m = builtins.match "[~=^]([0-9.]+)" d;
        in if m == null then d else builtins.head m;
        baz  = "/nix/store/XXXXXXX-repo.tgz";
        quux = "4.0.0";
      };
    in {
      expr = lib.libpkginfo.rewriteDescriptors {
        pjs      = data;
        resolves = xform;
      };
      expected = {
        name                = "test-pkg";
        version             = "0.0.1";
        dependencies.foo    = "2.0.0";
        dependencies.bar    = "1.0.0";
        dependencies.baz    = "/nix/store/XXXXXXX-repo.tgz";
        devDependencies.foo = "^1.0.0";
      };
    };


# ---------------------------------------------------------------------------- #

    testPjsBinPairs_0 = {
      expr = lib.libpkginfo.pjsBinPairs' {} {
        src             = ./data;
        directories.bin = "bin";
      };
      expected = {
        bar = "bin/bar.js";
        foo = "bin/foo.sh";
        baz = "bin/baz";
        # A subdirectory "sub/quux" should NOT be treated as a "bin".
      };
    };

    testPjsBinPairs_1 = {
      expr = lib.libpkginfo.pjsBinPairs' {} {
        bin.foo = "./hey.js";
        bin.bar = "./bin/bar.js";
      };
      expected = { bar = "bin/bar.js"; foo = "hey.js"; };
    };

    testPjsBinPairs_2 = {
      expr = lib.libpkginfo.pjsBinPairs' {} {
        bname = "quux";
        bin   = "./bin/bar.js";
      };
      expected.quux = "bin/bar.js";
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
