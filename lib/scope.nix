# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  pi = yt.PkgInfo;

# ---------------------------------------------------------------------------- #

  # Typeclass for Package/Module "Scope" name.
  Scope = let
    coercibleSums = yt.sum {
      identifier = pi.Strings.identifier_any;
      ident      = pi.Strings.identifier_any;
      name       = pi.Strings.identifier_any;
      meta       = yt.attrs yt.any;
      inherit (pi.Strings) key;
    };
    coercibleStructs_l = [
      ( yt.struct { inherit (pi.Strings) scope; } )
      pi.Structs.scope
      pi.Structs.identifier
      pi.Structs.id_locator
      pi.Structs.id_descriptor
    ];
    coercibleStrings_l = [
      ( yt.restrict "scope(dirty)" ( lib.test "@([^@/]+)" ) yt.string )
      pi.Strings.scope
      pi.Strings.scopedir
      pi.Strings.identifier_any
      pi.Strings.id_locator
      pi.Strings.id_descriptor
      pi.Strings.key
    ];
    # null -> `{ scope = null; scopedir = ""; }'
    coercibleType = let
      eithers = coercibleStructs_l ++ coercibleStrings_l ++ [coercibleSums];
    in yt.option ( yt.eitherN eithers );
  in {
    name = "Scope";
    # Strict YANTS type for a string or attrset representation of a Scope.
    # "foo" or { scope ? "foo"|null, scopedir = ( "" | "@${scope}/" ); }
    ytype  = yt.either pi.Strings.id_part pi.Structs.scope;
    isType = Scope.ytype.check;
    # Is `x' coercible to `Scope'?
    isCoercible = coercibleType.check;

    # Nullable
    empty    = { scope = null; scopedir = ""; };
    fromNull = yt.defun [yt.nil pi.Structs.scope] ( _: Scope.empty );

    # Parser
    fromString = let
      inner = str: let
        m         = builtins.match "((@([^@/]+)(/.*)?)|[^@/]+)" str;
        scopeAt   = builtins.elemAt m 2;
        scopeBare = builtins.head m;
        scope     = if scopeAt == null then scopeBare else scopeAt;
      in if ( m == null ) || ( scope == "unscoped" ) then Scope.empty else {
        inherit scope;
        scopedir = "@${scope}/";
      };
    in yt.defun [( yt.eitherN coercibleStrings_l ) yt.PkgInfo.Structs.scope]
                inner;
    # Writer
    toString = let
      inner = x:
        if builtins.isString x then "@${x}" else
        if x.scope == null then "" else "@${x.scope}";
    in yt.defun [Scope.ytype yt.string] inner;

    # Parser
    fromAttrs = let
      inner = x: let
        fromField =
          if ! ( x ? scope ) then Scope.empty else
          if builtins.isString x.scope then Scope.fromString x.scope else
          x.scope;
      in if pi.Structs.scope.check x then x else
         if x ? meta then Scope.fromAttrs x.meta else
         if ( x ? key ) || ( x ? ident ) || ( x ? name ) then
           Scope.fromString ( x.key or x.ident or x.name )
         else fromField;
      eithers = coercibleStructs_l ++ [coercibleSums];
    in yt.defun [( yt.eitherN eithers ) pi.Structs.scope] inner;
    # Serializer
    toAttrs = x: { inherit (Scope.coerce x) scope; };

    # Best effort conversion
    coerce = let
      inner = x:
        if x == null           then Scope.empty else
        if builtins.isString x then Scope.fromString x
        else Scope.fromAttrs x;
    in yt.defun [coercibleType pi.Structs.scope] inner;

    # Object Constructor/Instantiator
    __functor    = self: x: {
      _type      = self.name;
      val        = self.coerce x;
      __toString = child: self.toString child.val;
      __serial   = child: self.toAttrs child.val;
      _vtype     = self.ytype;
    };
  };


# ---------------------------------------------------------------------------- #

in {
  inherit Scope;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
