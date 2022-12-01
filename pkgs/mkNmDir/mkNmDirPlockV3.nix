#
# mkNmDirPlockV3 { lockDir | plock | metaSet | flocoPackages }
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
, mkNmDirCopyCmd
, mkNmDirLinkCmd

, npmSys
, system

, pure
, ifd
, allowedPaths
, typecheck

, mkSrcEnt'
, mkSrcEnt ? mkSrcEnt' { inherit pure ifd allowedPaths typecheck; }

, lockDir ? throw "You must provide an arg for me to find your package lock"
, plock   ? lib.importJSON' ( lockDir + "/package-lock.json" )
# This is the preferred argument
, metaSet ? lib.metaSetFromPlockV3 {
    inherit plock lockDir pure ifd allowedPaths typecheck;
  }
# Used to override paths used as "prepared"
# If this isn't provided we will create a source tree.
, flocoPackages ? lib.makeExtensible ( _:
    builtins.mapAttrs ( _: mkSrcEnt ) metaSet.__entries
  )
, coreutils
, lndir ? xorg.lndir
, xorg
} @ args: let
  # The `pkgEnt' for the lock we've parsed.
  rootEnt  = metaSet.__meta.rootKey;
  fenv = { inherit pure ifd allowedPaths typecheck; };
  mkNm = { copy ? false, dev ? true, ... } @ nmArgs: let
    # Get our ideal tree, filtering out packages that are incompatible with
    # out system.
    keyTree = lib.idealTreePlockV3 { inherit metaSet npmSys dev; };
    # Using the filtered tree, pull contents from our package set.
    pkgTree =
      builtins.mapAttrs ( path: lib.getFlocoPkg' fenv flocoPackages ) keyTree;
    nmDirCmd = ( if copy then mkNmDirCopyCmd else mkNmDirLinkCmd ) ( {
      inherit
        coreutils lndir flocoPackages ifd pure allowedPaths typecheck
      ;
      tree          = pkgTree;
      ignoreSubBins = false;
      assumeHasBin  = false;
      handleBindir  = false;
      preNmDir      = "";
      postNmDir     = "";
    } // ( removeAttrs nmArgs ["dev"] ) );
  in nmDirCmd // {
    passthru = ( nmDirCmd.passthru or {} ) // {
      inherit metaSet copy dev;
      inherit pkgTree fenv;
    };
  };

  funk = {
    __functionArgs =
      ( lib.functionArgs mkNmDirCmdWith ) // { dev = true; copy = true; };
    __toString = self: self.nmDirCmd.cmd + "\ninstallNodeModules;\n";
    __innerFunction = mkNm;
    # Build a new NM dir with custom args.
    __functor = self: args: self // { nmDirCmd = self.__innerFunction args; };
    nmDirCmd = funk.__innerFunction {};
    # Cache of most common types.
    passthru = {
      devLink  = funk.__innerFunction { copy = false; dev = true; };
      devCopy  = funk.__innerFunction { copy = true;  dev = true; };
      prodLink = funk.__innerFunction { copy = false; dev = false; };
      prodCopy = funk.__innerFunction { copy = true;  dev = false; };
    };
  };

in funk
