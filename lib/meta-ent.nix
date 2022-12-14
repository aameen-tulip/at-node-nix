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
  getMetaFiles = { metaFiles ? {}, ... }:
    yt.FlocoMeta._meta_ent_info_fields.metaFiles
      ( removeAttrs metaFiles ["__serial"] );

  # Abstraction to refer to `package.json' scripts fields.
  getScripts = {
    metaFiles ? getMetaFiles ent
  , ...
  } @ ent: metaFiles.metaRaw.scripts or (
    if ! ( metaFiles ? pjs ) then null else metaFiles.pjs.scripts or {}
  );

  getGypfile = {
    metaFiles ? getMetaFiles ent
  , fsInfo    ? null
  , ...
  } @ ent:
    metaFiles.metaRaw.gypfile or metaFiles.pjs.gypfile or
    ( if fsInfo == null then null else fsInfo.gypfile );


# ---------------------------------------------------------------------------- #

  metaEntFromRaw' = { typecheck, ... } @ fenv: {
    key     ? metaRaw.ident + "/" + metaRaw.version
  , ident   ? dirOf metaRaw.key
  , version ? baseNameOf metaRaw.key
  , ltype
  , fetchInfo
  # Mandatory fields with fallbacks:
  , entFromtype ? "raw"
  , lifecycle   ? { install = false; build = false; }
  , depInfo     ? {}
  , sysInfo     ? {}
  # Optional Fields:
  , binInfo     ? null
  , treeInfo    ? null
  , fsInfo      ? null
  , sourceInfo  ? null
  } @ metaRaw: let
    # Serialized `binInfo' records may be compressed to `binInfo = false', which
    # we are responsible for expanding here.
    binInfo' = if binInfo == false then { binInfo.binPairs = {}; } else {};
    members = {
      # Mandatory fields
      inherit
        key ident version entFromtype ltype fetchInfo depInfo sysInfo lifecycle
      ;
      metaFiles = { __serial = lib.libmeta.serialIgnore; inherit metaRaw; };
    } // metaRaw // binInfo';
    metaEnt = lib.libmeta.mkMetaEnt members;
  in if typecheck then yt.FlocoMeta.meta_ent_info metaEnt else metaEnt;


# ---------------------------------------------------------------------------- #

  # NOTE: the main difference here in terms of detection is that `resolved' for
  # dir/link entries will be an absolute path.
  # Aside from that we just have extra fields ( `NpmLock.Structs.pkg_*' types
  # ignore extra fields so this is fine ).
  identifyMetaEntFetcherFamily = {
    fetchInfo ? null
  , ...
  } @ metaEnt: let
    plent = ( getMetaFiles metaEnt ).plent or null;
  in if fetchInfo != null
     then lib.libfetch.identifyFetchInfoFetcherFamily fetchInfo else
     if plent != null then lib.libplock.identifyPlentFetcherFamily plent else
     throw "identifyMetaEntFetcherFamily: Cannot discern 'fetcherFamily'";


# ---------------------------------------------------------------------------- #

  # Identify Lifecycle "For Any"
  identifyLifecycle = x: let
    fromFi    = throw "identifyLifecycleType: TODO from fetchInfo";
    plent'    = ( getMetaFiles x ).plent or x;
    fromPlent = lib.libplock.identifyPlentLifecycleV3 plent';
  in if builtins.isString x then x else
     if yt.NpmLock.package.check plent' then fromPlent else
     if yt.FlocoFetch.fetched.check x then x.ltype else
     if yt.FlocoFetch.fetch_info_floco.check x then fromFi else
     throw ( "(identifyLifecycle): cannot infer lifecycle type from '"
             "${lib.generators.toPretty { allowPrettyValues = true; } x}'" );


# ---------------------------------------------------------------------------- #

  genericMetaEnt' = { typecheck, ifd, pure, allowedPaths } @ fenv: members: let
    base = lib.libmeta.mkMetaEnt members;
  in base.__extend ( lib.composeManyExtensions [
    ( lib.libbininfo.binInfoFromMetaFilesOv' {
        inherit typecheck ifd pure allowedPaths;
      } )
    lib.libsys.metaEntSetSysInfoOv
    lib.libevent.metaEntLifecycleOv
  ] );


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
      metaEntFromRaw'
      genericMetaEnt'
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

    genericMetaEnt'
    metaEntBinPairs'
    metaEntFromRaw'
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
