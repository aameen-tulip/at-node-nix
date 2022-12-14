# ============================================================================ #
#
# Create `metaEnt' from `package.json'.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  pi = yt.PkgInfo;

# ---------------------------------------------------------------------------- #

  # Standard arg processor that accepts `pjs' or `pjsDir' as an arg used to
  # access `package.json' info.
  # The arg `pjsKey' is short for "workspace key", but is currently unused - this
  # arg is a stub for future workspaces support.
  stdPjsArgProc' = { pure, ifd, typecheck, allowedPaths } @ fenv: self: {
    pjs    ? lib.libpkginfo.readJSONFromPath' fenv ( pjsDir + "/package.json" )
  , pjsKey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace members without 'pjsDir'."
  }: let
    loc  = self.__functionMeta.name or "libpjs";
    args = if pjsKey == "" then { inherit pjs pjsKey pjsDir fenv; } else
           throw "(${loc}): Reading workspaces has not been implemented.";
    targs = if self ? __thunk then self.__thunk // args else args;
    fargs = if self ? __functionArgs then lib.canPassStrict self targs else
            targs;
  in fargs;


# ---------------------------------------------------------------------------- #

  # Pull `pjs' info from a `metaEnt' without attempting to read anything from
  # the filesystem or network.
  # This is a simple accessor abstraction, nothing fancy.
  metaEntGetPjsStrict    = metaEnt: metaEnt.metaFiles.pjs or null;
  metaEntGetPjsDirStrict = metaEnt:
    metaEnt.metaFiles.pjsDir or metaEnt.sourceInfo.outPath or null;

  # Will read from filesystem but won't fetch.
  metaEntGetPjs' = { pure, ifd, typecheck, allowedPaths } @ fenv: metaEnt: let
    fromSrc = let
      pjsDir = metaEntGetPjsDirStrict metaEnt;
    in if pjsDir == null then null else ( stdPjsArgProc' fenv {} {
      inherit pjsDir;
    } ).pjs;
    fromMF = metaEntGetPjsStrict metaEnt;
  in if fromMF != null then fromMF else fromSrc;


# ---------------------------------------------------------------------------- #

  # FIXME: referring to `prev.metaFiles' here breaks things.
  # If you modify `pjsDir', you expect `pjs' to update, but doing so reverts
  # `pjsDir' underneat itself becoming `null' again, which unfortunately turns
  # into "/package.json"...
  #
  # This is still fine to use as long as `sourceInfo' has been set.
  metaEntSetPjsDirOv = final: prev:
    if ( prev.metaFiles.pjsDir or null ) != null then prev else {
      metaFiles = ( prev.metaFiles or {} ) // {
        pjsDir = prev.sourceInfo.outPath or null;
      };
    };

  # FIXME: see note above
  # This is still fine to use as long as `metaFiles.pjsDir' has been set.
  metaEntSetPjsOv = final: prev:
    if ( metaEntGetPjsStrict prev ) != null then prev else {
      metaFiles = ( prev.metaFiles or {} ) // {
        pjs = if ( prev.metaFiles.pjsDir or null ) == null then null else
              ( lib.importJSON ( prev.metaFiles.pjsDir + "/package.json" ) );
      };
    };

  metaEntSetScriptsOv = final: prev: {
    scripts = let
      pjs = metaEntGetPjsStrict final;
    in if pjs == null then null else ( pjs.scripts or {} );
  };

  metaEntPjsHasBinOv = final: prev: {
    hasBin = prev.hasBin or ( let
      pjs = metaEntGetPjsStrict final;
    in if pjs == null then null else
       ( pjs.bin or pjs.directories.bin or {} ) != {} );
  };

  metaEntPjsSetDepInfo = final: prev:
    if ( prev.depInfo or {} ) != {} then prev else {
      depInfo = lib.libdep.depInfoFromFields ( metaEntGetPjsStrict prev );
    };


  metaEntPjsBasicsOv = lib.composeManyExtensions [
    metaEntSetPjsDirOv
    metaEntSetPjsOv
    metaEntSetScriptsOv
    metaEntPjsHasBinOv
    metaEntPjsSetDepInfo
  ];


# ---------------------------------------------------------------------------- #

  # Abstracts workspaces

  getFieldPjs' = { pure, ifd, typecheck, allowedPaths } @ fenv: {
    __functionArgs.field   = false;
    __functionArgs.default = true;
    __processArgs = self: x: let
      fromFAttrs = { inherit (x) field; } //
                   ( if ( x ? default ) then { inherit (x) default; } else {} );
      fromTag = let
        vt = lib.libtag.verifyTag x;
      in if ! vt.isTag then throw vt.errmsg else {
        field   = vt.name;
        default = vt.val;
      };
    in if builtins.isString x then  { field = x; default = null; } else
       if ( x ? field ) then fromFAttrs else fromTag;
    __functor = self: x:
      self.__innerFunction ( self.__processArgs self x );
    __innerFunction = { field, default ? null }: {
      __functionArgs.pjs = false;
      __functor = iself: y:
        iself.__innerFunction ( iself.__processArgs iself y );
      __processArgs = stdPjsArgProc' fenv;
      __innerFunction = { pjs }: pjs.${field} or default;
    };
  };

  getFieldsPjs' = { pure, ifd, typecheck, allowedPaths } @ fenv: {
    __functionArgs.fields  = false;
    __processArgs = self: fields:
        if builtins.isAttrs fields then fields else
        builtins.foldl' ( acc: f: acc // { ${f} = false; } ) {} fields;
    __functor = self: x: let
      fields = self.__processArgs self ( x.fields or x );
    in {
      __functionArgs.pjs = false;
      __processArgs   = stdPjsArgProc' fenv;
      __innerFunction = { pjs }: builtins.intersectAttrs fields pjs;
      __functor = iself: y:
        iself.__innerFunction ( iself.__processArgs iself y );
    };
  };


# ---------------------------------------------------------------------------- #

  getIdentPjs'   = fenv: getFieldPjs' fenv { field = "name"; };
  getVersionPjs' = fenv: getFieldPjs' fenv { field = "version"; };
  getScriptsPjs' = fenv: getFieldPjs' fenv { field = "scripts"; default = {}; };

  getHasBinPjs' = fenv: let
    getBinFields = getFieldsPjs' fenv {
      fields = { bin = true; directories = true; };
    };
  in {
    inherit (getBinFields) __functionArgs;
    __innerFunction = fields:
      ( fields.bin or fields.directories.bin or {} ) != {};
    __processArgs = self: getBinFields;
    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };


# ---------------------------------------------------------------------------- #

  # FIXME: `metaEntOverlays'
  metaEntFromPjsNoWs' = { pure, ifd, typecheck, allowedPaths } @ fenv: let
    raenv = removeAttrs fenv ["typecheck"];
  in {
    pjs    ? lib.libpkginfo.readJSONFromPath' fenv ( pjsDir + "/package.json" )
  , pjsKey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace/write fetchInfo without 'pjsDir'."
  , isLocal ? args ? pjsDir
  , ltype   ?
    if ( args ? pjsDir ) && ( ! ( lib.isStorePath pjsDir ) ) then "dir" else
    "file"
  , basedir ? toString pjsDir
  , noFs    ? ! isLocal
  } @ args: let
    gargs = removeAttrs args ["basedir" "ltype" "isLocal" "noFs"];
    abs = if yt.FS.abspath.check pjsDir then toString pjsDir else
          toString ( /. + ( ( basedir + "/" + pjsDir ) ) );
    rel = let
      blen = builtins.stringLength basedir;
      alen = builtins.stringLength abs;
    in if basedir == pjsDir then "" else
       builtins.substring ( blen + 1 ) alen abs;
    forLocal = {
      # NOTE: this won't work for store paths.
      # FIXME: when you serialize this you need to write relative paths.
      # You have that here, but other `fetchInfo' entries don't, and honestly
      # I'm not in love with this handling.
      fetchInfo = {
        __serial = x: ( lib.libmeta.serialDefault x ) // {
          path =
            builtins.trace ( "WARNING: making absolute path '${toString abs}'" +
                             " relative './${rel}'." )
                           ( "./" + rel );
        };
        type      = "path";
        path      = assert pjsKey == "";  pjsDir;
        recursive = true;
      };
    };
    extra = getFieldsPjs' fenv {
      fields = {
        bin         = true;
        directories = true;
        gypfile     = true;  # Rarely declared but it happens.
      };
    } gargs;
    # We recycle `depInfoEntFromPlockV3' since we don't have a generic form.
    # The regular routine is fine for this, we just pass in a phony path.
    # At time of writing the `path' field isn't used anyway.
    deps = let
      plent = getFieldsPjs' fenv {
        fields = {
          dependencies         = true;
          devDependencies      = true;
          optionalDependencies = true;
          peerDependencies     = true;
          peerDependenciesMeta = true;
        };
      } gargs;
    in {
      depInfo   = lib.libdep.depInfoEntFromPlockV3 "" plent;
      depFields = plent;
    };
    # Merged mispelled field because NPM allows either spelling because they
    # couldn't be bothered to write a linter.
    bundled' = let
      fields = getFieldsPjs' fenv {
        fields = { bundledDependencies = true; bundleDependencies = true; };
      } gargs;
    in lib.libdep.getBundledDeps fields;

    ident   = getIdentPjs'   fenv gargs;
    version = getVersionPjs' fenv gargs;

    infoNoFs = bundled' // {
      inherit ident version;
      scripts = getScriptsPjs' fenv gargs;
      entFromtype = "package.json";
      key =
        if ( ident == null ) || ( version == null ) then "workspace/0.0.0" else
        ident + "/" + version;
      hasBin    = getHasBinPjs'  fenv gargs;
      metaFiles = {
        __serial = lib.libmeta.serialIgnore;
        inherit pjs pjsKey;
      } // ( if ! ( args ? pjsDir ) then {} else { inherit pjsDir; } );
      inherit (deps) depInfo;
    } // ( if ( args ? ltype ) || isLocal then { inherit ltype; } else {} )
      // ( if isLocal then forLocal else {} );

    infoFs = let
      hasDef  = lib.libpkginfo.hasInstallFromScripts infoNoFs.scripts;
      # Don't override the field from `pjs'
      gypfile = pjs.gypfile or (
        if lib.libread.readAllowed raenv ( pjsDir + "/binding.gyp" )
        then builtins.pathExists ( pjsDir + "/binding.gyp" )
        else null
      );
    in ( if gypfile == true then {
      scripts = { install = "node-gyp rebuild"; } // infoNoFs.scripts;
    } else {} ) // { inherit gypfile; };

    meta = lib.libmeta.mkMetaEnt infoNoFs;
    ex = let
      ov = lib.composeManyExtensions [
        ( _: prev: extra // infoFs // prev )
        lib.libsys.metaEntSetSysInfoOv
        lib.libevent.metaEntLifecycleOv
      ];
    in if noFs then meta else meta.__extend ov;
  in if pjsKey == "" then ex else
     throw "getIdentPjs: Reading workspaces has not been implemented.";


# ---------------------------------------------------------------------------- #

  _fenvFns = {
    inherit
      getFieldPjs'
      getFieldsPjs'
      getIdentPjs'
      getVersionPjs'
      getScriptsPjs'
      getHasBinPjs'
      metaEntFromPjsNoWs'
    ;
  };


# ---------------------------------------------------------------------------- #

in {

  inherit
    getFieldPjs'
    getFieldsPjs'
    getIdentPjs'
    getVersionPjs'
    getScriptsPjs'
    getHasBinPjs'

    metaEntGetPjsStrict
    metaEntGetPjsDirStrict
    metaEntGetPjs'

    metaEntSetPjsDirOv
    metaEntSetPjsOv
    metaEntSetScriptsOv
    metaEntPjsHasBinOv
    metaEntPjsSetDepInfo
    metaEntPjsBasicsOv

    metaEntFromPjsNoWs'
  ;

  __withFenv = fenv: let
    cw  = builtins.mapAttrs ( _: lib.callWith fenv ) _fenvFns;
    app = let
      proc = acc: name: acc // {
        ${lib.yank "(.*)'" name} = lib.apply _fenvFns.${name} fenv;
      };
    in builtins.foldl' proc {} ( builtins.attrNames _fenvFns );
  in cw // app;


}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
