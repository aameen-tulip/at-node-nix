# ============================================================================ #

# Must be `lib' from `ak-nix'.
{ lib, flocoConfig ? {}, ... } @ globalAttrs: let

# ---------------------------------------------------------------------------- #

  lib' = lib.extend ( final: prev: let
    # XXX: I'm not crazy about possibly polluting `lib' with the config.
    callLibs = file: import file { lib = final; };
  in {

    flocoConfig = (
      callLibs ./config.nix
    ).mkFlocoConfig ( globalAttrs.flocoConfig or {} );
    # Call it recursively this time ( not that it really matters )
    libcfg = callLibs ./config.nix;

    # `ak-nix.lib' has a `libattrs' and `libstr' as well, so merge.
    libparse   = callLibs ./parse.nix;
    librange   = callLibs ./ranges.nix;
    libpkginfo = callLibs ./pkginfo.nix;
    libattrs   = prev.libattrs // ( callLibs ./attrsets.nix );
    libplock   = callLibs ./pkg-lock.nix;
    libreg     = callLibs ./registry.nix;
    libtree    = callLibs ./tree.nix;
    libsys     = callLibs ./system.nix;
    libfetch   = callLibs ./fetch.nix;
    libmeta    = ( callLibs ./meta.nix ) // ( callLibs ./meta-ent.nix );
    libdep     = callLibs ./depinfo.nix;
    ytypes     = ( prev.ytypes or {} ) // ( callLibs ../types/npm-lock.nix );

    inherit (final.libfetch)
      fetchurlDrvW fetchGitW fetchTreeW pathW
      mkFlocoFetcher
    ;

    inherit (final.libparse)
      tryParseIdent
      parseIdent
      tryParseDescriptor
      parseDescriptor
      tryParseLocator
      parseLocator
      nameInfo
      isGitRev
    ;

    inherit (final.libattrs)
      pkgsAsAttrsets
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
      getFetchurlTarballArgs
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
