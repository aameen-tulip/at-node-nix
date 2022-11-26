# ============================================================================ #
#
# Convert `fetched' and `metaEnt' -> a `pkgEnt' with `source' and core
# fields set for processing by build recipes and `mkNmDirCmd'.
#
# ---------------------------------------------------------------------------- #

{ lib
, pure
, ifd
, typecheck

#, flocoConfig
, flocoUnpack
, flocoFetch

#, genSetBinPermissionsHook ? import ./genSetBinPermsCmd.nix {
#  inherit patch-shebangs lib;
#}
#, pjsUtil
#, patch-shebangs
#, stdenv
#, xcbuild
#, nodejs
#, jq
} @ globalArgs: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #
#
#  {
#    [outPath]    alias for most processed stage. ( ends with "prepared" )
#    [tarball]
#    source       ( unpacked into "$out" )
#    [built]      ( `build'/`pre[pare|publish]' )
#    [installed]  ( `gyp' or `[pre|post]install' )
#    prepared     ( `[pre|post]prepare', or "most complete" of previous 3 ents )
#    TODO: [bin]        ( bins symlinked to "$out" from `source'/`built'/`installed' )
#    [global]     ( `lib/node_modules[/@SCOPE]/NAME[/VERSION]' [+ `bin/'] )
#    TODO: module       ( `[/@SCOPE]/NAME' [+ `.bin/'] )
#    passthru     ( Holds the fields above + `nodejs', and a few other drvs )
#    key          ( `[@SCOPE/]NAME/VERSION' )
#    meta         ( package info yanked from locks, manifets, etc - no drvs! )
#  }
#
#
# ---------------------------------------------------------------------------- #
#
#  Structs.fetched = yt.struct "fetched" {
#    _type      = yt.restrict "_type[fetched]" ( s: s == "fetched" ) yt.string;
#    ltype      = yt.option yt.NpmLifecycle.Enums.ltype;
#    ffamily    = yt.FlocoFetch.Enums.fetcher_family;
#    outPath    = yt.FS.store_path;
#    fetchInfo  = yt.FlocoFetch.Eithers.fetch_info_floco;
#    sourceInfo = yt.FlocoFetch.Eithers.source_info_floco;
#    passthru   = yt.option ( yt.attrs yt.any );
#    meta       = yt.option ( yt.attrs yt.any );
#  };
#
#
# ---------------------------------------------------------------------------- #

  # Normalize info to a `pkgEnt:source' record, and perform unpacking if
  # it was not previously performed.
  # Any metadata scraping should be performed before or after this routine
  # based on `ifd' and `pure` settings - we don't fool with that here.
  #
  # TODO: indicate if reads require IFD/pure.
  # TODO: if `ffamily' or `unpacked' are unknown, you can discover that info
  # using IFD with the unpack routine used for `pacote' bootstrapping.
  mkPkgEntSource' = { metaEnt, fetched, flocoUnpack }: let
    me = metaEnt.__entries or metaEnt;
    inherit (fetched.passthru) unpacked;
    needsUnpack = ( fetched.ffamily == "file" ) && ( ! unpacked );

    # bname, genName, src, registryTarball, localTarball, tarball, ..
    # `tarball' is an alias of `registryTarball' by default, but may be
    # overidden by the user with a `metaEnt' overlay.
    names = metaEnt.names or ( lib.libmeta.metaEntNames {
      inherit (me) ident version;
    } );

    doUnpack = flocoUnpack {
      name    = names.src;
      tarball = fetched;  # this should have set `outPath'
    };  # => { tarball, source, outPath }

    core = if needsUnpack then doUnpack else {
      source = fetched;
      inherit (fetched) outPath;
    };

  in core // {
    _type = "pkgEnt:source";
    ltype = metaEnt.ltype or fetched.ltype or
      ( throw "mkPkgEntSource: Missing 'ltype' in 'metaEnt' and 'fetched'." );
    inherit (me) key ident version;
    passthru = {
      metaEnt = me;
      inherit names;
    };
  };


# ---------------------------------------------------------------------------- #

  #
  # TODO: scrape PJS after unpack.
  # TODO: typecheck.
  # TODO: check bin perms.
  # FIXME: this interface doesn't actually make any sense for anything other
  # then `metaEnt' input.
  # ( metaEnt | fetched | plent | fetchInfo | sourceInfo ) -> `pkgEnt:source'
  mkSrcEnt' = { pure, ifd, typecheck } @ fenv: x: let
    kind = lib.libtypes.discrDefTypes {
      metaEnt    = yt.FlocoMeta.meta_ent_shallow;
      fetchInfo  = yt.FlocoFetch.Eithers.fetch_info_floco;
      fetched    = yt.FlocoFetch.fetched;
      sourceInfo = yt.FlocoFetch.source_info_floco;
    } "unknown" x;
    toMF = lib.libtag.matchLam {
      metaEnt = {
        metaEnt = x;
        fetched = flocoFetch x;
      };
      # FIXME: You're actually kind of stuck here since you planned to unpack
      # in `mkPkgEntSource'' but don't have the `metaEnt' fields that you need.
      fetchInfo = let
        fetched = flocoFetch { fetchInfo = x; };
      in {
        metaEnt = /* FIXME */ throw "FIXME: you need to get metaEnt info first";
        inherit fetched;
      };
      fetched = {
        metaEnt = /* FIXME */ throw "FIXME: you need to get metaEnt info first";
        fetched = x;
      };
      sourceInfo = {
        metaEnt = /* FIXME */ throw "FIXME: you need to get metaEnt info first";
        fetched = /* FIXME */ throw "FIXME: you can't derive fetched from sourceInfo alone.";
      };
    };
    se = mkPkgEntSource' ( toMF kind );
  in se;


# ---------------------------------------------------------------------------- #

in {
  inherit
    mkPkgEntSource'
    mkSrcEnt'
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
