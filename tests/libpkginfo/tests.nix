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
    # Note that the "./<PATH>" prefixes will be retained, but not for
    # "." and "./" - if you really give a shit you should write your own.
    testPkgJsonForPath = let
      pwd = ( toString ./. );
    in {
      expr = map lib.libpkginfo.pjsPath [
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
        ./package.json "${pwd}/package.json" "${pwd}/package.json"
        "package.json" "./package.json" "${pwd}/package.json"
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
      expr = lib.libpkginfo.pjsBinPairs {
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
      expr = lib.libpkginfo.pjsBinPairs {
        bin.foo = "./hey.js";
        bin.bar = "./bin/bar.js";
      };
      expected = { bar = "bin/bar.js"; foo = "hey.js"; };
    };

    testPjsBinPairs_2 = {
      expr = lib.libpkginfo.pjsBinPairs {
        bname = "quux";
        bin   = "./bin/bar.js";
      };
      expected.quux = "bin/bar.js";
    };


# ---------------------------------------------------------------------------- #

    # TODO: test if `pure' and `ifd' work in a wider variety of cases.
    testCoercePjs_0 = let
      pjs = ( lib.libpkginfo.coercePjs ../pkg-set/data ).name;
    in {
      expr     = builtins.tryEval pjs;
      expected =
        if lib.inPureEvalMode then { success = false; value = false; } else
        { success = true; value = "ideal-tree-plock-v2-test"; };
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
