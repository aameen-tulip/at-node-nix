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
    pkg_tarball
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
    plTarballEnts = let
      pkgs = let
        named = lib.libattrs.pushDownNames ( removeAttrs arb3.packages [""] );
        vals  = builtins.attrValues named;
      in if limit < 1000 then lib.take limit vals else vals;

      proc = acc: p: let
        ent = removeAttrs p ["name"];
      in acc // {
          "testPlockEntryTarball_${p.name}" = {
            expr     = pkg_tarball ent;
            expected = ent;
          };
        };
    in builtins.foldl' proc {} pkgs;

# ---------------------------------------------------------------------------- #

  in npmTop1000 // plTarballEnts // {

    inherit packs arb2 arb3 lib yt;

# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
