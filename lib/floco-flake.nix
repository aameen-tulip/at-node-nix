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
  , rootKey      ? metaSet.__meta.rootKey or args.rootEnt.key or null
  , rootEnt      ? if rootKey == null then null else metaSet.${rootKey} or null
  } @ args: let
    lows  = metaSet.__entries or metaSet;
    highs = if depsPriority == "high" then lows else
            if ( rootPriority == "high" ) && ( rootEnt != null ) then {
              ${rootKey} = rootEnt;
            } else {};
  in final: prev: let
    lproc = acc: key: if prev ? ${key} then acc else acc // {
      ${key} = lows.${key};
    };
    lkeeps = builtins.foldl' lproc {} ( builtins.attrNames lows );
  in lkeeps // highs;


# ---------------------------------------------------------------------------- #

  # TODO: `fenv'

  # FIXME: if plock and cache are disable use `metaEntFromSerial'
  # on `package.json'.
  # FIXME: read packuments?
  # FIXME: read `tree.nix' and `fetchInfo.nix'.
  loadMetaFiles' = {
    pdir
  , cacheFile   ? null
  , enablePlock ? true
  , enableCache ? true
  , metaSet     ? lib.mkMetaSet {}
  } @ args: let
    # Metadata scraped from the lockfile without any overrides by the cache.
    lockMeta = let
      lm = lib.metaSetFromPlockV3 {
        lockDir = pdir;
      };
    in if builtins.pathExists ( pdir + "/package-lock.json" ) then lm else {};

    # Metadata defined explicitly in `meta.nix' or `meta.json' ( if any )
    cacheMeta = let
      mjp      = pdir + "/meta.json";
      mnp      = pdir + "/meta.nix";
      metaJSON = lib.importJSON mjp;
      metaRaw  = if builtins.pathExists mnp then import mnp else
                 if builtins.pathExists mjp then lib.importJSON mjp else {};
    in if metaRaw == {} then {} else lib.metaSetFromSerial metaRaw;

    # Merged cache + lockfile
    merged = let
      co  = metaSetAsOverlay' { metaSet = cacheMeta; rootKey = null; };
      lo  = metaSetAsOverlay' { metaSet = lockMeta; };
      co' = if ( ! enableCache ) || ( cacheMeta == {} ) then [] else [co];
      lo' = if ( ! enablePlock ) || ( lockMeta == {} ) then [] else [lo];
      ov  = lib.composeManyExtensions ( co' ++ lo' );
    in metaSet.__extend ov;
  in {
    metaSet = merged;
    inherit cacheMeta lockMeta;  # Included for debugging, may be empty.
  };


# ---------------------------------------------------------------------------- #

in {

  inherit
    metaSetAsOverlay'
    loadMetaFiles'
  ;

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
