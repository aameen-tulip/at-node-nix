# ============================================================================ #
#
# General tests for `libfetch' routines.
#
# ---------------------------------------------------------------------------- #

{ lib
, system    ? "unknown"
, pure      ? lib.inPureEvalMode
, ifd       ? ( builtins.currentSystem or null ) == system
, typecheck ? true
}: let

# ---------------------------------------------------------------------------- #

  fenv = {
    inherit pure ifd typecheck;
    allowedPaths = [( toString ./data )];
  };


# ---------------------------------------------------------------------------- #

  lockDir = toString ./data/proj2;
  plock   = lib.importJSON ( lockDir + "/package-lock.json" );
  metaSet = lib.metaSetFromPlockV3 ( fenv // { inherit lockDir; } );

  proj2   = metaSet."proj2/1.0.0";
  lodash  = metaSet."lodash/5.0.0";
  ts      = metaSet."typescript/4.8.2";
  projd   = metaSet."projd/1.0.0";

  # These assert that `resolved = pkey' fallbacks allow `dir' entries to be
  # fetched correctly, without interfering with other types of entries -
  # particularly `link' entries.
  pl_proj2  = { resolved = ""; } // plock.packages."";
  pl_lodash = {
    resolved = "node_modules/lodash";
  } // plock.packages."node_modules/lodash";
  pl_ts = {
    resolved = "node_modules/typescript";
  } // plock.packages."node_modules/typescript";
  pl_projd = {
    resolved = "node_modules/projd";
  } // plock.packages."node_modules/projd";


# ---------------------------------------------------------------------------- #

  tests = {

    env = {
      inherit metaSet proj2 lodash ts projd;
    };

# ---------------------------------------------------------------------------- #

    # XXX: I'm unsure of why `basedir' in `flocoFetcher' doesn't NEED to be set.
    # I mean: it works, but it probably shouldn't for `projd'.

    testFlocoFetcher_ms = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher ( fenv // { basedir = lockDir; } );
      in builtins.mapAttrs ( _: v: if v ? outPath then true else v ) {
        dir = flocoFetcher proj2;
        # NOTE: This test case will fail in GitHub Actions if you don't set up
        #       an SSH key authorized for your repo.
        #       If you fork this repo and it crashes here, setup a key, auth it,
        #       and add it to secrets.
        git  = flocoFetcher lodash;
        file = flocoFetcher ts;
        link = flocoFetcher projd;
      };
      expected = {
        dir  = true;
        git  = true;
        file = true;
        link = true;
      };
    };

    testFlocoFetcher_pl = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher ( fenv // { basedir = lockDir; } );
      in builtins.mapAttrs ( k: v: v.ltype == k  ) {
        dir = flocoFetcher pl_proj2;
        # NOTE: This test case will fail in GitHub Actions if you don't set up
        #       an SSH key authorized for your repo.
        #       If you fork this repo and it crashes here, setup a key, auth it,
        #       and add it to secrets.
        git  = flocoFetcher pl_lodash;
        file = flocoFetcher pl_ts;
        link = flocoFetcher pl_projd;
      };
      expected = {
        dir  = true;
        git  = true;
        file = true;
        link = true;
      };
    };


# ---------------------------------------------------------------------------- #
 
    testCwdFlocoFetcher = {
      expr = let
        flocoFetcher = lib.mkFlocoFetcher ( fenv // { basedir = lockDir; } );
        mapFetch = let
          doFetchPlock = pkey: plent:
            flocoFetcher ( { resolved = pkey; } // plent );
          doFetch = key: x: let
            fetched =
              if x ? fetchInfo then flocoFetcher x else doFetchPlock key x;
          in lib.ytypes.FlocoFetch.fetched.check fetched;
        in builtins.mapAttrs doFetch;
        checkAll = v: builtins.all ( b: b ) ( builtins.attrValues v );
      in builtins.mapAttrs ( _: checkAll ) {
        plents = mapFetch metaSet._meta.plock.packages;
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
        resolved = pl_ts.resolved;
      in lib.libfetch.identifyResolvedFetcherFamily resolved;
      expected = "file";
    };

    testIdentifyResolvedFetcherFamily_git = {
      expr = let
        resolved = pl_lodash.resolved;
      in lib.libfetch.identifyResolvedFetcherFamily resolved;
      expected = "git";
    };


# ---------------------------------------------------------------------------- #

    testFlocoGitFetcher_0 = {
      expr = let
        fetched = lib.libfetch.flocoGitFetcher' fenv pl_lodash;
      in ( lib.isStorePath fetched.outPath ) &&
         ( fetched.ffamily == "git" ) && ( fetched.fetchInfo.type == "github" );
      expected = true;
    };

    testFlocoGitFetcher_1 = {
      expr = let
        fetched = lib.libfetch.flocoGitFetcher' fenv pl_lodash;
      in fetched.fetchInfo.rev;
      expected = "2da024c3b4f9947a48517639de7560457cd4ec6c";
    };

    testFlocoGitFetcher_2 = let
      prep = lib.processArgs ( lib.libfetch.flocoGitFetcher' fenv );
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
      fetched = lib.libfetch.flocoGitFetcher' fenv {
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
        ltype   = "git";
        ffamily = "git";
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
