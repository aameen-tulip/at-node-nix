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
    libstr     = prev.libstr // ( callLibs ./strings.nix );
    libattrs   = prev.libattrs // ( callLibs ./attrsets.nix );
    libplock   = callLibs ./pkg-lock.nix;
    libreg     = callLibs ./registry.nix;
    libtree    = callLibs ./tree.nix;
    libsys     = callLibs ./system.nix;
    libfetch   = callLibs ./fetch.nix;
    libmeta    = ( callLibs ./meta.nix ) // ( callLibs ./meta-ent.nix );

    inherit (final.libfetch)
      fetchurlW fetchGitW fetchTreeW pathW
      mkFlocoFetcher
    ;
    fetchurlDrvW = final.libfetch.fetchurlW;

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

    inherit (final.libpkginfo)
      importJSON'
      getDepFields
      getNormalizedDeps
      addNormalizedDepsToMeta
    ;

    inherit (final.libstr)
      lines
      readLines
      test
      charN
      trim
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
    ;

    inherit (final.libreg)
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
      mkMetaEnt'
      mkMetaEnt
      mkMetaSet
      genMetaEntAdd
      genMetaEntUp
      genMetaEntExtend
      genMetaEntRules
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

  } );

in lib'
