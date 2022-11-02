# ============================================================================ #
#
# General tests for YANTS types.
#
# ---------------------------------------------------------------------------- #

{ lib
, limit ? 1000  # Limit the number of entries used for testing.
                # In the top level flake we don't want to check 1,000 packuments
}: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes;
  inherit (yt.PkgInfo.Strings)
    identifier_any
    identifier
    descriptor
  ;
  inherit (yt.Packument.Structs)
    packument
  ;
  inherit (yt.NpmLock.Structs)
    pkg_path_v3
    pkg_dir_v3
    pkg_link_v3
    pkg_tarball_v3
    pkg_git_v3
    package
  ;

  inherit ( import ../data/plocks.nix )
    arb2
    arb3
  ;

  allPacks = import ../data/packuments.nix;
  packs = if limit < 1000 then lib.take limit allPacks else allPacks;

# ---------------------------------------------------------------------------- #

  tests = let

    # Test our type spec against 1,000 packuments.
    # The data set is the top 1,000 on NPM's registry from ~2019.
    # NOTE:
    # `registry.npmjs.org' is just one registry, and others may have
    # different specs.
    # The type we've specificied is meant to be expanded over time.
    npmTop1000 = let
      proc = acc: p:
        acc // {
          "testPackumentSpec_${p._id}" = {
            expr     = packument.check p;
            expected = true;
          };

          "testIdentifierSpec_${p._id}" = {
            expr = let
              c = identifier_any.checkType p._id;
            in if c.ok then p._id else c.err;
            expected = p._id;
          };
        };
    in if lib.inPureEvalMode then {} else builtins.foldl' proc {} packs;

    # The `@floco/arbor' lock only uses registry tarballs.
    plockEnts = let
      pkgs = let
        named = lib.libattrs.pushDownNames arb3.packages;
        vals  = builtins.attrValues named;
      in if limit < 1000 then lib.take limit vals else vals;
      proc = acc: p: let
        tname = if p.name == "" then "ROOT" else p.name;
        ent = if p.name == "" then p // { inherit (arb3.packages."") name; }
                              else removeAttrs p ["name"];
        # We skip the root entry on this one.
        tb = lib.optionalAttrs ( p.name != "" ) {
          "testPlockEntryTarball_${p.name}" = {
            expr     = pkg_tarball_v3 ent;
            expected = ent;
          };
        };
      in acc // tb // {
          "testPlockEntryPackage_${tname}" = {
            expr     = package ent;
            expected = ent;
          };
      };
    in builtins.foldl' proc {} pkgs;

# ---------------------------------------------------------------------------- #

  in npmTop1000 // plockEnts // {

    inherit packs arb2 arb3 lib yt;

# ---------------------------------------------------------------------------- #

    testPkgPath3_0 = {
      expr     = pkg_path_v3.check { name = "foo"; version = "1.0.0"; };
      expected = true;
    };

    testPkgPath3_1 = {
      expr = pkg_path_v3.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = true;
    };

    testPkgPath3_2 = {
      expr = pkg_path_v3.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    testPkgDir3_0 = {
      expr     = pkg_dir_v3.check { name = "foo"; version = "1.0.0"; };
      expected = true;
    };

    testPkgDir3_1 = {
      expr = pkg_dir_v3.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = false;
    };

    testPkgDir3_2 = {
      expr = pkg_dir_v3.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    testPkgLink3_0 = {
      expr     = pkg_link_v3.check { name = "foo"; version = "1.0.0"; };
      expected = false;
    };

    testPkgLink3_1 = {
      expr = pkg_link_v3.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = true;
    };

    testPkgLink3_2 = {
      expr = pkg_link_v3.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = false;
    };


# ---------------------------------------------------------------------------- #

    testPkgGit3_0 = let
      ent = {
        version  = "5.0.0";
        resolved = "git+ssh://git@github.com/lodash/lodash.git" +
                   "#2da024c3b4f9947a48517639de7560457cd4ec6c";
        license = "MIT";
        engines.node = ">=4.0.0";
      };
    in {
      expr     = pkg_git_v3 ent;
      expected = ent;
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
