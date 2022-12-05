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

    getFsMeta = ent: let
      source = flocoScrapeEnv.flocoFetch ent;
    in flocoScrapeEnv.lib.libmeta.tryCollectMetaFromDir source;

    scrapeDirTbDeps = pathlike: let
      ms = flocoScrapeEnv.lib.libmeta.metaSetEntListsFromDir pathlike;
      # Merge existing entries and yank `fetchInfo'.
      # In the majority of cases this only matters for the root project.
      mkScrapedEnt = ents: let
        merged = lib.libmeta.mergeMetaEntList ents;
        opt    = if merged.fetchInfo.type == "file"
                 then flocoScrapeEnv.optimizeFetchInfo merged
                 else merged;
        scrape = flocoScrapeEnv.getFsMeta opt;
        sent   = lib.libmeta.mkMetaEnt ( scrape // {
          inherit (merged) ident version key;
          inherit (opt) fetchInfo;
          entFromtype = "raw";
          metaFiles   = {
            __serial = lib.libmeta.serialIgnore;
          } // ( scrape.metaFiles or {} );
        } );
        pjsEnt' = let
          pent = flocoScrapeEnv.lib.libpjs.metaEntFromPjsNoWs {
            inherit (opt) ltype;
            inherit (scrape.metaFiles) pjs;
            isLocal = false;
            noFs    = true;
          };
        in if ! ( scrape ? metaFiles.pjs ) then [] else [pent];
        # Don't add the scraped info if we already have an `srcdir' record.
        #should = ( opt.fetchInfo != merged.fetchInfo ) ||
        #         ( ! ( builtins.any ( e: e.entFromtype == "srcdir" ) ) );
        should = true;
      in if should then [sent] ++ pjsEnt' else [];
      addScraped = ms.__mapEnts ( _: prev: ( mkScrapedEnt prev ) ++ prev );
    in addScraped.__mapEnts ( _: lib.libmeta.mergeMetaEntList );

    flocoShowDir = pathlike: let
      ms = flocoScrapeEnv.scrapeDirTbDeps pathlike;
      exSerial = ms.__mapEnts ( _: prev: prev.__update {
        metaFiles = let
          dropS = removeAttrs prev.metaFiles ["__serial"];
        in if ! ( prev ? metaFiles ) then {} else
           dropS // ( builtins.mapAttrs ( _: builtins.toJSON ) dropS );
      } );
    in exSerial.__serial;


  };  # End flocoScrapeEnv


# ---------------------------------------------------------------------------- #

in if libOnly then flocoScrapeEnv.lib else flocoScrapeEnv

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
