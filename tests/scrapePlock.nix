# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib
, flocoScrape    ? null
, system         ? builtins.currentSystem
, snapDerivation
}: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

  fslib = flocoScrape.lib;
  fsenv = flocoScrape.${system};
  slib  = fsenv.lib;
  inherit (slib) flocoFetch;
  inherit (fsenv)
    flocoEnv
    optimizeFetchInfo optimizeFetchInfoSet
  ;

# ---------------------------------------------------------------------------- #

  data  = import ./data;
  plock = data.plocks.arb3;
  # Derive a phony `package.json' from `package-lock.json' info.
  pjs = { inherit (plock) name version; };
  # A phony project dir so that `flocoFetch' and `[f]slib' have a real tree to
  # play with.
  source = snapDerivation {
    name = "test-scrape-plock-phony-project";
    pjs  = builtins.toJSON pjs;
    buildCommand = ''
      mkdir -p "$out";
      echo "$pjs" > "$out/package.json";
    '';
  };
  lockDir = source.outPath;
  rootKey = plock.name + "/" + plock.version;
  acKey   = "@adobe/css-tools/4.0.1";  # An arbitrary tarball dep.

  # TODO: use `fslib'
  metaSet = lib.metaSetFromPlockV3 ( flocoEnv // { inherit lockDir plock; } );

  # NOTE: This could be incredibly slow if you tried to optimize all of them.
  # This is a good opportunity to ensure that we lazily optimize `fetchInfo'.
  #
  # The case where I'm not 100% sure that we care about laziness is if we call
  # `metaSetOpt.__serial."foo/1.0.0"' - ideally this /should/ be lazy but at
  # time of writing I'm not sure that it really is.
  # This isn't really a problem though because the user could just as easily
  # call `optimizeFetchInfo metaSet."foo/1.0.0"' if they want to limit things;
  # but still, I want to aknowledge that we really should improve `__serial' to
  # let this laziness work.
  metaSetOpt = optimizeFetchInfoSet metaSet;


# ---------------------------------------------------------------------------- #

  # Only usable in impure mode with IFD.
  # `default.nix' handles this and ensures that the `flocoScrape' are will not
  # be passed if these conditions are not met, so we can just return an empty
  # set to avoid crashing.
  tests = if flocoScrape == null then {} else {

    env = {
      inherit
        plock pjs source
        metaSet metaSetOpt
        lib slib fslib
        flocoScrape flocoEnv flocoFetch
        optimizeFetchInfo optimizeFetchInfoSet
      ;
    };

# ---------------------------------------------------------------------------- #

    testMetaSet_serialize_0 = {
      expr     = builtins.deepSeq metaSet.__serial true;
      expected = true;
    };

# ---------------------------------------------------------------------------- #

    # Ensure we optmized a `fetchurlDrv' argset to `fetchTree' args.
    testMetaSetOpt_fetchInfo = let
      ffs = yt.FlocoFetch.Structs;
    in {
      expr = {
        old = let
          fi = metaSet.${acKey}.fetchInfo;
        in ( fi.type == "file" ) && ( ! ( fi ? narHash ) ) && ( fi ? hash ) &&
           ( ! fi.unpack );
        new = ffs.fetch_info_tarball.check metaSetOpt.${acKey}.fetchInfo;
      };
      expected = { old = true; new = true; };
    };


# ---------------------------------------------------------------------------- #

    # XXX: if this test fails it's likely because you changed the `fetchInfo'
    # argset to include `basedir' or something.
    # Do not hesistate to modify how this test pulls the `package.json' file.
    testMetaSetOpt_fetchInfo_path = {
      expr = let
        pjsPath = metaSetOpt.${rootKey}.fetchInfo.path + "/package.json";
      in lib.importJSON pjsPath;
      expected = pjs;
    };


# ---------------------------------------------------------------------------- #




# ---------------------------------------------------------------------------- #

  };  # End tests

# ---------------------------------------------------------------------------- #

in tests

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
