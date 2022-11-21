#
# mkNmDirPlockV3 { lockDir | plock | metaSet | pkgSet }
#
# This is the "magic" `package-lock.json(v2/3)' -> `node_modules/' builder.
# It's built on top of lower level functions that allow for fine grained
# control of how the directory tree is built, what inputs are used, etc;
# but this form is your "grab a `node_modules/' dir off the shelf" routine
# that tries to do the right thing for a `package-lock.json(v2/3)'.
#
# The resulting attrset is a "functor", which just means its an attrset that
# can modify itself.
# So out of the box it can become a string, or if you check in subattrs you'll
# find `myNmd.nmDirCmds.{devLink,devCopy,prodLink,prodCopy}.cmd' attrs that
# lazily generate other styles of copy or tree.
#
# Additionally if you treat it as a function passing args meant for `mkNmDir*'
# routines, it will change the settings for the default builder.
# The default builder is used for the `toString' magic, and is stashed under
# `myNmd.nmDirCmd' for you to reference.
#
# Passing args does NOT modify the 4 "common" builders stashed under `nmDirCmds'
# so you can rely on those being there, and if you want you can add more.
#
# NOTE: see full docs in `./README.org'.
#
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
, metaSet ? lib.metaSetFromPlockV3 {
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
  cmd        = defaultNm.cmd;
  __toString = self: self.nmDirCmd.cmd;
  # Cache of most common types.
  nmDirCmds = {
    devLink  = defaultNm;
    devCopy  = mkNm { copy = true; };
    prodLink = mkNm { dev = false; };
    prodCopy = mkNm { dev = false; copy = true; };
  };

  # Build a new NM dir with custom args.
  __functor = self: args: let
    nmDirCmd = mkNm args;
  in self // { inherit nmDirCmd; inherit (nmDirCmd) cmd; };
  __functionArgs = let
      base = lib.functionArgs mkNmDirCmdWith;
      clean = removeAttrs base ["override" "overrideDerivation"];
    in clean // { dev = true; };
}
