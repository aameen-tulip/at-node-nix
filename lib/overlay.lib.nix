# ============================================================================ #
#
# Overlays `lib' adding new sublibs.
#
# ---------------------------------------------------------------------------- #

final: prev: let

# ---------------------------------------------------------------------------- #

  callLibWith = { lib ? final, ... } @ auto: x: let
    f = if prev.isFunction x then x else import x;
    args = builtins.intersectAttrs ( builtins.functionArgs f )
                                   ( { inherit lib; } // auto );
  in f args;
  callLib = callLibWith {};
  callLibsWith = auto:
    builtins.foldl' ( acc: x: acc // ( callLibWith auto x ) ) {};
  callLibs = callLibsWith {};


# ---------------------------------------------------------------------------- #

in {

  # FIXME: this is evil and it really contradicts the idea of "pure" libs.
  # You need to make the effected routines explicitly accept relevant args
  # and handle any config options like this at the call site.
  # As convenient as this has been while developing libs, it is difficult to
  # use from the context of a Nixpkgs overlay.
  flocoConfig = (
    callLib ./config.nix
  ).mkFlocoConfig ( prev.flocoConfig or {} );


# ---------------------------------------------------------------------------- #

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
  libmeta    = callLibs [./meta.nix ./meta-ent.nix];
  libdep     = callLib  ./depinfo.nix;
  libsat     = callLib  ./sat.nix;
  libevent   = callLib  ./events.nix;
  # `laika' provides a base.
  libfetch = prev.libfetch // ( callLib  ./fetch.nix );
  # `ak-nix' provides a base.
  libfilt = prev.libfilt // ( callLib ./filt.nix );
  # `ak-nix', `rime', and `laika' have constructed the existing set.
  ytypes = prev.ytypes.extend ( import ../types/overlay.yt.nix );

  # Probably going to change this name.
  libfloco = callLib ./floco-flake.nix;

  inherit (final.libpkginfo)
    Scope
    parseNodeNames
  ;


  inherit (final.libfetch)
    flocoPathFetcher
    flocoGitFetcher
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
    discrPlentFetcherFamily
    identifyPlentFetcherFamily
    supportsPlV1
    supportsPlV3
    resolveDepForPlockV1
    resolveDepForPlockV3
    pinVersionsFromPlockV1
    pinVersionsFromPlockV3
    lookupRelPathIdentV3
    getIdentPlV3
    getKeyPlV3

    metaEntFromPlockV3
    metaSetFromPlockV3
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

    metaEntFromSerial
    metaSetFromSerial
  ;

  inherit (final.libtree)
    idealTreePlockV3  # NOTE: Only for "root" package
  ;

  inherit (final.libcfg)
    getDefaultRegistry
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

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
