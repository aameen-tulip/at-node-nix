# ============================================================================ #
#
# General tests for `libfetch' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  lockDir = toString ./data/proj2;
  metaSet = lib.libmeta.metaSetFromPlockV3 { inherit lockDir; };
  proj2   = metaSet."proj2/1.0.0";
  lodash  = metaSet."lodash/5.0.0";
  ts      = metaSet."typescript/4.8.2";
  projd   = metaSet."projd/1.0.0";


# ---------------------------------------------------------------------------- #

  tests = {

    env = {
      inherit metaSet proj2 lodash ts projd;
    };

# ---------------------------------------------------------------------------- #

    testFlocoFetcher = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher {};
      in builtins.mapAttrs ( _: v: if v ? outPath then true else v ) {
        dir = flocoFetcher proj2;
        # NOTE: This test case will fail in GitHub Actions if you don't set up
        #       an SSH key authorized for your repo.
        #       If you fork this repo and it crashes here, setup a key, auth it,
        #       and add it to secrets.
        git  = flocoFetcher lodash;
        tar  = flocoFetcher ts;
        link = flocoFetcher projd;
      };
      expected = {
        dir  = true;
        git  = true;
        tar  = true;
        link = true;
      };
    };


# ---------------------------------------------------------------------------- #
 
    testCwdFlocoFetcher = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher { basedir = lockDir; };
        mapFetch = builtins.mapAttrs ( _: flocoFetcher );
      in builtins.mapAttrs ( _: v: builtins.deepSeq v true ) {
        plents = mapFetch metaSet.__meta.plock.packages;
        msents = mapFetch metaSet.__entries;
      };
      expected = {
        plents = true;
        msents = true;
      };
    };


# ---------------------------------------------------------------------------- #

    # FIXME: link
    #testIdentifyResolvedType_path = {
    #  expr = let
    #    tagged = lib.libfetch.identifyResolvedType projd.entries.plock.resolved;
    #  in lib.libtag.tagName tagged;
    #  expected = "path";
    #};

    testIdentifyResolvedType_file = {
      expr = let
        tagged = lib.libfetch.identifyResolvedType ts.entries.plock.resolved;
      in lib.libtag.tagName tagged;
      expected = "file";
    };

    testIdentifyResolvedType_git = {
      expr = let
        tagged =
          lib.libfetch.identifyResolvedType lodash.entries.plock.resolved;
      in lib.libtag.tagName tagged;
      expected = "git";
    };


# ---------------------------------------------------------------------------- #

    testIdentifyPlentSourceType_path_0 = {
      expr = lib.libfetch.identifyPlentSourceType proj2.entries.plock;
      expected = "path";
    };

    testIdentifyPlentSourceType_path_1 = {
      expr = lib.libfetch.identifyPlentSourceType projd.entries.plock;
      expected = "path";
    };

    testIdentifyPlentSourceType_file = {
      expr = lib.libfetch.identifyPlentSourceType ts.entries.plock;
      expected = "file";
    };

    testIdentifyPlentSourceType_git = {
      expr = lib.libfetch.identifyPlentSourceType lodash.entries.plock;
      expected = "git";
    };


# ---------------------------------------------------------------------------- #

    testPlockEntryHashAttr_0 = {
      expr = lib.libfetch.plockEntryHashAttr ts.entries.plock;
      expected.sha512_sri = "sha512-C0I1UsrrDHo2fYI5oaCGbSejwX4ch+9Y5jTQELvovfmFkK3HHSZJB8MSJcWLmCUBzQBchCrZ9rMRV6GuNrvGtw==";
    };


# ---------------------------------------------------------------------------- #

    testFlocoGitFetcher_0 = {
      expr = let
        fetched = lib.libfetch.flocoGitFetcher lodash.entries.plock;
      in ( lib.isStorePath fetched.outPath ) && ( fetched.type == "github" );
      expected = true;
    };

    # TODO: test that we parse `rev' from URLs
    # TODO: test a non-github URI


# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
