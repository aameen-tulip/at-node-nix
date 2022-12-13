# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

# ---------------------------------------------------------------------------- #

  yt = ytypes // ytypes.Core // ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # TODO: reconstruct to avoid ugly names in error messages.
  # Currently the look like "flake:ref[TYPE][fetchInfo]" which is weird.
  flakeRefTypeToFetchInfoType = let
    cond = x:
      ! ( ( x ? follows ) || ( x ? flake ) || ( x ? id ) || ( x ? dir ) );
  in tn: yt.restrict "fetchInfo" cond yt.FlakeRef.Structs."flake_ref_${tn}";


# ---------------------------------------------------------------------------- #

in {

# ---------------------------------------------------------------------------- #

  Enums.fetch_info_type_floco =
    yt.enum "type[fetchInfo]" ["file" "tarball" "git" "github" "path"];

  Enums.fetcher_family =
    yt.enum "type[fetcher_family]" ["file" "git" "path"];


# ---------------------------------------------------------------------------- #

  # TODO: move to `rime' or `laika'
  Structs.fetch_info_path      = flakeRefTypeToFetchInfoType "path";
  Structs.fetch_info_file      = flakeRefTypeToFetchInfoType "file";
  Structs.fetch_info_tarball   = flakeRefTypeToFetchInfoType "tarball";
  Structs.fetch_info_git       = flakeRefTypeToFetchInfoType "git";
  Structs.fetch_info_github    = flakeRefTypeToFetchInfoType "github";
  Structs.fetch_info_sourcehut = flakeRefTypeToFetchInfoType "sourcehut";
  Structs.fetch_info_mercurial = flakeRefTypeToFetchInfoType "mercurial";
  Structs.fetch_info_indirect  = flakeRefTypeToFetchInfoType "indirect";

  Structs.fetch_info_fetchurl_drv = yt.struct "fetchInfo:fetchurlDrv" {
    url            = yt.Uri.Strings.uri_ref;
    name           = yt.option yt.FS.Strings.store_filename;
    hash           = yt.option yt.Hash.hash;
    md5            = yt.option yt.Hash.md5;
    sha1           = yt.option yt.Hash.sha1;
    sha256         = yt.option yt.Hash.sha256;
    sha512         = yt.option yt.Hash.sha512;
    outputHash     = yt.option yt.Hash.hash;
    outputHashAlgo = yt.option ( yt.enum ["" "sha1" "md5" "sha256" "sha512"] );
    executable     = yt.option yt.bool;
    unpack         = yt.option yt.bool;
    extraAttrs     = yt.option ( yt.attrs yt.any );
    extraDrvAttrs  = yt.option ( yt.attrs yt.any );
  };


# ---------------------------------------------------------------------------- #

  # TODO:
  # Custom forms of `fetchInfo' do not strictly adhere to the `fetchTree'
  # records, for example `fetchurlDrvW', `pathW', and `fetchGitW' - plus users
  # should be able to choose their own backends.
  # So when checkin returned `fetchInfo' in generic routines and records that
  # carry an abstract `fetchInfo' field, we use this type to serve as our
  # stricted minimum.
  #
  # This is a tricky one.
  # It honestly makes more sense for routines to "inherit" typedefs from
  # an instance of `flocoFetch', but that's a whole other can of worms.
  Structs.fetch_info_generic =
    yt.__internal.typedef "fetchInfo[floco]" builtins.isAttrs;


# ---------------------------------------------------------------------------- #

  Eithers.fetch_info_any = yt.eitherN [
    yt.FlocoFetch.Structs.fetch_info_path
    yt.FlocoFetch.Structs.fetch_info_file
    yt.FlocoFetch.Structs.fetch_info_tarball
    yt.FlocoFetch.Structs.fetch_info_git
    yt.FlocoFetch.Structs.fetch_info_github
    yt.FlocoFetch.Structs.fetch_info_sourcehut
    yt.FlocoFetch.Structs.fetch_info_mercurial
    yt.FlocoFetch.Structs.fetch_info_indirect
  ];

  Eithers.fetch_info_floco = yt.eitherN [
    yt.FlocoFetch.Structs.fetch_info_path
    yt.FlocoFetch.Structs.fetch_info_file
    yt.FlocoFetch.Structs.fetch_info_tarball
    yt.FlocoFetch.Structs.fetch_info_git
    yt.FlocoFetch.Structs.fetch_info_github
    yt.FlocoFetch.Structs.fetch_info_generic
  ];


# ---------------------------------------------------------------------------- #

  Structs.drv_source_info = yt.struct "sourceInfo:derivation" {
    outPath = yt.FS.store_path;
    narHash = yt.option yt.Hash.nar_hash;
  };


  Structs.fetched = yt.struct "fetched" {
    _type      = yt.restrict "_type[fetched]" ( s: s == "fetched" ) yt.string;
    ltype      = yt.option yt.Npm.Enums.ltype;
    ffamily    = yt.FlocoFetch.Enums.fetcher_family;
    outPath    = yt.FS.store_path;
    fetchInfo  = yt.FlocoFetch.Eithers.fetch_info_floco;
    sourceInfo = yt.FlocoFetch.Eithers.source_info_floco;
    passthru   = yt.option ( yt.attrs yt.any );
    meta       = yt.option ( yt.attrs yt.any );
  };


# ---------------------------------------------------------------------------- #

  Eithers.source_info_floco =
    yt.either yt.SourceInfo.source_info yt.FlocoFetch.Structs.drv_source_info;


# ---------------------------------------------------------------------------- #

  inherit (yt.FlocoFetch.Enums)
    fetcher_family
    fetch_info_type_floco
  ;
  inherit (yt.FlocoFetch.Eithers)
    source_info_floco
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
