# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # TODO: store as scoped/versioned hierarchy
  getFlocoPkg' = { ... } @ fenv: flocoPackages: keylike:
    flocoPackages.${keylike} or null;


# ---------------------------------------------------------------------------- #

  # TODO: the args on this NEED to be typed because the field names are
  # not very descriptive.
  # The user is will definitely set `version' when they mean `semver' for
  # example, and while we could "do what they mean", we have to parse regex
  # to discern between semver and versions - and we are NOT going to support
  # that given the throughput we need from this routine.
  satisfyFlocoPkg' = { ... } @ fenv: flocoPackages: {
    ident   ? null
  , version ? null
  , key     ? null
  , semver  ? null
  , ltype   ? null
  , filter  ? null
  } @ constraints:
    throw "TODO";


# ---------------------------------------------------------------------------- #

  getMetaEntFromFlocoPkg' = { ifd, pure, typecheck, allowedPaths } @ fenv: let
    inner = fpkg: let
      pt = fpkg.passthru.metaEnt;
    in if yt.FlocoMeta.meta_ent_shallow.check pt then pt else
       lib.libmeta.metaEntFromSerial' fenv pt;
  in inner;


# ---------------------------------------------------------------------------- #

  # TODO: Convert any keylike to string
  showKey = lib.generators.toPretty { allowPrettyValues = true; };


# ---------------------------------------------------------------------------- #

  getFlocoPkgModule' = { ... } @ fenv: flocoPackages: keylike: let
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
      else getFlocoPkg' fenv flocoPackages coercedKey;
  in if fpkg == null then throw "No such package '${showKey keylike}'." else
     fpkg.module or fpkg.outPath or fpkg.prepared or fpkg.installed or
     fpkg.built or fpkg.source or
     ( throw "No module outputs available for package '${showKey keylike}.'" );


# ---------------------------------------------------------------------------- #

  # TODO: store as scoped/versioned hierarchy.
  # TODO: Do not allow `flocoPackages' to be accessed directly by `override'.
  # Instead feed it matching deps from a list of `keylike' attrs ( `depInfo' ).
  registerFlocoPkg' = { ... } @ fenv: flocoPackages: {
    ident, version, key, passthru, outPath, ...
  } @ fpkg: flocoPackages.extend ( final: prev: {
    ${key} =
      if ! ( fpkg ? override.__functionArgs.flocoPackages ) then fpkg else
      fpkg.override { flocoPackages = final; };
  } );


# ---------------------------------------------------------------------------- #

  # Will not override existing definitions.
  # TODO: fill missing fields such as `global' or `test'.
  addFlocoPkg' = { ... } @ fenv: flocoPackages: {
    ident, version, key, passthru, outPath, ...
  } @ fpkg:
    if ( getFlocoPkg' fenv flocoPackages key ) != null then flocoPackages else
    registerFlocoPkg' fenv flocoPackages fpkg;


# ---------------------------------------------------------------------------- #

  # Takes Nixpkgs package set as an argument, returns a `flocoPackages' set.
  # If `flocoPackages' is undefined, define one.
  # If `flocoPackages' is defined but is not an extensible set,
  # make it extensible
  # If `flocoPackages' is defined and is extensible, return it.
  initFlocoPkgs' = { ifd, pure, allowedPaths, typecheck } @ fenv: let
    inner = prev:
      if prev ? flocoPackages.extend then prev.flocoPackages else
      if prev ? flocoPackages
      then lib.makeExtensible ( final: prev.flocoPackages )
      else lib.makeExtensible ( final: {} );
  in if ! typecheck then inner else
     yt.defun [yt.Attrsets.pkgset yt.Typeclasses.extensible] inner;


# ---------------------------------------------------------------------------- #

  addFlocoPkgs' = { ifd, pure, allowedPaths, typecheck } @ fenv: let
    inner = prev: pkgs: let
      fp = initFlocoPkgs' fenv prev;
      pkgsE =
        if ! ( lib.isFunction pkgs ) then ( _: _: pkgs ) else
        if ! ( lib.isFunction ( pkgs {} ) ) then ( _: pkgs ) else pkgs;
    in fp.extend pkgsE;
  in if ! typecheck then inner else
     yt.defun [yt.Attrsets.pkgset yt.Attrsets.pkgset] inner;


# ---------------------------------------------------------------------------- #

in {

  inherit
    showKey
    getFlocoPkg'
    getMetaEntFromFlocoPkg'
    getFlocoPkgModule'
    initFlocoPkgs'
    registerFlocoPkg'
    addFlocoPkg'
    addFlocoPkgs'
  ;
  # Legacy routine
  addFlocoPackages = addFlocoPkgs' {
    ifd          = false;
    pure         = true;
    allowedPaths = [];
    typecheck    = false;
  };

  # TODO: fenv/typed forms need to be implemented in most cases
  __withFlocoEnv = { ifd, pure, typecheck, allowedPaths } @ fenv: let
    app = builtins.mapAttrs ( _: f: lib.apply f fenv ) {
      getFlocoPkg            = lib.libfloco.getFlocoPkg';
      getMetaEntFromFlocoPkg = lib.libfloco.getMetaEntFromFlocoPkg';
      getFlocoPkgModule      = lib.libfloco.getFlocoPkgModule';
      initFlocoPkgs          = lib.libfloco.initFlocoPkgs';
      registerFlocoPkg       = lib.libfloco.registerFlocoPkg';
      addFlocoPkg            = lib.libfloco.addFlocoPkg';
      addFlocoPkgs           = lib.libfloco.addFlocoPkgs';
    };
    _with = builtins.mapAttrs ( _: lib.callWith fenv ) {
      getFlocoPkg'            = lib.libfloco.getFlocoPkg';
      getMetaEntFromFlocoPkg' = lib.libfloco.getMetaEntFromFlocoPkg';
      getFlocoPkgModule'      = lib.libfloco.getFlocoPkgModule';
      initFlocoPkgs'          = lib.libfloco.initFlocoPkgs';
      registerFlocoPkg'       = lib.libfloco.registerFlocoPkg';
      addFlocoPkg'            = lib.libfloco.addFlocoPkg';
      addFlocoPkgs'           = lib.libfloco.addFlocoPkgs';
    };
  in app // _with;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
