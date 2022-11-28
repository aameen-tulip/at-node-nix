{ lib

, evalScripts
, buildGyp

, mkNmDir

, flocoUnpack
, flocoFetch

, linkFarm
, stdenv
, xcbuild
, nodejs
, jq
} @ globalArgs: let

# ---------------------------------------------------------------------------- #

  buildPkgEnt = {
    src      ? outPath
  , name     ? passthru.names.built
  , ident    ? metaEnt.ident
  , version  ? metaEnt.version
  , outPath  ? source
  , source   ? throw "You gotta give me something to work with here"
  , metaEnt  ? passthru.metaEnt
  , passthru
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
                 ( lib.optional ( metaEnt.fetchInfo.type == "path" ) "prepare" )
  , evalScripts
  , jq
  , nodejs
  , stdenv
  , ...
  } @ args: let
    args' = {
      inherit name version src runScripts passthru;
    } // ( removeAttrs args [
      "evalScripts"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "source"
      "tarball"
      "installed"
      "prepared"
      "outPath"
      "bin"
      "global"
      "module"
      "key"
    ] );
  in evalScripts args';


# ---------------------------------------------------------------------------- #

  installPkgEnt = {
    src      ? outPath
  , name     ? passthru.names.installed
  , ident    ? metaEnt.ident
  , version  ? metaEnt.version
  , outPath  ? built
  , built    ? source
  , source   ? throw "You gotta give me something to work with here"
  , metaEnt  ? passthru.metaEnt
  , passthru
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
  , buildGyp
  , evalScripts
  , python         ? nodejs.python
  , node-gyp       ? nodejs.pkgs.node-gyp
  , xcbuild
  , jq
  , nodejs
  , stdenv
  , ...
  } @ args: let
    argsG = {
      inherit name version src python node-gyp runScripts passthru;
    } // ( removeAttrs args [
      "evalScripts"
      "buildGyp"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "tarball"
      "source"
      "built"
      "installed"
      "prepared"
      "outPath"
      "bin"
      "global"
      "module"
      "key"
    ] );
    argsE = removeAttrs argsG ["python" "node-gyp" "xcbuild"];
  in if metaEnt ? gypfile then buildGyp argsG else evalScripts argsE;


# ---------------------------------------------------------------------------- #

  testPkgEnt = {
    src        ? outPath
  , name       ? passthru.names.test or ( passthru.names.genName "test" )
  , ident      ? metaEnt.ident
  , version    ? metaEnt.version
  , outPath    ? prepared
  , prepared   ? installed
  , installed  ? built
  , built      ? source
  , source     ? throw "You gotta give me something to work with here"
  , metaEnt    ? passthru.metaEnt
  , passthru
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
      inherit name version src runScripts passthru;
    } // ( removeAttrs args [
      "evalScripts"
      # Drop `pkgEnt' fields, but allow other args to be passed through to
      # `evalScripts' ( which accepts a superset of `stdenv.mkDerivation' args )
      "outPath"
      "source"
      "tarball"
      "installed"
      "prepared"
      "bin"
      "global"
      "module"
      "key"
    ] );
  in evalScripts args';


# ---------------------------------------------------------------------------- #

  outputs = {
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
