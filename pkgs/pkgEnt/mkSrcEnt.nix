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
, allowedPaths

, flocoUnpack
, flocoFetch   # This does not necessarily need to adhere to `flocoEnv' passed

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

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

  readAllowed = lib.libread.readAllowed {
    inherit pure ifd allowedPaths;
  };

# ---------------------------------------------------------------------------- #
#
#  Full `pkgEnt' record:
#
#  {
#    [outPath]    alias for most processed stage. ( ends with "prepared" )
#    [tarball]
#    source       ( unpacked into "$out" )
#    [built]      ( `build'/`pre[pare|publish]' )
#    [installed]  ( `gyp' or `[pre|post]install' )
#    prepared     ( `[pre|post]prepare', or "most complete" of previous 3 ents )
#    [global]     ( `lib/node_modules[/@SCOPE]/NAME[/VERSION]' [+ `bin/'] )
#    TODO: module       ( `[/@SCOPE]/NAME' [+ `.bin/'] )
#    passthru     ( `metaEnt', `names', and other misc info )
#    key          ( `[@SCOPE/]NAME/VERSION' )
#    meta         ( Nixpkgs compliant `meta' fields - NOT `metaEnt' )
#  }
#
#
# ---------------------------------------------------------------------------- #
#
# We process `fetched' -> `pkgEnt' here, either directly or by running
# `flocoFetch' on inputs.
# These are the fields we have to work with.
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

  # Simplest form of `x' -> `source'.
  # Doesn't attempt to set any metadata or proper derivation names.
  # You basically only want to use this for scraping metadata in `impure' mode.
  coerceUnpacked' = { flocoUnpack, flocoFetch }: {
    fetchInfo ? null
  , fetched   ? flocoFetch x
  , source    ? null
  , ...
  } @ x: assert ( x ? source ) || ( x ? fetchInfo ) ||
                ( x ? fetched ) || ( x ? resolved ); let
    inherit (fetched.passthru) unpacked;
    name        = x.names.src or "source";
    needsUnpack = ( fetched.ffamily == "file" ) && ( ! unpacked );
    doUnpack    = flocoUnpack { inherit name; tarball = fetched; };
  in x.source or ( if needsUnpack then doUnpack.source else fetched );


# ---------------------------------------------------------------------------- #

  # Normalize info to a `pkgEnt:source' record, and perform unpacking if
  # it was not previously performed.
  # Any metadata scraping should be performed before or after this routine
  # based on `ifd' and `pure` settings - we don't fool with that here.
  mkPkgEntSource' = { metaEnt, fetched, flocoUnpack }: let
    me = removeAttrs ( metaEnt.__entries or metaEnt ) ["names"];
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

    sent = core // {
      _type = "pkgEnt:source";
      ltype = metaEnt.ltype or fetched.ltype or
        ( throw "mkPkgEntSource: Missing 'ltype' in 'metaEnt' and 'fetched'." );
      inherit (me) key ident version;
      passthru = {
        metaEnt = me;
        inherit names;
        # TODO: handle other lifecycle events.
        lifecycle = {
          build = let
            fallback = if sent.ltype == "file" then false else null;
          in metaEnt.hasBuild or fallback;
          pack = let
            fallback = if sent.ltype == "file" then false else null;
          in metaEnt.hasPack or fallback;
          install = metaEnt.hasInstallScript or null;
        };
      };
    };
  in sent;


# ---------------------------------------------------------------------------- #

  _pkg_ent_src_fields = {
    _type = yt.enum "_type[pkgEnt:source]" ["pkgEnt:source"];
    ident = yt.PkgInfo.identifier;
    inherit (yt.NpmLifecycle.Enums) ltype;
    inherit (yt.PkgInfo) version key;
    outPath  = yt.FS.store_path;
    tarball  = yt.option yt.FlocoFetch.fetched;
    source   = yt.either yt.FlocoFetch.fetched yt.Prim.drv;
    passthru = yt.attrs yt.any;  # FIXME: check `metaEnt' and `names'
  };

  # TODO: make a real type
  pkg_ent_src = yt.struct "pkgEnt:source" _pkg_ent_src_fields;


# ---------------------------------------------------------------------------- #

  # TODO: less ugly pre/post scraping
  # TODO: check bin perms.
  # `metaEnt' -> `pkgEnt:source'
  mkSrcEntFromMetaEnt' = {
    pure, ifd, typecheck
  , flocoUnpack, flocoFetch
  } @ fenv:
  { fetched ? flocoFetch metaEnt, ... } @ metaEnt: let
    fetched' = if typecheck then yt.FlocoFetch.fetched fetched else fetched;
    scrape = dir: let
      pjs   = lib.importJSON ( dir + "/package.json" );
      isDir = builtins.pathExists ( dir + "/." );
    in if ( readAllowed ( dir + "/package.json" ) ) && isDir then {
      metaFiles = { inherit pjs; };
      gypfile   = builtins.pathExists ( dir + "/binding.gyp" );
      scripts   = pjs.scripts or {};
    } else {};

    sent = mkPkgEntSource' {
      fetched = fetched';
      metaEnt = let
        # Only runs if allowed
        merged = metaEnt.__extend ( final: prev:
          lib.recursiveUpdate ( scrape fetched' ) prev
        );
        clean  = removeAttrs merged ["fetched"];
      in if typecheck then yt.FlocoMeta.meta_ent_shallow clean else clean;
      inherit flocoUnpack;
    };

    post = let
      done   = ( scrape fetched' ) != {};
      merged = metaEnt.__extend ( final: prev:
        lib.recursiveUpdate ( scrape sent.source ) prev
      );
      clean = removeAttrs merged ["fetched"];
      lifecycle = {
        build = let
          fallback = if sent.ltype == "file" then false else null;
        in clean.hasBuild or fallback;
        pack = let
          fallback = if sent.ltype == "file" then false else null;
        in clean.hasPack or fallback;
        install = clean.hasInstallScript or null;
      };
    in if ( ! done ) && ( readAllowed sent.source ) then sent // {
      passthru = sent.passthru // { inherit lifecycle; metaEnt = clean; };
    } else sent;
  in if ! typecheck then post else pkg_ent_src post;


# ---------------------------------------------------------------------------- #

  mkSrcEnt' = { pure, ifd, typecheck , flocoUnpack, flocoFetch } @ fenv: x: let
    detectKind = lib.libtypes.discrDefTypes {
      metaEnt = yt.FlocoMeta.meta_ent_shallow;
    } "unknown";
    mkSrcFromTag = lib.matchLam {
      metaEnt   = mkSrcEntFromMetaEnt' fenv;
      unknown = let
        msg = "mkSrcEnt': Unsure of how to make 'pkgEnt:source' from value " +
              "'${lib.generators.toPretty { allowPrettyValue = true; } x}'.";
      in throw msg;
    };
    tagged = detectKind x;
  in mkSrcFromTag tagged;


# ---------------------------------------------------------------------------- #

in {
  coerceUnpacked'     = lib.callWith globalArgs coerceUnpacked';
  coerceUnpacked      = lib.apply coerceUnpacked' globalArgs;
  mkPkgEntSource      = lib.callWith globalArgs mkPkgEntSource';
  mkSrcEntFromMetaEnt = lib.apply mkSrcEntFromMetaEnt' globalArgs;
  mkSrcEnt            = lib.apply mkSrcEnt' globalArgs;
}


# ---------------------------------------------------------------------------- #
#
# Example Info ( `passthru' contains `metaEnt' input pulled from `plock(v3)' )
#
#  {
#    _type   = "pkgEnt:source";
#    key     = "@adobe/css-tools/4.0.1";
#    ident   = "@adobe/css-tools";
#    version = "4.0.1";
#    ltype   = "file";
#    outPath = "/nix/store/dk84mpjq7dzc8xyb4zcy1nf9y712zfbc-css-tools-source-4.0.1";
#
#    source = <derivation /nix/store/mirybp8w080cs30v1vdgcscqbml8c3by-css-tools-source-4.0.1.drv>;
#
#    tarball = {
#      _type = "fetched";
#      fetchInfo = {
#        type = "file";
#        url = "https://registry.npmjs.org/@adobe/css-tools/-/css-tools-4.0.1.tgz";
#      };
#      ffamily = "file";
#      ltype = "file";
#      outPath = "/nix/store/861hmkgln9pxjlr09sy037mgl7pd4qda-source";
#      passthru = {
#        fetcher = <function, args: {allRefs?, narHash?, owner?, path?, ref?, repo?, rev?, shallow?, submodules?, type, url?}>;
#        unpacked = false;
#      };
#      sourceInfo = {
#        narHash = "sha256-SEK/OHJp0lXRP/oQASLGho4a1OsLXdCLusoVFKoV2M4=";
#        outPath = "/nix/store/861hmkgln9pxjlr09sy037mgl7pd4qda-source";
#      };
#    };  # End `tarball'
#
#    passthru = {
#
#      metaEnt = {
#        depInfo = { };
#        entFromtype = "package-lock.json(v3)";
#        # XXX: Note the difference between this and the actual args used as
#        # recorded in `tarball.fetchInfo' record
#        fetchInfo = {
#          executable = false;
#          hash = "sha512-+u76oB43nOHrF4DDWRLWDCtci7f3QJoEBigemIdIeTi1ODqjx6Tad9NCVnPRwewWlKkVab5PlK8DCtPTyX7S8g==";
#          recursive = false;
#          recursiveHash = false;
#          type = "file";
#          unpack = false;
#          url = "https://registry.npmjs.org/@adobe/css-tools/-/css-tools-4.0.1.tgz";
#        };
#        hasBin = false;
#        hasInstallScript = false;
#        ident = "@adobe/css-tools";
#        key = "@adobe/css-tools/4.0.1";
#        ltype = "file";
#        scoped = true;
#        version = "4.0.1";
#      };
#
#      names = {
#        __serial = false;
#        bin = "css-tools-bin-4.0.1";
#        bname = "css-tools";
#        built = "css-tools-built-4.0.1";
#        flake-id-l = "adobe--css-tools--4_0_1";
#        flake-id-s = "adobe--css-tools";
#        flake-ref = {
#          id = "adobe--css-tools";
#          ref = "4.0.1";
#        };
#        genName = <function>;
#        global = "css-tools-4.0.1";
#        installed = "css-tools-inst-4.0.1";
#        localTarball = "adobe-css-tools-4.0.1.tgz";
#        module = "css-tools-module-4.0.1";
#        node2nix = "_at_adobe_slash_css-tools-4.0.1";
#        prepared = "css-tools-prep-4.0.1";
#        registryTarball = "css-tools-4.0.1.tgz";
#        scope = "adobe";
#        scopeDir = "@adobe/";
#        src = "css-tools-source-4.0.1";
#        tarball = "css-tools-4.0.1.tgz";
#      };
#    };  # End `passthru'
#
#  }  # End `pkgEnt:source'
#
#
# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
