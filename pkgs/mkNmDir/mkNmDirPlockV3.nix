# mkSourceTree { lockDir || plock, flocoFetch ( set CWD ) }
{ lib
# You default
, mkNmDirCmdWith
, mkPkgEntSource
, npmSys
, system
, flocoConfig
, flocoFetch
, lockDir ? throw "You must provide an arg for me to find your package lock"
, plock   ? lib.importJSON' "${lockDir}/package-lock.json"
# This is the preferred argument
, metaSet ? lib.libmeta.metaSetFromPlockV3 {
    inherit plock flocoConfig lockDir;
  }
# Used to override paths used as "prepared"
# If this isn't provided we will create a source tree.
, pkgSet ? builtins.mapAttrs ( _: mkPkgEntSource ) metaSet.__entries

, coreutils
, lndir ? xorg.lndir
, xorg
} @ args: let
  # The `pkgEnt' for the lock we've parsed.
  rootEnt  = metaSet.__meta.rootKey;
  mkNm = { copy ? false, dev ? true, ... } @ nmArgs: let
    # Get our ideal tree, filtering out packages that are incompatible with
    # out system.
    keyTree = lib.idealTreePlockV3 { inherit metaSet npmSys dev; };
    # Using the filtered tree, pull contents from our package set.
    pkgTree = builtins.mapAttrs ( path: key: pkgSet.${key} ) keyTree;
    nmDirCmd = mkNmDirCmdWith ( {
      inherit copy coreutils lndir;
      tree = pkgTree;
      ignoreSubBins = false;
      assumeHasBin  = false;
      handleBindir  = false;
      preNmDir      = "";
      postNmDir     = "";
    } // ( removeAttrs nmArgs ["dev"] ) );
  in nmDirCmd // {
    meta = nmDirCmd.meta // {
      inherit metaSet copy dev;
    };
    passthru = nmDirCmd.passthru // { inherit pkgTree; };
  };
  defaultNm = mkNm {};
in {
  nmDirCmd   = defaultNm;
  __toString = self: self.nmDirCmd.cmd;
  # Cache of most common types.
  nmDirCmds = {
    devLink  = defaultNm;
    devCopy  = mkNm { copy = true; };
    prodLink = mkNm { dev = false; };
    prodCopy = mkNm { dev = false; copy = true; };
  };

  # Build a new NM dir with custom args.
  __functor = self: args: self // { nmDirCmd = mkNm args; };
  __functionArgs = let
    base = lib.functionArgs mkNmDirCmdWith;
    clean = removeAttrs base ["override" "overrideDerivation"];
  in clean // { dev = true; };
}
