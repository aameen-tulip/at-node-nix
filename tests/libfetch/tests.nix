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
    #testIdentifyResolvedFetcherFamily_path = {
    #  expr = let
    #    tagged = lib.libfetch.identifyResolvedFetcherFamily projd.entries.plock.resolved;
    #  in lib.libtag.tagName tagged;
    #  expected = "path";
    #};

    testIdentifyResolvedFetcherFamily_file = {
      expr = let
        resolved = ts.entries.plock.resolved;
      in lib.libfetch.identifyResolvedFetcherFamily resolved;
      expected = "file";
    };

    testIdentifyResolvedFetcherFamily_git = {
      expr = let
        resolved = lodash.entries.plock.resolved;
      in lib.libfetch.identifyResolvedFetcherFamily resolved;
      expected = "git";
    };


# ---------------------------------------------------------------------------- #

    testFlocoGitFetcher_0 = {
      expr = let
        fetched = lib.libfetch.flocoGitFetcher lodash.entries.plock;
      in ( lib.isStorePath fetched.outPath ) &&
         ( fetched.type == "git" ) && ( fetched.fetchInfo.type == "github" );
      expected = true;
    };

    testFlocoGitFetcher_1 = {
      expr = let
        fetched = lib.libfetch.flocoGitFetcher lodash.entries.plock;
      in fetched.fetchInfo.rev;
      expected = "2da024c3b4f9947a48517639de7560457cd4ec6c";
    };

    testFlocoGitFetcher_2 = let
      prep =
        lib.libfetch.flocoGitFetcher.__processArgs lib.libfetch.flocoGitFetcher;
      base = "git+https://code.tvl.fyi/depot.git";
      ref  = "refs/heads/canon";
      rev  = "57cf952ea98db70fcf50ec31e1c1057562b0a1df";
      url  = "${base}?rev=${rev}&ref=${ref}";
    in {
      expr     = prep { inherit url; };
      expected = {
        #url  = "git+https://code.tvl.fyi/depot.git?rev=57cf952ea98db70fcf50ec31e1c1057562b0a1df&ref=refs/heads/canon";
        url  = "https://code.tvl.fyi/depot.git";
        name = "depot";
        inherit ref rev;
        allRefs    = true;
        shallow    = false;
        submodules = false;
      };
    };

    # NOTE: this fails if you try to include the params in `url'.
    testFlocoGitFetcher_3 = let
      fetched = lib.libfetch.flocoGitFetcher {
        name = "depot";
        url  = "https://code.tvl.fyi/depot.git";
        ref  = "refs/heads/canon";
        rev  = "57cf952ea98db70fcf50ec31e1c1057562b0a1df";
      };
    in {
      expr = ( removeAttrs fetched ["outPath"] ) // {
        sourceInfo = removeAttrs fetched.sourceInfo ["outPath"];
      };
      expected = {
        _type = "fetched";
        fetchInfo = {
          allRefs = true;
          name = "depot";
          ref = "refs/heads/canon";
          rev = "57cf952ea98db70fcf50ec31e1c1057562b0a1df";
          shallow = false;
          submodules = false;
          url = "https://code.tvl.fyi/depot.git";
        };
        # outPath = "/nix/store/...";
        sourceInfo = {
          lastModified = 1667488239;
          lastModifiedDate = "20221103151039";
          narHash = "sha256-8v2xS7pvkA1coe3Ys/eFxK3m3Uw+O9loJChOLbLI5bQ=";
          # outPath = "/nix/store/...";
          rev = "57cf952ea98db70fcf50ec31e1c1057562b0a1df";
          revCount = 17351;
          shortRev = "57cf952";
          submodules = false;
        };
        type = "git";
      };  # End Expected
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
