{ lib

, buildGyp
, evalScripts
, genericInstall
, runBuild

, mkNmDir

, flocoConfig
, flocoUnpack
, flocoFetch

, linkFarm
, stdenv
, xcbuild
, nodejs
, jq
} @ globalArgs: let

# ---------------------------------------------------------------------------- #
#
#  {
#    [tarball]
#    source       ( unpacked into "$out" )
#    [built]      ( `build'/`pre[pare|publish]' )
#    [installed]  ( `gyp' or `[pre|post]install' )
#    prepared     ( `[pre|post]prepare', or "most complete" of previous 3 ents )
#    [bin]        ( bins symlinked to "$out" from `source'/`built'/`installed' )
#    [global]     ( `lib/node_modules[/@SCOPE]/NAME[/VERSION]' [+ `bin/'] )
#    module       ( `[/@SCOPE]/NAME' [+ `.bin/'] )
#    passthru     ( Holds the fields above + `nodejs', and a few other drvs )
#    key          ( `[@SCOPE/]NAME/VERSION' )
#    meta         ( package info yanked from locks, manifets, etc - no drvs! )
#  }
#
#
# ---------------------------------------------------------------------------- #

# MetaEnt for reference
#
# {
#   key = "@babel/core/7.18.13";
#   ident = "@babel/core";
#   version = "7.18.13";
#   entFromtype = "package-lock.json(v2)";
#   hasBin = false;
#   hasBuild = false;
#   hasInstallScript = false;
#   scoped = true;
#   sourceInfo = {
#     entSubtype = "registry-tarball";
#     hash = "sha512-ZisbOvRRusFktksHSG6pjj1CSvkPkcZq/KHD45LAkVP/oiHJkNBZWfpvlLmX8OtHDG8IuzsFlVRWo08w7Qxn0A==";
#     sha512 = "ZisbOvRRusFktksHSG6pjj1CSvkPkcZq/KHD45LAkVP/oiHJkNBZWfpvlLmX8OtHDG8IuzsFlVRWo08w7Qxn0A==";
#     type = "tarball";
#     url = "https://registry.npmjs.org/@babel/core/-/core-7.18.13.tgz";
#   };
#   depInfo = { ... };
# }
#
# ---------------------------------------------------------------------------- #

  # Just fetch and unpack.
  # No bin permissions are handled, no patching is performed.
  mkPkgEntSource = {
    key
  , ident
  , version
  , entFromtype
  , scoped
  , sourceInfo  # { type, entSubtype, hash, sha512|sha1, url|path|git-shit }
  , depInfo      ? {}  # Not referenced
  , flocoFetch
  , flocoUnpack
  , names
  , ...
  } @ metaEnt: assert metaEnt._type == "metaEnt"; let
    common = {
      inherit key ident version;
      source = flocoFetch sourceInfo;
      meta   = metaEnt.__entries;
    };
    # FIXME: use `names.tarball' if you can.
    forTbs = let
      tbUrl    = flocoFetch ( ( removeAttrs sourceInfo ["entSubtype"] )
                              // { type = "url"; } );
      fetched  = flocoFetch sourceInfo;
      unpacked = assert ( fetched.needsUnpack or false ); flocoUnpack {
        name    = names.src;
        tarball = fetched;
      };
    in lib.optionalAttrs ( sourceInfo.type == "tarball" ) {
      # This may or may not become the source.
      tarball = if ( fetched.needsUnpack or false ) then fetched  else tbUrl;
      source  = if ( fetched.needsUnpack or false ) then unpacked else fetched;
    };
  in common // forTbs;


# ---------------------------------------------------------------------------- #




# ---------------------------------------------------------------------------- #

in {
  mkPkgEntSource = lib.callPackageWith globalArgs mkPkgEntSource;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
