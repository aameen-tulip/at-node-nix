# ============================================================================ #

# Must be `lib' from `ak-nix'.
{ lib, config ? {}, ... } @ globalAttrs: let

# ---------------------------------------------------------------------------- #

  lib' = lib.extend ( final: prev: let
    callLibs = file: import file { lib = final; inherit config; };
  in {
    # `ak-nix.lib' has a `libattrs' and `libstr' as well, so merge.
    libparse   = callLibs ./parse.nix;
    librange   = callLibs ./ranges.nix;
    libpkginfo = callLibs ./pkginfo.nix;
    libstr     = prev.libstr // ( callLibs ./strings.nix );
    libattrs   = prev.libattrs // ( callLibs ./attrsets.nix );
    libplock   = callLibs ./pkg-lock.nix;
    libreg     = callLibs ./registry.nix;
    libmeta    = callLibs ./meta.nix;
    libtree    = callLibs ./ideal-tree-plockv2.nix;
    # TODO: handle merge of fetch.nix ( partial ), nm-scope.nix ( maybe ),
    #       and `libmeta-pl2' ( needs small alignment with `meta.nix' ).

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
      getNpmCpuForPlatform
      getNpmCpuForSystem
      getNpmOSForPlatform
      getNpmOSForSystem
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
      partitionResolved
      toposortDeps
      resolvedFetchersFromLock
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
      metaEntryFromTypes
      mkMetaEnt'
      mkMetaEnt
      mkMetaSet
    ;

    inherit (final.libtree)
      idealTreeMetaSetPlockV2  # NOTE: Only for "root" package
    ;

  } );
in lib'
