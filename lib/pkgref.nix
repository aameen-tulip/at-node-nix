# ============================================================================ #
#
# Package References as Keys and Specs.
#
# "Keys" are used to refer to packages, usually by trees, to lookup a defined
# entry in either a `metaSet' or `pkgSet'.
#
# "Specs" are used to refer to zero or more packages that "satisfy" a set of
# requirements "specified" by the spec.
# NPM calls these "specifiers" and Yarn calls these "descriptors".
#
# NOTE: the same string or attrset may be a key in the context of one container,
# but be a spec in the context of another container!
# The distinction being that a "key" must uniquely refer to a record ( or
# collection of records ), while a spec always refers to a collection of records.
#
# The most common "key" is simply `<IDENT>/<VERSION>', which is used throughout
# this codebase; but in retrospect these should have been named /IV Keys/, being
# "Ident+Version" keys, or "Locators" ( term used by NPM and Yarn ).
#
# Newer APIs should begin migrating to accept `keylike' arguments, which is
# generacally "any string or attrset with enough info to uniquely identify a
# package by exact version".
# This is effectively a "locator", but it intentionally avoids the NPM/Yarn
# terminology to avoid confusion in contexts where we want to convert
# `keylike -> locator' to lookup a package from an NPM lockfile or registry,
# since our abstract keys are not required to adhere to the `<IDENT>@<VERSION>'
# or URI schema used by locators.
#
#
# One important distinction to highlight is that we should never say
# "resolve a key" as we might say "resolve a descriptor", since "resolution"
# implies filtering multiple satisfactory versions or potential resources on
# different registries/filesystems/mirrors.
# Rather we "lookup a key's value", so routine names such as `lookupInFoo' are
# accessing unique key/values in a `Foo' structure.
#
# A single keylike may refer to multiple resources or packages in a structure -
# but only if that structure returns ALL associated records as a list
# or attrset.
# For example we might "lookup" an identifier in a registry, which should return
# all registered versions of a package - being a "Packument" containing multiple
# "abbreviated version info" ( /VInfo/ ) records.
#
# A more precise keylike may be used in the same structure to locate exactly one
# record, but only if this "kind" of keylike would return exactly one result
# forall resources.
# For example, `lodash@4.17.21' is allowed to return exactly one version, and
# `lodash@latest?before=<TIMESTAMP>' might also return exactly one version in
# the context of a registry.
# This same key might not be appropriate in other contexts, for example a blob
# which aggregates local trees alongside remote trees where conflicting
# keylikes could potentially refer to multiple trees.
#
#
# With Nix flakes our equivalent teminology is "locked" vs. "unlocked" refs.
# This is the ideal way to think about "specs" vs "keylikes", and in the future
# I hope to create a Nix plugin which allows use to use specs as input URIs
# that can be recorded as resolved keys in a `flake.lock'.
# The descriptor `foo@latest' could lock to the URI
# `https://registry.npmjs.org/foo/4.2.0?rev=2', allowing the keylike `floco:foo'
# or `floco:foo/latest' to be used anywhere in a flake's eval context to refer
# to that package uniquely.
#
#
# In any case, you get the fucking point by now:
# Keys/locators shouldn't be confused with specs/descriptors, and the difference
# between the two depends on the context that they're used in!
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt    = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  ivkey = yt.PkgInfo.Strings.key;
  mkLoc = n: "(at-node-nix#lib.libfloco.${n}):";
  pp    = lib.generators.toPretty { allowPrettyValues = true; };

# ---------------------------------------------------------------------------- #

  IVKey = let
    coercibleType = yt.eitherN [
      yt.PkgInfo.Eithers.ivkeylike
      ( yt.restrict "ivkeylike[attrs]" ( x:
        ( ( x.ident or x.name or x.identifier or x.key or null ) != null ) &&
          ( ( x.version or x.key or null ) != null ) )
        ( yt.attrs yt.any ) )
    ];
  in {
    name        = "IVKey";
    empty       = "@floco/dummy/0.0.0";
    isType      = IVKey.ytype.check;
    ytype       = ivkey;
    fromNull    = yt.defun [yt.nil ivkey] ( _: IVKey.empty );
    isCoercible = coercibleType.check;
    fromString  = x: let
      p = "(${yt.PkgInfo.RE.id_old_p})[@/](${yt.PkgInfo.RE.version_p}).*";
      m = builtins.match p x;
    in "${builtins.head m}/${builtins.elemAt m 2}";
    toString = x:
      if yt.PkgInfo.key.check x then x else
      if builtins.isString x then IVKey.fromString x else
      if builtins.isAttrs then x.key or ( IVKey.fromAttrs x ) else
      if yt.Typeclasses.stringy x then IVKey.fromString ( toString x ) else
      # Throw
      ( coercibleType x );
    fromAttrs = x: let
      ident    = x.ident or x.name or x.identifier or null;
      version  = x.version or x.locator or null;
      canAttrs = ( ident != null ) && ( version != null );
    in x.key or (
      if canAttrs then "${ident}/${version}" else
      IVKey.fromString ( toString ( coercibleType x ) )  # Probably throws
    );
    toAttrs = x: { ident = dirOf x; version = baseNameOf x; key = x; };
    # Best effort conversion with typechecking
    coerce = let
      inner = x:
        if x == null           then IVKey.empty else
        if builtins.isString x then IVKey.fromString x
        else IVKey.fromAttrs x;
    in yt.defun [coercibleType IVKey.ytype] inner;
    toSerial = IVKey.toString;
    __functor = self: x: {
      _type      = "ivkey";
      val        = self.coerce x;
      __toString = child: child.val;
      __toSerial = child: child.val;
      _vtype     = self.ytype;
    };
  };


# ---------------------------------------------------------------------------- #

  # No type assertions, possibly faster but who knows.
  coerceIVKey = keylike: let
    ident = keylike.ident or keylike.name or keylike.identifier or null;
    str   = toString keylike;
    msg   = "${mkLoc "coerceIVKey"} Cannot convert value '${pp keylike}' of " +
            "type '${builtins.typeOf keylike}' an '<IDENT>/<VERSION>' key.";
  in if ivkey.check keylike then keylike else
     if ( keylike ? key ) && ( ivkey.check keylike.key ) then keylike.key else
     if ( keylike ? version ) && ( ident != null )
     then ident + "/" + keylike.version
     else if ( yt.Typeclasses.stringy.check keylike ) && ( ivkey.check str )
     then str
     else throw msg;


# ---------------------------------------------------------------------------- #

in {
  inherit
    IVKey
    coerceIVKey
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
