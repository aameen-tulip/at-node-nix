# ============================================================================ #
#
# I strongly recommend reading
# [[file:../doc/processes-and-metadata.org][Processes and Metadata]]
# for a primer on "which processes actually use which pieces of metadata".
#
# Understanding when it is worthwhile to put in extra effort to infer a bit of
# info before generating derivations, and when it's mellow to defer to ad-hoc
# handling inside of a derivation is useful context for leveraging these
# routines in your build pipeline; and even moreso when augmenting these
# routines to satisfy the unique needs of your workflow.
#
# The metadata routines defined here should be viewed as your "out of the box"
# standard metadata scrapers - they will make quick work of most projects,
# particularly published tarballs; but you are sincerely encouraged to
# add extra fields to suite your own purposes.
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib) genMetaEntRules;
  inherit (lib.libmeta) metaWasPlock;

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  getKey     = { key, ... }: yt.FlocoMeta._meta_ent_info_fields.key key;
  getIdent   = { ident, ... }: yt.FlocoMeta._meta_ent_info_fields.ident ident;
  getVersion = { version, ... }:
    yt.FlocoMeta._meta_ent_info_fields.version version;

  getEntFromtype = { entFromtype, ... }:
    yt.FlocoMeta._meta_ent_info_fields.entFromtype entFromtype;

  getLtype = { ltype, ... }: yt.FlocoMeta._meta_ent_info_fields.ltype ltype;

  # original metadata sources such as `package.json' are stashed as members
  # of `metaFiles' by default.
  # We use this accessor to refer to them so that users can override this
  # function with custom implementations that fetch these files.
  # TODO: deprecate `entries' field.
  getMetaFiles = {
    metaFiles ? {}
  , ...
  } @ args: metaFiles;

  # Abstraction to refer to `package.json' scripts fields.
  getScripts = {
    metaFiles ? {}
  , ...
  } @ args: let
  in if ! ( metaFiles ? pjs ) then null else
     metaFiles.pjs.scripts or {};

  getGypfile = {
    metaFiles ? {}
  , fsInfo    ? null
  , ...
  } @ ent:
    metaFiles.pjs.gypfile or
    ( if fsInfo == null then null else fsInfo.gypfile );


# ---------------------------------------------------------------------------- #

  # NOTE: the main difference here in terms of detection is that `resolved' for
  # dir/link entries will be an absolute path.
  # Aside from that we just have extra fields ( `NpmLock.Structs.pkg_*' types
  # ignore extra fields so this is fine ).
  identifyMetaEntFetcherFamily = {
    fetchInfo ? null
  , ...
  } @ metaEnt: let
    plent = ( getMetaFiles metaEnt ).plock or null;
  in if fetchInfo != null
     then lib.libfetch.identifyFetchInfoFetcherFamily fetchInfo else
     if plent != null then lib.libplock.identifyPlentFetcherFamily plent else
     throw "identifyMetaEntFetcherFamily: Cannot discern 'fetcherFamily'";


# ---------------------------------------------------------------------------- #

  # Identify Lifecycle "For Any"
  identifyLifecycle = x: let
    fromFi    = throw "identifyLifecycleType: TODO from fetchInfo";
    plent'    = ( getMetaFiles x ).plock or x;
    fromPlent = lib.libplock.identifyPlentLifecycleV3 plent';
  in if builtins.isString x then x else
     if yt.NpmLock.package.check plent' then fromPlent else
     if yt.FlocoFetch.fetched.check x then x.ltype else
     if yt.FlocoFetch.fetch_info_floco.check x then fromFi else
     throw ( "(identifyLifecycle): cannot infer lifecycle type from '"
             "${lib.generators.toPretty { allowPrettyValues = true; } x}'" );


# ---------------------------------------------------------------------------- #

  # `null' means we aren't sure.
  # Input will be normalized to pairs.
  # If `metaEnt' has `directories.bin' we may use IFD in helper routines.
  # TODO: typecheck
  metaEntBinPairs' = { pure, ifd, allowedPaths, typecheck } @ fenv: ent: let
    getBinPairs = lib.libpkginfo.pjsBinPairs' fenv;
    emptyIsNone = ( lib.libmeta.metaWasPlock ent ) ||
                  ( builtins.elem ent.entFromtype ["package.json" "raw"] );
    keep = {
      ident           = true;
      bin             = true;
      directories.bin = true;
      fetchInfo       = true;
    };
    comm  = builtins.intersectAttrs keep ( ent.__entries or ent );
    asPjs = lib.libpkginfo.pjsBinPairs' fenv comm;
    empty = ! ( ( comm ? bin ) || ( comm ? directories.bin ) );
    src'  = if ( ( ent.fetchInfo.type or "file" ) == "file" ) ||
               ( ! ( ent ? sourceInfo.outPath ) )
            then null
            else { src = ent.sourceInfo.outPath; };
  in if emptyIsNone && empty then {} else
     if comm ? bin then getBinPairs comm else
     if ( comm ? directories.bin ) && ( src' != null ) then getBinPairs src'
                                                       else null;


# ---------------------------------------------------------------------------- #

  _fenvFns = {
    inherit
      metaEntBinPairs'
    ;
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    getKey
    getIdent
    getVersion
    getEntFromtype
    getLtype
    getMetaFiles
    getScripts
    getGypfile

    metaEntBinPairs'
    identifyMetaEntFetcherFamily
    identifyLifecycle
  ;

  __withFenv = fenv: let
    cw  = builtins.mapAttrs ( _: lib.callWith fenv ) _fenvFns;
    app = let
      proc = acc: name: acc // {
        ${lib.yank "(.*)'" name} = lib.apply _fenvFns.${name} fenv;
      };
    in builtins.foldl' proc {} ( builtins.attrNames _fenvFns );
  in cw // app;

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
