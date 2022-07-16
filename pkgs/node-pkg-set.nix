{ lib
, doFetch      # A configured `fetcher' from `./build-support/fetcher.nix'.
, typeOfEntry
, fetchurl    ? lib.fetchurlDrv
, buildGyp
, evalScripts
}: let

/* -------------------------------------------------------------------------- */

/**
 *
 * {
 *   [tarball]
 *   source       ( unpacked into "$out" )
 *   [built]      ( `build'/`pre[pare|publish]' )
 *   [installed]  ( `gyp' or `[pre|post]install' )
 *   [bin]        ( bins symlinked to "$out" from `source'/`built'/`installed' )
 *   [global]     ( `lib/node_modules[/@SCOPE]/NAME[/VERSION]' [+ `bin/'] )
 *   module       ( `[/@SCOPE]/NAME' [+ `.bin/'] )
 *   passthru     ( Holds the fields above )
 *   key          ( `[@SCOPE/]NAME/VERSION' )
 *   meta         ( package info yanked from locks, manifets, etc - no drvs! )
 * }
 *
 */


/* -------------------------------------------------------------------------- */

  entryFromTypes = [
    "package.json"
    "package-lock.json"      # Detect version
    "package-lock.json(v1)"
    "package-lock.json(v2)"
    "yarn.lock"              # Detect version
    "yarn.lock(v1)"
    "yarn.lock(v2)"
    "yarn.lock(v3)"
    "manifest"
    "packument"
  ];


/* -------------------------------------------------------------------------- */

  serialAsIs   = self: self;
  serialIgnore = false;
  serialDrop   = self: "__DROP__";

  serialDefault = self: let
    keepF = k: v: let
      inherit (builtins) isAttrs isString typeOf elem;
      keepType = elem ( typeOf v ) ["set" "string" "bool" "list" "int"];
      keepAttrs =
        if v ? __serial then v.__serial != serialIgnore else
          ( ! lib.isDerivation v ) && ( ! lib.hasPrefix "__" k );
      keepStr = ! lib.hasPrefix "/nix/store/" v;
      keepT = if isAttrs  v then keepAttrs else
              if isString v then keepStr   else keepType;
    in keepT;
    keeps = lib.filterAttrs keepF ( removeAttrs self ["__serial" "passthru"] );
    serializeF = k: v: let
      fromAttrs = if v ? __serial then v.__serial v else
                  if v ? __toString then toString v else
                  self.__serial v;
    in if builtins.isAttrs v then fromAttrs else v;
    serialized = builtins.mapAttrs serializeF keeps;
  in lib.filterAttrs ( _: v: v != "__DROP__" ) serialized;


/* -------------------------------------------------------------------------- */

  # Make an extensible attrset with functors `__extend', `__entries', and
  # `__serial' which are intended to create a common interface for handling
  # various sorts of package info.
  # `__extend` allow you to apply overlays to add new fields in a fixed point,
  # and is identical to the `nixpkgs.lib.extends' "overlay" function.
  # `__entries' scrubs any "non-entry" fields which is useful for mapping over
  # "real" entries to avoid processing meta fields.
  # `__serial' scrubs any entries or fields of those entries which should not
  # be written to disk in the even that entries are serialized with a function
  # such as `toJSON' - it is recommended that you replace the default
  # implementation for this functor in most cases.
  mkExtInfo = { serialFn ? serialDefault }: info: let
    info' = self: info // {
      __serial  = serialFn self;
      __entries = lib.filterAttrs ( k: _: ! lib.hasPrefix "__" ) self;
    };
  in lib.makeExtensibleWithCustomName "__extend" info';


/* -------------------------------------------------------------------------- */

  mergeExtInfo = f: g: let
    inherit (builtins) isAttrs intersectAttrs mapAttrs isFunction;
    mergeAttr = k: gv: let
      ext = let
        gOvA = prev: gv.__unfix__ or ( final: gv );
        gOvF = if isFunction ( gv {} ) then gv else ( final: gv );
        gOv  = if isAttrs gv then gOvA else gOvF;
      in if gv ? __extend then mergeExtInfo f.${k} gv else
         f.${k}.__extend gOv;
      reg = if ( isAttrs gv ) && ( f ? ${k} )
            then lib.recursiveUpdate f.${k} gv
            else gv;
      isExt = ( isFunction gv ) || ( f ? ${k}.__extend );
    in if isExt then ext else reg;
    ext = mapAttrs mergeAttr ( intersectAttrs f g );
  in f.__extend ext;


/* -------------------------------------------------------------------------- */

  metaCore = {
    key     ? args.ident + "/" + args.version
  , ident   ? dirOf args.key
  , version ? baseNameOf args.key
  } @ args: let
    em = mkExtInfo {
      inherit key ident version;
      entries.__serial = false;
      __type = "ext:meta";
    };
    addNames = final: prev: {
      scoped = ( builtins.substring 0 1 prev.ident ) != "@";
      names = {
        __serial = false;
        bname = baseNameOf prev.ident;
        node2nix =
          ( if final.scoped then "_at_${final.names.scope}_slash_" else "" ) +
          "${final.names.bname}-${prev.version}";
        registryTarball = "${final.names.bname}-${prev.version}.tgz";
        localTarball =
          ( if final.scoped then "${final.names.scope}-" else "" ) +
          final.names.registryTarball;
        tarball   = final.names.registryTarball;
        src       = "${final.names.bname}-source-${prev.version}";
        built     = "${final.names.bname}-built-${prev.version}";
        installed = "${final.names.bname}-inst-${prev.version}";
        prepared  = "${final.names.bname}-prep-${prev.version}";
        module    = "${final.names.bname}-module-${prev.version}";
        global    = "${final.names.bname}-${prev.version}";
      } // ( if final.scoped then { scope = dirOf prev.ident; } else {} );
    };
  in em.__extend addNames;


/* -------------------------------------------------------------------------- */

  # v2 package locks normalize most fields, so for example, `bin' will always
  # be an attrset of name -> path, even if the original `project.json' wrote
  # `"bin": "./foo"' or `"direcories": { "bin": "./scripts" }'.
  pkgEntFromPlockV2 = pkey: {
    version
  , hasInstallScript ? false
  , hasBin ? ( pl2ent.bin or {} ) != {}
  , ident ? pl2ent.name or lib.yank' ".*node_modules/((@[^@/]+/)?[^@/]+)" pkey
  , ...
  } @ pl2ent: let

    meta = ( metaCore { inherit ident version; } ) // {
      inherit hasInstallScript hasBin;
      entries.__serial = false;
      entries.pl2 = pl2ent // { inherit pkey; };
    } // ( lib.optionalAttrs hasBin { inherit (pl2ent) bin; } );

    basics = { inherit key ident version meta; };

    entType = typeOfEntry pl2ent;

    tarball = let
      url  = pl2ent.resolved;
      hash = pl2ent.integrity;
    in if entType != "registry-tarball" then null else fetchurl {
      name = meta.names.registryTarball;
      inherit hash url;
      unpack = false;
    };

    source = doFetch pl2ent;

    # FIXME: pass in the whole package set somewhere so we can create the
    # the `passthru' members `nodeModulesDir[-dev]'.

    # Assumed to be a git checkout or local tree.
    # These do not run the `install' or `prepare' routines, since those are
    # supposed to run after `install'.
    built = final: if ! final.hasBuild then null else evalScripts {
      name = meta.names.built;
      src = source;
      inherit (final.passthru) nodejs;
      # Both `dependencies' and `devDependencies' are available for this step.
      # NOTE: `devDependencies' are NOT available during the `install'/`prepare'
      # builder and you should consider how this effects both closures and
      # any "non-standard" fixups you do a package.
      nodeModules = final.passthru.nodeModulesDir-dev;
      runScripts = [
        # These aren't supported by NPM, but they are supported by Pacote.
        # Realistically, you want them because of Yarn.
        "prebuild" "build" "postbuild"
        # NOTE: I know, "prepublish" I know.
        # It is fucking evil, but you probably already knew that.
        # `prepublish' actually isn't run for publishing or `git' checkouts
        # which aim to mimick the creation of a published tarball.
        # It only exists for backwards compatibility to support a handful of
        # ancient registry tarballs.
      ] ++ ( lib.optional ( entType != "git" ) "prepublish" );
    };

    # FIXME
    installed = if ! hasInstallScript then null else final: let
      # Runs `gyp' and may run `[pre|post]install' if they're defined.
      # You may need to add meta hints to hooks to account for neanderthals that
      # hide the `binding.gyp' file in a subdirectory - because `npmjs.org'
      # does not detect these and will not contain correct `gypfile' fields in
      # registry manifests.
      gyp = buildGyp {
        name = final.meta.names.installed;
        src = final.built or final.source;
        inherit (final.passthru) nodejs;
        nodeModules = final.passthru.nodeModulesDir;
      };
      # Plain old install scripts.
      std = evalScripts {
        name = final.meta.names.installed;
        src = final.built or final.source;
        inherit (final.passthru) nodejs;
      };
      # Add node-gyp "just in case" and check dynamically.
      # This is just to avoid IFD but you should add an overlay with hints
      # to avoid using this builder.
      maybeGyp = evalScripts {
      };
    in if final.meta.gypfile or false then gyp else std;

    prepared = final: let
      src = final.installed or final.built or final.source;
    in if ! final.hasPrepare then src else evalScripts {
      name = meta.names.prepared;
      inherit ident version src;
      nodeModules = final.passthru.nodeModulesDir;
      runScripts = ["preprepare" "prepare" "postprepare"];
    };

    bin = null;
    global = null;
    module = null;
    passthru = {};

  in basics;



/* -------------------------------------------------------------------------- */

  mkPkgEntry = {
    ident
  , version
  , key           ? ident + "/" + version
  , entryFromType ? null
  } @ fields: let
  in {};


/* -------------------------------------------------------------------------- */

in {
}


/* -------------------------------------------------------------------------- */
