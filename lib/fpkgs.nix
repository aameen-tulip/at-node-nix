# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # TODO
  getFlocoPkg = flocoPackages: keylike:
    flocoPackages.${keylike};


# ---------------------------------------------------------------------------- #

  getMetaEntFromFlocoPkg = fpkg: let
    pt = fpkg.passthru.metaEnt;
  in if yt.FlocoMeta.meta_ent_shallow.check pt then pt else
     lib.libmeta.metaEntFromSerial pt;


# ---------------------------------------------------------------------------- #

  # TODO
  showKey = lib.generators.toPretty { allowPrettyValues = true; };


# ---------------------------------------------------------------------------- #

  getFlocoPkgModule = flocoPackages: keylike: let
    coercedKey =
      if builtins.isString keylike then keylike else
      if ( keylike ? key ) then keylike.key else
      if ( ( keylike ? version ) &&
           ( ( keylike.ident or keylike.name or null ) != null ) )
      then ( keylike.ident or keylike.name ) + "/" + keylike.version else
      toString keylike;
    # Check to see if it's already a package.
    fpkg =
      if ( ( keylike._type or null ) == "pkgEnt" ) ||
         ( ( keylike ? outPath ) || ( keylike ? module ) ||
           ( keylike ? prepared ) || ( keylike ? installed ) ||
           ( keylike ? built ) || ( keylike ? source ) ||
           ( keylike ? tarball ) || ( keylike ? fetched ) )
      then keylike
      else getFlocoPkg flocoPackages coercedKey;
  in if fpkg == null then throw "No such package '${showKey keylike}'." else
     fpkg.module or fpkg.outPath or fpkg.prepared or fpkg.installed or
     fpkg.built or fpkg.source or
     ( throw "No module outputs available for package '${showKey keylike}.'" );


# ---------------------------------------------------------------------------- #

in {

  inherit
    showKey
    getFlocoPkg
    getMetaEntFromFlocoPkg
    getFlocoPkgModule
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
