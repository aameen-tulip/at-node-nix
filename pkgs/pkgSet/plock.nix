{ lib
, lockDir

, mkSrcEnt
, mkNmDirPlockV3

, runCommandNoCC
, buildPkgEnt
, installPkgEnt
, testPkgEnt

, ifd
, pure
, allowedPaths
, typecheck
, basedir ? toString lockDir

}: let

  fenv = { inherit ifd pure allowedPaths typecheck; };

  metaSet = lib.metaSetFromPlockV3 ( fenv // { inherit lockDir basedir; } );

  pkgSet = builtins.mapAttrs ( path: metaEnt: let
    basePkgEnt = mkSrcEnt metaEnt;
    doBins = runCommandNoCC basePkgEnt.meta.names.prepared {
      src = basePkgEnt.source;
      # The version on `node-js' that we can't `patchShebangs' to use.
      buildInputs = [nodejs jq];
    } ''
      cp -r -- "$src" "$out";
      cd "$out";
      mkdir -p .bin;
      jq -r '( .bin // {} )|to_entries[]|"ln -sr -- " + .value + "  ../.bin/" + .key'|sh;
      patchShebangs ../.bin;
    '';

    in if basePkgEnt.meta.hasBuild         then buildPkgEnt   basePkgEnt else
       if basePkgEnt.meta.hasInstallScript then installPkgEnt basePkgEnt else
       if basePkgEnt.meta.hasBin           then doBins                   else
       basePkgEnt
  ) metaSet.__entries;

  nmd = mkNmDirPlockV3 {
    # Packages will be pulled from here when their "key" ( "<IDENT>/<VERSION>" )
    # matches an attribute in the set.
    inherit pkgSet;
    # Default settings. These are wiped out if you pass args again.
    copy = false;  # Symlink
    dev  = true;   # Include dev modules
  };
in {
  inherit metaSet pkgSet;
}
