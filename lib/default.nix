# ============================================================================ #

# Must be `lib' from `ak-nix'.
{ lib, flocoConfig ? {}, ... } @ globalAttrs: let

# ---------------------------------------------------------------------------- #

  lib' = lib.extend ( final: prev: let

    callLibWith = { lib ? final, ... } @ auto: x: let
      f = if prev.isFunction x then x else import x;
      args = builtins.intersectAttrs ( builtins.functionArgs f )
                                      ( { inherit lib; } // auto );
    in f args;
    callLib = callLibWith {};
    callLibsWith = auto: lst:
      builtins.foldl' ( acc: x: acc // ( callLibWith auto x ) ) {} lst;
    callLibs = callLibsWith {};


# ---------------------------------------------------------------------------- #
  in {

    flocoConfig = (
      callLib ./config.nix
    ).mkFlocoConfig ( globalAttrs.flocoConfig or {} );
    # Call it recursively this time ( not that it really matters )
    libcfg = callLib ./config.nix;

    # `ak-nix.lib' has a `libattrs' and `libstr' as well, so merge.
    libparse   = callLib  ./parse.nix;
    librange   = callLib  ./ranges.nix;
    libpkginfo = callLib  ./pkginfo.nix;
    libattrs   = prev.libattrs // ( callLib  ./attrsets.nix );
    libplock   = callLib  ./pkg-lock.nix;
    libreg     = callLib  ./registry.nix;
    libtree    = callLib  ./tree.nix;
    libsys     = callLib  ./system.nix;
    libfetch   = callLib  ./fetch.nix;
    libmeta    = callLibs [./meta.nix ./meta-ent.nix];
    libdep     = callLib  ./depinfo.nix;
    ytypes     = builtins.foldl' ( a: b: a // b ) ( prev.ytypes or {} ) [
      ( callLib ../types/npm-lock.nix )
      { Packument = callLib ../types/packument.nix; }
      { PkgInfo   = callLib ../types/pkginfo.nix; }
    ];
    # `ak-nix' provides a base.
    libfilt = prev.libfilt // ( callLib ./filt.nix );

    inherit (final.libfetch)
      fetchurlDrvW fetchGitW fetchTreeW pathW
      mkFlocoFetcher
    ;

    inherit (final.libparse)
      parseIdent
      parseDescriptor
      parseLocator
    ;

    inherit (final.libattrs)
      pkgsAsAttrsets
      addFlocoPackages
    ;

    inherit (final.libplock)
      supportsPlV1
      supportsPlV3
      resolveDepForPlockV1
      resolveDepForPlockV3
      pinVersionsFromPlockV1
      pinVersionsFromPlockV3
      lookupRelPathIdentV3
      getIdentPlV3
      getKeyPlV3
    ;

    inherit (final.libreg)
      registryForScope
      importFetchPackument
      packumenter
      packumentClosure
      flakeRegistryFromNpm
    ;

    inherit (final.libmeta)
      serialAsIs
      serialDefault
      serialIgnore
      serialDrop

      extInfoExtras
      mkExtInfo'
      mkExtInfo
      metaEntryFromtypes
      metaWasPlock
      metaWasYlock

      mkMetaEnt'
      mkMetaEnt
      mkMetaSet

      genMetaEntAdd
      genMetaEntUp
      genMetaEntExtend
      genMetaEntRules

      metaEntFromPlockV3
      metaSetFromPlockV3

      metaEntFromSerial
      metaSetFromSerial
    ;

    inherit (final.libtree)
      idealTreePlockV3  # NOTE: Only for "root" package
    ;

    inherit (final.libcfg)
      mkFlocoConfig
    ;

    inherit (final.libsys)
      getNpmCpuForSystem
      getNpmOSForSystem
      getNpmSys'
      getNpmSys
      pkgSysCond
    ;

    inherit (final.libdep)
      depInfoEntFromPlockV3
      depInfoTreeFromPlockV3
      depInfoSetFromPlockV3
    ;

  } );

in lib'
