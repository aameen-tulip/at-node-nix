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

  stdPjsArgProc' = { pure, ifd, typecheck, allowedPaths } @ fenv: let
    rjenv = removeAttrs fenv ["metaEntOverlays"];
  in self: {
    pjs    ? lib.libpkginfo.readJSONFromPath' rjenv ( pjsDir + "/package.json" )
  , wkey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace members without 'pjsDir'."
  }: let
    loc = self.__functionMeta.name or "libpjs";
    args = if wkey == "" then { inherit pjs wkey pjsDir fenv; } else
           throw "(${loc}): Reading workspaces has not been implemented.";
    targs = if self ? __thunk then self.__thunk // args else args;
    fargs = if self ? __functionArgs
            then lib.canPassStrict self.__functionArgs targs else targs;
  in fargs;


# ---------------------------------------------------------------------------- #

  # Abstracts workspaces
  getFieldPjs' = { field, default ? null }: {
    pure, ifd, typecheck, allowedPaths
  } @ fenv: let
    rjenv = removeAttrs fenv ["metaEntOverlays"];
  in {
    pjs    ? lib.libpkginfo.readJSONFromPath' rjenv ( pjsDir + "/package.json" )
  , wkey   ? ""
  , pjsDir ?
    throw "getFieldPjs': Cannot read workspace members without 'pjsDir'."
  }: if wkey == "" then pjs.${field} or default else
     throw "getFieldPjs': Reading workspaces has not been implemented.";

  getFieldsPjs' = { fields }: {
    pure, ifd, typecheck, allowedPaths
  } @ fenv: let
    rjenv = removeAttrs fenv ["metaEntOverlays"];
  in {
    pjs    ? lib.libpkginfo.readJSONFromPath' rjenv ( pjsDir + "/package.json" )
  , wkey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace members without 'pjsDir'."
  }: let
    fa = if builtins.isAttrs fields then fields else
         builtins.foldl' ( acc: f: acc // { ${f} = false; } ) {} fields;
  in if wkey == "" then builtins.intersectAttrs fa pjs else
     throw "getFieldsPjs': Reading workspaces has not been implemented.";


# ---------------------------------------------------------------------------- #

  getIdentPjs'   = getFieldPjs'  { field = "name"; };
  getVersionPjs' = getFieldPjs'  { field = "version"; };
  getScriptsPjs' = getFieldPjs'  { field = "scripts"; default = {}; };

  getHasBinPjs' = { pure, ifd, allowedPaths, typecheck } @ fenv: let
    rjenv = removeAttrs fenv ["metaEntOverlays"];
  in {
    pjs    ? lib.libpkginfo.readJSONFromPath' rjenv ( pjsDir + "/package.json" )
  , wkey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace members without 'pjsDir'."
  } @ args: let
    fields = getFieldsPjs' {
      fields = { bin = true; directories = true; };
    } fenv args;
  in ( fields.bin or fields.directories.bin or {} ) != {};


# ---------------------------------------------------------------------------- #

  # FIXME: `metaEntOverlays'
  metaEntFromPjsNoWs' = { pure, ifd, typecheck, allowedPaths } @ fenv: let
    rjenv = removeAttrs fenv ["metaEntOverlays"];
    raenv = removeAttrs fenv ["typecheck" "metaEntOverlays"];
  in {
    pjs    ? lib.libpkginfo.readJSONFromPath' rjenv ( pjsDir + "/package.json" )
  , wkey   ? ""
  , pjsDir ?
    throw "getIdentPjs: Cannot read workspace/write fetchInfo without 'pjsDir'."
  , isLocal ? true
  , ltype   ? "dir"
  , basedir ? toString pjsDir
  } @ args: let
    gargs = removeAttrs args ["basedir" "ltype" "isLocal"];
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
        path      = assert wkey == "";  pjsDir;
        recursive = true;
      };
    };
    extra = getFieldsPjs' {
      fields = {
        bin         = true;
        directories = true;
        os          = true;
        cpu         = true;
        engines     = true;
        gypfile     = true;  # Rarely declared but it happens.
      };
    } fenv gargs;
    # We recycle `depInfoEntFromPlockV3' since we don't have a generic form.
    # The regular routine is fine for this, we just pass in a phony path.
    # At time of writing the `path' field isn't used anyway.
    deps = let
      plent = getFieldsPjs' {
        fields = {
          dependencies         = true;
          devDependencies      = true;
          optionalDependencies = true;
          peerDependencies     = true;
          peerDependenciesMeta = true;
        };
      } fenv gargs;
    in {
      depInfo   = lib.libdep.depInfoEntFromPlockV3 "" plent;
      depFields = plent;
    };
    # Merged mispelled field because NPM allows either spelling because they
    # couldn't be bothered to write a linter.
    bundled' = let
      fields = getFieldsPjs' {
        fields = { bundledDependencies = true; bundleDependencies = true; };
      } fenv gargs;
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
      metaFiles = { __serial = false; inherit pjs wkey; } //
                  ( if ! ( args ? pjsDir ) then {} else { inherit pjsDir; } );
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
      # TODO: this should be a separate overlay made to be general purpose.
      scriptInfo = final: prev: {
        hasBuild         = lib.libpkginfo.hasBuildFromScripts prev.scripts;
        hasPrepare       = lib.libpkginfo.hasPrepareFromScripts prev.scripts;
        hasTest          = lib.libpkginfo.hasTestFromScripts prev.scripts;
        hasPack          = lib.libpkginfo.hasPackFromScripts prev.scripts;
        hasPublish       = lib.libpkginfo.hasPublishFromScripts prev.scripts;
        hasInstallScript =
          if lib.libpkginfo.hasInstallFromScripts prev.scripts then true else
          null;
      };
      #ovs = metaEntOverlays or [];
      #...
      ov = lib.composeExtensions ( _: prev:
        extra // infoFs // prev
      ) scriptInfo;
    in meta.__extend ov;
  in if wkey == "" then ex else
     throw "getIdentPjs: Reading workspaces has not been implemented.";


# ---------------------------------------------------------------------------- #

  _fenvFns = {
    inherit
      # TODO: reorder args getField[s]Pjs'
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
