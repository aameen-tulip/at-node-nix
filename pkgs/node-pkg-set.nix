{ lib
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
