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
  callLibsWith = auto: libs: let
    loc = "(at-node-nix#callLibsWith):";
    getLibName = x:
      if builtins.isFunction x then "<???>" else baseNameOf ( toString x );
    lnames = builtins.concatStringsSep ", " ( map getLibName libs );
    ec = builtins.addErrorContext ( loc + " processing libs '${lnames}'" );
    proc = acc: x: let
      l     = callLibWith auto x;
      lname = getLibName x;
      comm  = builtins.intersectAttrs acc l;
      merge = f: let
        aa  = acc.${f};
        la  = l.${f};
        msg = "${loc} ${lname}: Cannot merge conflicting definitions for " +
              "member '${f}' of types '${builtins.typeOf aa}' and " +
              "'${builtins.typeOf la}'.";
      in if builtins.isAttrs acc.${f}
         then assert builtins.isAttrs l.${f}; acc.${f} // l.${f}
         else throw msg;
      merged = builtins.foldl' ( sa: f: sa // ( merge f ) ) l
                               ( builtins.attrNames comm );
    in acc // merged;
  in ec ( builtins.foldl' proc {} libs );
  callLibs = callLibsWith {};


# ---------------------------------------------------------------------------- #

in {

# ---------------------------------------------------------------------------- #

  libcfg = callLib ./config.nix;

  # `ak-nix.lib' has a `libattrs' and `libstr' as well, so merge.
  libparse   = callLib  ./parse.nix;
  librange   = callLib  ./ranges.nix;
  libpkginfo = callLibs [./pkginfo.nix ./scope.nix];
  libattrs   = prev.libattrs // ( callLib  ./attrsets.nix );
  libplock   = callLib  ./pkg-lock.nix;
  libpjs     = callLib  ./pkg-json.nix;
  libreg     = callLib  ./registry.nix;
  libtree    = callLibs [./tree.nix ./focus-tree.nix];
  libsys     = callLib  ./system.nix;
  libmeta    = callLibs [./meta.nix ./meta-ent.nix ./serial.nix];
  libbininfo = callLib  ./bin-info.nix;
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
  libfloco = callLibs [
    ./floco-flake.nix
    ./fpkgs.nix
    ./pkgref.nix
  ];

  inherit (final.libfloco)
    getFlocoPkg'
    getFlocoPkgModule'
    getMetaEntFromFlocoPkg'
    addFlocoPackages

    # These sort of accomplish the same thing but one is a typeclass
    IVKey        # IVKey.coerce is strictly typed regardless of `fenv'
    coerceIVKey  # Always untyped, throws on failure
  ;

  inherit (final.libpkginfo)
    Scope  # Typeclass
  ;


  inherit (final.libfetch)
    flocoUrlFetcher'
    flocoTarballFetcher'
    flocoFileFetcher'
    flocoPathFetcher'
    flocoGitFetcher'
    mkFlocoFetcher
  ;

  inherit (final.libparse)
    parseIdent
    parseDescriptor
    parseLocator
    parseNodeNames
  ;

  inherit (final.libattrs)
    pkgsAsAttrsets
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
    toSerial
    _mkExtInfo mkExtInfo
    metaWasPlock
    metaWasYlock
    mkMetaEnt' mkMetaEnt
    mkMetaSet
  ;

  inherit (final.libtree)
    idealTreePlockV3  # NOTE: Only for "root" package
  ;

  inherit (final.libcfg)
    getDefaultRegistry
    mkFenvLibSet
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
