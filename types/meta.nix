# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  inherit (yt) struct string list attrs option restrict;
  inherit (yt.__internal) typedef' typedef typeError;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  _meta_ext_fields = [
    "__add"
    "__entries"
    "__extend"
    "__extendEx"
    "__new"
    "__serial"
    "__thunkWith"
    "__unfix__"
    "__update"
    "__updateEx"
  ];

  _meta_ent_core_extra_fields = [
    "_type" "key" "ident" "version" "entFromtype" "metaFiles"
  ];
  _meta_ent_core_fields =
    yt.FlocoMeta._meta_ext_fields ++ yt.FlocoMeta._meta_ent_core_extra_fields;

  _meta_set_core_extra_fields = [
    "_type" "_meta" "__unkey" "__mapEnts" "__maybeApplyEnt" "__filterEnts"
  ];
  _meta_set_core_fields =
    yt.FlocoMeta._meta_ext_fields ++ yt.FlocoMeta._meta_set_core_extra_fields;


# ---------------------------------------------------------------------------- #

  _meta_fromtypes = [
    "package.json"
    "package-lock.json"      # Detect version
    "package-lock.json(v1)"
    "package-lock.json(v2)"
    "package-lock.json(v3)"
    "yarn.lock"              # Detect version
    "yarn.lock(v1)"
    "yarn.lock(v2)"
    "yarn.lock(v3)"
    "vinfo"
    "packument"
    # Generic types, usually for manually provided or merged info
    "explicit"   # High priority
    "raw"        # Fallback/Default medium priority
    "cached"     # Low priority
    "composite"  # Merged from other types ( non-specific )
  ];
  Enums.meta_fromtype = yt.enum "meta_fromtype" yt.FlocoMeta._meta_fromtypes;


  _ylock_fromtypes = [
    "yarn.lock"
    "yarn.lock(v1)"
    "yarn.lock(v2)"
    "yarn.lock(v3)"
  ];
  Enums.ylock_fromtype = yt.enum "ylock_fromtype" yt.FlocoMeta._ylock_fromtypes;


  _plock_fromtypes = [
    "package-lock.json"
    "package-lock.json(v1)"
    "package-lock.json(v2)"
    "package-lock.json(v3)"
  ];
  Enums.plock_fromtype = yt.enum "plock_fromtype" yt.FlocoMeta._plock_fromtypes;


# ---------------------------------------------------------------------------- #

  Attrs = {

    meta_ent_shallow = let
      cond = x: ( builtins.isAttrs x ) && ( ( x._type or null ) == "metaEnt" );
    in typedef "metaEnt[shallow]" cond;

    meta_set_shallow = let
      cond = x: ( builtins.isAttrs x ) && ( ( x._type or null ) == "metaSet" );
    in typedef "metaSet[shallow]" cond;

  };  # End Attrs


# ---------------------------------------------------------------------------- #

  Typeclasses = {

    meta_ext = let
      missing = x: builtins.filter ( f: ! ( builtins.hasAttr f x ) )
                                   yt.FlocoMeta._meta_ext_fields;
      cond   = x: ( builtins.isAttrs x ) && ( ( missing x ) == [] );
    in typedef' {
      name = "metaExt";
      checkType = x: let
        msm = builtins.concatStringsSep ", " ( missing x );
        err = if ( missing x ) == [] then typeError "metaExt (attrs)" x else
              "expected a metaExt, but attrs '${msm}' are missing from value " +
              "'${yt.__internal.prettyPrint x}'";
        ok = cond x;
      in if ok then { inherit ok; } else { inherit ok err; };
    };


    meta_ent = yt.restrict "metaEnt" ( x: ( x._type or null ) == "metaEnt" )
                                     yt.FlocoMeta.Typeclasses.meta_ext;
    meta_set = yt.restrict "metaSet" ( x: ( x._type or null ) == "metaSet" )
                                     yt.FlocoMeta.Typeclasses.meta_ext;

  };  # End Typeclasses


# ---------------------------------------------------------------------------- #

  _bin_info_fields = {
    binPairs = yt.PkgInfo.bin_pairs;
    binDir   = yt.FS.relpath;
  };

  Structs.bin_info_raw = yt.struct "bin_info" {
    binPairs = yt.option _bin_info_fields.binPairs;
    binDir   = yt.option _bin_info_fields.binDir;
  };

  Structs.bin_info = typedef' {
    name      = "bin_info";
    checkType = v: let
      raw     = yt.FlocoMeta.Structs.bin_info_raw.checkType v;
      base    = if raw.ok then removeAttrs raw ["err"] else raw;
      hasAtLeastOne = let
        ok   = ( v ? binPairs ) || ( v ? binDir );
        err' = if ok then {} else {
          err =
            "expected 'bin_info', but value '${yt.__internal.prettyPrint v}' " +
            "lacks either a 'binPairs' or 'binDir' field.";
        };
      in if raw.ok then { inherit ok; } // err' else {};
    in base // hasAtLeastOne // { ok = raw.ok && hasAtLeastOne.ok; };
  };


# ---------------------------------------------------------------------------- #

  Structs.tree_info = yt.struct "tree_info" {
    prod = yt.option ( yt.attrs yt.PkgInfo.key );
    dev  = yt.option ( yt.attrs yt.PkgInfo.key );
  };


# ---------------------------------------------------------------------------- #

  Structs.filesystem_info = yt.struct "filesystem_info" {
    gypfile = yt.bool;
    dir     = yt.FS.relpath;
  };


# ---------------------------------------------------------------------------- #

  _meta_files_info_fields = {
    __serial     = yt.either yt.function ( yt.attrs yt.any );
    pjsDir       = yt.FS.abspath;
    lockDir      = yt.FS.abspath;
    vinfoUrl     = yt.Uri.Strings.uri_ref;
    packumentUrl = yt.Uri.Strings.uri_ref;
    metaRaw      = yt.attrs yt.any;
    pjs          = yt.attrs yt.any;
    plock        = yt.NpmLock.plock_shallow;
    plent        = yt.NpmLock.package;
    plentKey     = yt.NpmLock.pkey;
    vinfo        = yt.Packument.vinfo_meta;
    packument    = yt.Packument.packument;
    trees        = yt.FlocoMeta.Structs.tree_info;
  };

  Structs.meta_files_info =
    yt.struct "meta_files_info"
      ( builtins.mapAttrs ( _: yt.option )
                          yt.FlocoMeta._meta_files_info_fields );


# ---------------------------------------------------------------------------- #

  _meta_ent_info_fields = {
    _type = yt.enum "_type[metaEnt]" ["metaEnt"];
    inherit (yt.PkgInfo) key version;
    ident       = yt.PkgInfo.identifier;
    entFromtype = yt.FlocoMeta.Enums.meta_fromtype;
    names       = yt.attrs ( yt.eitherN [
      yt.function yt.string yt.bool ( yt.attrs yt.string )
    ] );
    inherit (ytypes.Npm.Enums) ltype;
    binInfo    = yt.FlocoMeta.Structs.bin_info;
    depInfo    = yt.attrs yt.DepInfo.dep_info;
    fetchInfo  = yt.FlocoFetch.Eithers.fetch_info_floco;
    sourceInfo = yt.FlocoFetch.source_info_floco;
    sysInfo    = yt.Npm.sys_info;
    inherit (yt.Npm) lifecycle;
    treeInfo   = yt.FlocoMeta.Structs.tree_info;
    fsInfo     = yt.FlocoMeta.Structs.filesystem_info;
    metaFiles  = yt.FlocoMeta.Structs.meta_files_info;
  };

  meta_ent_info = let
    mandatory = {
      inherit (yt.FlocoMeta._meta_ent_info_fields)
        _type key version ident entFromtype ltype depInfo fetchInfo lifecycle
        sysInfo names
      ;
    };
    optional = builtins.mapAttrs ( _: yt.option ) {
      inherit (yt.FlocoMeta._meta_ent_info_fields)
        binInfo metaFiles fsInfo treeInfo sourceInfo
      ;
    };
    innerType = yt.struct "metaEnt:info" ( mandatory // optional );
    checkedFields = v: let
      ignore = k: ( builtins.substring 0 2 k ) == "__";
      drops  = builtins.filter ignore ( builtins.attrNames v );
    in removeAttrs v drops;
    ec = v:
      builtins.addErrorContext "while typechecking '${v.key or "No Key"}'";
  in yt.__internal.typedef' {
    name = "metaEnt";
    checkType = v: let
      shallow = yt.FlocoMeta.Attrs.meta_ent_shallow.checkType v;
      info    = checkedFields v;
      innerCt = innerType.checkType info;
      ok      = shallow.ok && innerCt.ok;
      err'    = if ok then {} else
                if shallow.ok then { inherit (innerCt) err; } else
                { inherit (shallow) err; };
    in { inherit ok; } // err';
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    Enums
    Attrs
    Typeclasses
    Structs
  ;
  inherit (Typeclasses)
    meta_ext
    meta_ent
    meta_set
  ;
  inherit (Attrs)
    meta_ent_shallow
    meta_set_shallow
  ;
  inherit (Structs)
    bin_info
    tree_info
    filesystem_info
    meta_files_info
  ;

  inherit
    _meta_ext_fields
    _meta_ent_core_extra_fields _meta_ent_core_fields
    _meta_set_core_extra_fields _meta_set_core_fields
    _meta_fromtypes
    _plock_fromtypes
    _ylock_fromtypes
    _bin_info_fields
    _meta_files_info_fields
    _meta_ent_info_fields
  ;

  inherit
    meta_ent_info
  ;

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
