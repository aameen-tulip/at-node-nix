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
  inherit (yt.NpmLock.Strings)
    relative_file_uri
    git_uri
    tarball_uri
    resolved_uri
  ;
  inherit (yt.NpmLock.Structs)
    pkg_path
    pkg_dir
    pkg_link
    pkg_tarball
    pkg_git
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
            expr     = pkg_tarball ent;
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

    testPkgPath_0 = {
      expr     = pkg_path.check { name = "foo"; version = "1.0.0"; };
      expected = true;
    };

    testPkgPath_1 = {
      expr = pkg_path.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = true;
    };

    testPkgPath_2 = {
      expr = pkg_path.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    testPkgDir_0 = {
      expr     = pkg_dir.check { name = "foo"; version = "1.0.0"; };
      expected = true;
    };

    testPkgDir_1 = {
      expr = pkg_dir.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = false;
    };

    testPkgDir_2 = {
      expr = pkg_dir.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    testPkgLink_0 = {
      expr     = pkg_link.check { name = "foo"; version = "1.0.0"; };
      expected = false;
    };

    testPkgLink_1 = {
      expr = pkg_link.check {
        version  = "1.0.0";
        link     = true;
        resolved = "../foo";
      };
      expected = true;
    };

    testPkgLink_2 = {
      expr = pkg_link.check {
        version      = "1.0.0";
        dependencies = { bar = "^1.0.0"; };
      };
      expected = false;
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
