# ============================================================================ #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;

in {

# ---------------------------------------------------------------------------- #

  Enums.fetchType =
    yt.enum "source-type" cond ["file" "tarball" "git" "github" "path"];

  # Project types recognized by NPM.
  # These are used to determine which lifecycle scripts are run.
  Enums.sourceType = let
    cond = x: builtins.elem x ["file" "path" "git"];
  in yt.restrict "npm" cond yt.FlocoFetch.Enums.fetchType;


# ---------------------------------------------------------------------------- #

  Structs.drvSourceInfo = yt.struct "sourceInfo:derivation" {
    outPath = yt.FS.store_path;
    narHash = yt.option yt.Hash.narHash;
  };


  Structs.fetched = yt.structs "fetched" {
    _type     = yt.restrict "_type[fetched]" ( s: s == "fetched" ) yt.string;
    type      = yt.FlocoFetch.Enums.sourceType;
    outPath   = yt.FS.store_path;
    passthru  = yt.option ( yt.attrs yt.any );
    meta      = yt.option ( yt.attrs yt.any );
    fetchInfo = yt.attrs yt.any;
    inherit (yt.FlocoFetch.Eithers) sourceInfo;
  };


# ---------------------------------------------------------------------------- #

  Eithers.sourceInfo =
    yt.either yt.SourceInfo.sourceInfo yt.FlocoFetch.Structs.drvSourceInfo;


# ---------------------------------------------------------------------------- #

  inherit (yt.FlocoFetch.Enums)
    fetchType
    sourceType
  ;
  inherit (yt.FlocoFetch.Eithers)
    sourceInfo
  ;
  inherit (yt.FlocoFetch.Structs)
    fetched
  ;


# ---------------------------------------------------------------------------- #

}  # End FlocoFetch Types

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
