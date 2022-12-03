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
    "raw"                    # Fallback/Default for manual entries
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

in {
  inherit
    Enums
    Attrs
    Typeclasses
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

  inherit
    _meta_ext_fields
    _meta_fromtypes
    _plock_fromtypes
    _ylock_fromtypes
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
