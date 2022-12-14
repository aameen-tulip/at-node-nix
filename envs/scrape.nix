# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib
# the IFD setting is ignored for certain utilities such as `optimizeFetchInfo'
, ifd
, typecheck
, system ? builtins.currentSystem

, registryScopes

# from `rime'. Made optional so `libOnly' can work.
, urlFetchInfo ? rimePkgs.urlFetchInfo
, collectTarballManifest ? null

, pacote ? null # Globally installed executable

, rimePkgs ? nixpkgs.legacyPackages.${system}.extend rime.overlays.default
, nixpkgs
, rime

, libOnly ? system == "unknown"

} @ globalArgs: assert builtins ? currentSystem; let

# ---------------------------------------------------------------------------- #

  flocoScrapeEnv = {

    flocoEnv = {
      inherit ifd typecheck;
      pure         = false;
      allowedPaths = [];
    };

    # TODO: inject into `libreg'
    inherit registryScopes;

    lib = let
      configured = globalArgs.lib.mkFenvLibSet flocoScrapeEnv.flocoEnv;
    in configured // {
      _libEnvInfo = {
        name = "scrape[${if ifd then "" else "no "}IFD]";
        inherit ifd typecheck;
        pure = false;
      };
    };

    flocoFetch = lib.mkFlocoFetcher ( flocoScrapeEnv.flocoEnv // {
        inherit (flocoScrapeEnv.lib.libfetch) fetchers;
      } );

    inherit (import ../pkgs/optimizeFetchInfo.nix {
      inherit urlFetchInfo lib;
      pure = false;
    }) optimizeFetchInfo optimizeFetchInfoSet;

    inherit
      collectTarballManifest
      pacote
    ;

  };  # End flocoScrapeEnv


# ---------------------------------------------------------------------------- #

in if libOnly then flocoScrapeEnv.lib else flocoScrapeEnv

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
