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
    ident      ? null
  , version    ? null
  , key        ? null
  , semver     ? null
  , ltype      ? null
  , filter     ? null
  , includePre ? false
  } @ constraints: let
    forIdent = let
      keys     = builtins.attrNames flocoPackages;
      matches  = builtins.filter ( key: ( dirOf key ) == ident ) keys;
      releases = builtins.filter ( lib.test "${ident}/[0-9.]+" ) matches;
      rlen = builtins.length releases;
      # Wether to Include pre-release versions.
      # If explicitly set we always respect the setting, which will throw an
      # error if no releases are avialable; but if no releases are available we
      # will allow pre-releases as a fallback.
      keeps = if includePre then matches else
              if constraints ? includePre then releases else
              if releases == [] then matches else releases;
      msg0 = "getFlocoPkg: No release versions defined for ${ident}";
      msg1 = "getFlocoPkg: No definitions exist for ${ident}";
      msg  = if includePre then msg0 else msg1;
      latest = lib.latestVersion keeps;
    in if keeps == [] then throw msg else flocoPackages.${latest};
  in if constraints ? ident then forIdent else
     throw "TODO: Only ident is supported";


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

  fpkgsEmpty_setIVK = lib.makeExtensibleWithCustomName "__extend" ( self: {
    _type    = "flocoPkgs";
    flocoEnv = {
      flocoPackages = self.pkgs;
    };
    pkgs = {};
    hierarchy     = "set:ivKey";
    schemaVersion = "0.1.0";
  } );

  fpkgsEmpty_simple = lib.makeExtensible ( self: {} );


# ---------------------------------------------------------------------------- #

  # TODO: store as scoped/versioned hierarchy.
  # TODO: Do not allow `flocoPackages' to be accessed directly by `override'.
  # Instead feed it matching deps from a list of `keylike' attrs ( `depInfo' ).
  registerFlocoPkg' = { ... } @ fenv: flocoPackages: {
    ident, version, key, passthru, outPath, ...
  } @ fpkg: let
    keyedRec = final: {
      ${key} = let
        forOverride = fpkg.override { flocoPackages = final; };
        forExt      = fpkg.__extend ( _: pkgPrev: {
          nmDirCmds = pkgPrev.nmDirCmds.override { flocoPackages = final; };
        } );
      in if fpkg ? override.__functionArgs.flocoPackages then forOverride else
        if ( fpkg ? __extend ) && ( fpkg ? nmDirCmds.override ) then forExt else
        fpkg;
    };
    keyedOv = final: prev: keyedRec final;
    update = attrs: lib.fix ( lib.extends ( _: prev: attrs // prev ) keyedRec );
    reg = assert builtins.isAttrs flocoPackages;
      flocoPackages.__register or
      flocoPackages.__extend or
      flocoPackages.extend or
      ( if flocoPackages != {} then update else
        fpkgsEmpty_simple.extend );
    isExt = ( flocoPackages ? extend ) || ( flocoPackages ? __extend ) ||
            ( flocoPackages == {} );
    arg = if isExt then keyedOv else flocoPackages;
  in if ! ( flocoPackages ? __register ) then reg arg else
     flocoPackages.__register flocoPackages fpkg;


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

  # Nipkgs -> [pkgDef] -> ( Nixpkgs // { flocoPackages += pkgDefs; } )
  addFlocoPackages' = { ifd, pure, allowedPaths, typecheck } @ fenv: let
    inner = prev: fpkgs: let
      fp = initFlocoPkgs' fenv prev;
      fpkgsE =
        if ! ( lib.isFunction fpkgs ) then ( _: _: fpkgs ) else
        if ! ( lib.isFunction ( fpkgs {} ) ) then ( _: fpkgs ) else fpkgs;
      # TODO: call `addFlocoPkg''.
    in fp.extend fpkgsE;
  in if ! typecheck then inner else
     yt.defun [yt.Attrsets.pkgset yt.Attrsets.pkgset] inner;


# ---------------------------------------------------------------------------- #

in {

  inherit
    showKey
    getFlocoPkg'
    satisfyFlocoPkg'
    getMetaEntFromFlocoPkg'
    getFlocoPkgModule'
    initFlocoPkgs'
    registerFlocoPkg'
    addFlocoPkg'
    addFlocoPackages'
  ;
  # Legacy routine
  addFlocoPackages = lib.libfloco.addFlocoPackages' {
    ifd          = false;
    pure         = true;
    allowedPaths = [];
    typecheck    = false;
  };

  # TODO: fenv/typed forms need to be implemented in most cases
  __withFlocoEnv = { ifd, pure, typecheck, allowedPaths } @ fenv: let
    app = builtins.mapAttrs ( _: f: lib.apply f fenv ) {
      satisfyFlocoPkg         = lib.libfloco.satisfyFlocoPkg';
      getFlocoPkg            = lib.libfloco.getFlocoPkg';
      getMetaEntFromFlocoPkg = lib.libfloco.getMetaEntFromFlocoPkg';
      getFlocoPkgModule      = lib.libfloco.getFlocoPkgModule';
      initFlocoPkgs          = lib.libfloco.initFlocoPkgs';
      registerFlocoPkg       = lib.libfloco.registerFlocoPkg';
      addFlocoPkg            = lib.libfloco.addFlocoPkg';
      addFlocoPackages       = lib.libfloco.addFlocoPackages';
    };
    _with = builtins.mapAttrs ( _: lib.callWith fenv ) {
      satisfyFlocoPkg'        = lib.libfloco.satisfyFlocoPkg';
      getFlocoPkg'            = lib.libfloco.getFlocoPkg';
      getMetaEntFromFlocoPkg' = lib.libfloco.getMetaEntFromFlocoPkg';
      getFlocoPkgModule'      = lib.libfloco.getFlocoPkgModule';
      initFlocoPkgs'          = lib.libfloco.initFlocoPkgs';
      registerFlocoPkg'       = lib.libfloco.registerFlocoPkg';
      addFlocoPkg'            = lib.libfloco.addFlocoPkg';
      addFlocoPackages'       = lib.libfloco.addFlocoPackages';
    };
  in app // _with;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
