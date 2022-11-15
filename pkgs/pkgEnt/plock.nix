{ lib

, evalScripts
, buildGyp
, genericInstall

, mkNmDir

, flocoConfig
, flocoUnpack
, flocoFetch

, genSetBinPermissionsHook ? import ./genSetBinPermsCmd.nix {
  inherit patch-shebangs lib;
}
, patch-shebangs
, linkFarm
, stdenv
, xcbuild
, nodejs
, jq
} @ globalArgs: let

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
#   fetchInfo = {
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
  , fetchInfo  # { type, hash, sha512|sha1, url|path|git-shit }
  , depInfo      ? {}  # Not referenced
  , flocoFetch
  , flocoUnpack
  , names        ? lib.libmeta.metaEntNames { inherit ident version; }
  , ...
  } @ metaEnt:
    assert metaEnt ? _type -> metaEnt._type == "metaEnt"; let
    common = {
      inherit key ident version;
      source = flocoFetch fetchInfo;
      meta   = metaEnt.__entries or metaEnt;
    };
    # FIXME: use `names.tarball' if you can.
    forTbs = let
      tbUrl   = flocoFetch ( fetchInfo // { type = "file"; } );
      fetched = flocoFetch fetchInfo;
      # FIXME: this is hideous.
      # Rewrite based on `pacote' fetcher.
      needsUnpack =
        ( ( fetched.fetchInfo.type or fetchInfo.type or null ) == "file" ) ||
        ( ( fetchInfo ? needsUnpack ) && ( fetchInfo.needsUnpack == false ) );
      unpacked = if ! needsUnpack then fetched else
                 flocoUnpack { name = names.src; tarball = fetched; };
    in lib.optionalAttrs ( builtins.elem fetchInfo.type ["tarball" "file"] ) {
      # This may or may not become the source.
      tarball = if needsUnpack then fetched  else tbUrl;
      source  = unpacked;
    };
  in common // forTbs;


# ---------------------------------------------------------------------------- #

  buildPkgEnt = {
    src     ? outPath
  , name    ? meta.names.built
  , ident   ? meta.ident
  , version ? meta.version
  , outPath ? source
  , source  ? throw "You gotta give me something to work with here"
  , meta
  # Hook to install `node_modules/'. Ideally Produced by `mkNmDir*'.
  # This can be an arbitary snippet of shell code.
  # The env var `node_modules_path' should be used to refer to the install dir.
  #   mkNmDirHook = ''
  #     mkdir -p "$node_modules_path/@foo/bar";
  #     cp -Tr -- "${pkgs.bar}" "$node_modules_path/@foo/bar";
  #   ''
  , nmDirCmd
  # If we have a local path we're building, also run the `prepare' script.
  , runScripts ? ["prebuild" "build" "postbuild"] ++
                 ( lib.optional ( meta.fetchInfo.type == "path" ) "prepare" )
  , evalScripts
  , jq
  , nodejs
  , stdenv
  , ...
  } @ args: let
    args' = {
      inherit name version src runScripts;
    } // ( removeAttrs args [
      "evalScripts"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "source"
      "tarball"
      "installed"
      "prepared"
      "outPath"
      "passthru"
      "bin"
      "global"
      "module"
      "key"
    ] );
  in evalScripts args';


# ---------------------------------------------------------------------------- #

  installPkgEnt = {
    src     ? outPath
  , name    ? meta.names.installed
  , ident   ? meta.ident
  , version ? meta.version
  , outPath ? built
  , built   ? source
  , source  ? throw "You gotta give me something to work with here"
  , meta
  # Hook to install `node_modules/'. Ideally Produced by `mkNmDir*'.
  # This can be an arbitary snippet of shell code.
  # The env var `node_modules_path' should be used to refer to the install dir.
  #   nmDirCmd = ''
  #     mkdir -p "$node_modules_path/@foo/bar";
  #     cp -Tr -- "${pkgs.bar}" "$node_modules_path/@foo/bar";
  #   ''
  , nmDirCmd
  # If we have a local path we're building, also run the `prepare' script.
  , runScripts     ? ["preinstall" "install" "postinstall"]
  , genericInstall
  , python         ? nodejs.python
  , node-gyp       ? nodejs.pkgs.node-gyp
  , xcbuild
  , jq
  , nodejs
  , stdenv
  , flocoConfig
  , ...
  } @ args: let
    args' = {
      inherit name version src python node-gyp runScripts;
    } // ( removeAttrs args [
      "genericInstall"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "tarball"
      "source"
      "built"
      "installed"
      "prepared"
      "outPath"
      "passthru"
      "bin"
      "global"
      "module"
      "key"
    ] );
  in genericInstall args';


# ---------------------------------------------------------------------------- #

  testPkgEnt = {
    src        ? outPath
  , name       ? meta.names.test or ( meta.names.genName "test" )
  , ident      ? meta.ident
  , version    ? meta.version
  , outPath    ? prepared
  , prepared   ? installed
  , installed  ? built
  , built      ? source
  , source     ? throw "You gotta give me something to work with here"
  , meta
  , nmDirCmd
  # If we have a local path we're building, also run the `prepare' script.
  , runScripts ? ["test"]
  , evalScripts
  , jq
  , nodejs
  , stdenv
  , ...
  } @ args: let
    args' = {
      inherit name version src runScripts;
    } // ( removeAttrs args [
      "evalScripts"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "outPath"
      "source"
      "tarball"
      "installed"
      "prepared"
      "passthru"
      "bin"
      "global"
      "module"
      "key"
    ] );
  in evalScripts args';


# ---------------------------------------------------------------------------- #

  outputs = {
    mkPkgEntSource = lib.callPackageWith globalArgs mkPkgEntSource;
    buildPkgEnt    = lib.callPackageWith globalArgs buildPkgEnt;
    installPkgEnt  = lib.callPackageWith globalArgs installPkgEnt;
    testPkgEnt     = lib.callPackageWith globalArgs testPkgEnt;
  };

in outputs


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
