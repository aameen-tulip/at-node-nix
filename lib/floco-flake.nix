# ============================================================================ #
#
# Helpers to generate flakes and flake outputs.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  Strings.priority = yt.enum "priority" ["high" "medium" "low"];


# ---------------------------------------------------------------------------- #

  metaSetAsOverlay' = {
    metaSet
  , rootPriority ? "high"
  , depsPriority ? "low"
  }: let
    rootEnt = metaSet.${metaSet.__meta.rootKey} or null;
    lows    = metaSet.__entries or metaSet;
    highs   = if depsPriority == "high" then lows else
              if ( rootPriority == "high" ) && ( rootEnt != null ) then {
                ${metaSet.__meta.rootKey} = rootEnt;
              } else {};
  in final: prev: let
    lproc = acc: key: if prev ? ${key} then acc else acc // {
      ${key} = lows.${key};
    };
    lkeeps = builtins.foldl' lproc {} ( builtins.attrNames lows );
  in lkeeps // highs;


# ---------------------------------------------------------------------------- #

  # FIXME: if plock and cache are disable use `metaEntFromSerial'
  # on `package.json'.
  # FIXME: read packuments?
  # FIXME: read `tree.nix' and `fetchInfo.nix'.
  loadMetaFiles' = {
    pdir
  , cacheFile   ? null
  , flocoConfig ? {}
  , enablePlock ? true
  , enableCache ? true
  , metaSet     ? lib.mkMetaSet {}
  }: let
    # Metadata scraped from the lockfile without any overrides by the cache.
    lockMeta = sarcodes.lib.metaSetFromPlockV3 {
      lockDir = pdir;
      inherit flocoConfig;
    };
    # Metadata defined explicitly in `meta.nix' or `meta.json' ( if any )
    cacheMeta = let
      mjp      = "${pdir}/meta.json";
      mnp      = "${pdir}/meta.nix";
      metaJSON = nixpkgs.lib.importJSON mjp;
      metaRaw  = if builtins.pathExists mnp then import mnp else
                 if builtins.pathExists mjp then lib.importJSON mjp else {};
    in if metaRaw == {} then {} else lib.metaSetFromSerial metaRaw;
    # Merged cache + lockfile
    metaSet = lockMeta.__extend ( _: _: cacheMeta.__entries or cacheMeta );
  in {
    inherit cacheMeta lockMeta metaSet;
  };


# ---------------------------------------------------------------------------- #

  defPkgOverlays' = {

  }:


# ---------------------------------------------------------------------------- #

in {

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
