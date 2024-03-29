# ============================================================================ #
#
# In an ideal world: metadata would always be "flat" plain old data.
# No derivations, no store paths, no string contexts.
# If you want any of those things, scroll down and use `passthru'.
# This ideal is maintained when "serializing" metadata to disk to be read back
# later - however, in practice we often need to allow metadata representations
# to carry functions or thunks so that they may be specialized and optimized.
#
# In general we aim to keep those types of routines to a strict minimum.
# One clever trick to achieve this is by defining metadata as a recursive set
# of "layers" which may depend on one another - effectively this lets us express
# metadata as a pipeline from "raw" info into processed info, in such a way that
# these transformations are performed lazily.
#
# Ideally, metadata fields should not need to be "recomputed" once retrieved,
# and need to be able to write to/from JSON to be saved on disk.
# Derivations cannot be serialized, except in the Nix store;
# similarly Store Paths cannot be read from a regular file or from JSON,
# because Nix has no way of determining which derivation produced the path.
# This is why the separation between `passthru' and `meta' exists.
# Even when evaluating metadata recursively you should keep derivations and
# store paths in `passthru'!
# If you see existing routines that break this rule please file an issue.
#
#
# ---------------------------------------------------------------------------- #
#
# NOTE: It is fine to "fill metadata" fields from things like a REGISTERED
# `package.json' or `packument' file ( NOT a local tree/git checkout! ), but
# you need to be absolutely positive that this metadata will never change for
# this package version, and in theory you should be able to carve this in
# stone on disk as `read-only' forever and always.
# If you do so, be sure to run `builtins.unsafeRemoveStringContext' so Nix
# knows "no seriously this data is not ever going to change" so that it can
# be dynamically repacked into a regular string.
#
# XXX: For a local tree, you generally shouldn't record that metadata to disk,
# because presumably whatever version number is in your `package.json'
# isn't "real".
# You could add some ridiculous hash to ensure you don't write "bad"
# metadata, OR you can let Nix do that for you - all you do it
# "don't call `builtins.unsafeRemoveStringContext'".
# Yep, that's it, pretty easy.
# No need to generate a unique hash for your source tree, because y'know,
# that's that thing that Nix does all the time for every file using
# string contexts.
#
# This giant block about "meta" is really aiming to tell you "meta" is the
# exception to Nix's tracking, so we treat it with exceptional caution.
#
# These functions never call `builtins.unsafeDiscardStringConext' - and this
# is intentional ( and I know it seems inconvenient ).
# This is because we NEED the user to take responsibility for explicitly
# deciding when contexts should be stripped, so that we can use `meta' tags
# in "impure" builds without poisoning the cache.
#
# Scripts like `genMeta' and certain specialized "serializers" are explicitly
# intended for handling local trees; but this should always be done with
# real caution or some form of infrastructure to auto-update cached info in
# favor of updated metadata.
# See this [[file:../templates/project/flake.nix][project template]] for an
# example of managing a metadata cache as an optimization for a local project.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

  inherit (yt.FlocoMeta)
    _meta_ext_fields
    _meta_ent_core_fields
    _meta_set_core_fields
  ;

  inherit (lib.libmeta)
    serialAsIs serialIgnore serialDrop serialDefault
    metaEntSerialDefault metaEntSerial
  ;

# ---------------------------------------------------------------------------- #

  # Coerce arg to be a recursive attrset.
  # Arg must be either a recursive or non-recursive attrset.
  asRecur = x: if builtins.isFunction x then x else
    assert builtins.isAttrs x;
    ( self: x );


# ---------------------------------------------------------------------------- #

  # Convert package "keys" ( "@foo/bar/1.0.0" ) to attrsets as:
  #   foo = { bar = { v1_0_0 = { ... }; }; };
  # Keys are grouped by scope, name, and the final version field holds the
  # original keys' values.
  # XXX: Please do not use this in any routines; it was written exclusively for
  # convenience when `nix repl' is being used to avoid having to quote fields
  # and allow <TAB> autocompletion to behave as expected.
  unkeyAttrs = __entriesFn: self: let
    inherit (builtins) groupBy attrValues mapAttrs replaceStrings head;
    mapVals = fn: mapAttrs ( _: fn );
    getScope = x: x.scope or x.names.scope or x.meta.names.scope or "_";
    gs = groupBy getScope ( attrValues ( __entriesFn self ) );
    getPname = x:
      baseNameOf ( x.ident or
                   ( builtins.head ( builtins.catAttrs "ident" x ) ) );
    is = mapVals ( groupBy getPname ) gs;
    getVers = x: let
      v = x.version or ( builtins.head ( builtins.catAttrs "version" x ) );
    in "v${replaceStrings ["." "+"] ["_" "_"] v}";
    vs = mapVals ( mapVals ( ids: mapVals head ( groupBy getVers ids ) ) ) is;
  in vs;


# ---------------------------------------------------------------------------- #

  # Make an extensible attrset with functors `__extend', `__entries', and
  # `__serial', etc which are intended to create a common interface for handling
  # various sorts of package info.
  # This is based on Nixpkgs' `makeScope' pattern, which is essentially just a
  # fancy fixed point attrset with a set of "OOP-ish" member functions.
  # We use the pattern for a different purpose, but eagle eyed readers might
  # already see how this object could be used for scope splicing.
  #
  # `__extend` allow you to apply overlays to add new fields in a fixed point,
  # and is identical to the `nixpkgs.lib.extends' "overlay" function.
  #
  # `__entries' scrubs any "non-entry" fields which is useful for mapping over
  # "real" entries to avoid processing meta fields.
  # You may pass in your own definition to hide additional fields; when doing so
  # I strongly recommend using `yt.FlocoMeta._meta_ext_fields' as a base list of
  # fields to always exclude.
  #
  # `__serial' scrubs any entries or fields of those entries which should not
  # be written to disk in the even that entries are serialized with a function
  # such as `toJSON' - it is recommended that you replace the default
  # implementation for this functor in most cases.
  #
  # `__update' may be used to add/set attributes to the attrset.
  # The argument to `__update' may be a regular attrset, or a recursively
  # defined attrset.
  #
  # `__add' is similar to `__update' except it will not overwrite defined fields,
  # this is useful for bulk adding info while avoiding redundancy in evals.
  #
  # `__thunkWith' passes fields from our attrset as arguments to a function
  # which accepts an attrset of named fields as its argument.
  # this does not modify our attrset in any way.
  # The argument to `__thunkWith' must be a function which accepts an attrset as
  # its argument.
  # The result will be a "thunk" which holds unapplied args and the orginal
  # function as fields in an attrset.
  # The function will be applied when an additional attrset of arguments is
  # given; the entries of the `metaExt' will be updated with these args, and
  # applied to the stashed function.
  # The resulting return value will be extended with the fields `override' and
  # which allow users to re-evaluate the thunk with modified args.
  # I strongly suggest reading the Nixpkgs' manual about "overrides" and
  # `callPackage[s][With]' for more info; when doing so keep in mind that we do
  # not provide `overrideDerivation' in our simplified form of `callWithOv', but
  # these routines are otherwise the same.
  #
  # `__unfix__' holds the original argument `info' as a recursively defined
  # attrset ( see `infoR' definition ) which is useful for "deep" overrides.
  # It's unlikely that you'll ever use this yourself, but it's a life saver
  # for deeply nested/complex overrides - so it's here as an escape hatch.
  # For clarity, this exists so that you can reorder or "unapply" overlays.
  # As an example imagine that you have a "pipeline" of ( uncomposed ) overlays
  # that are applied by a routine, and lets say the user wants to replace one of
  # those overlays with an alternative implementation; they're going to
  # accomplish this by doing `( myExt.__new myExt.__unfix__ ).__extend ov' to
  # "undo" the last overlay, and apply an alternative.
  # TRIVIA: In early versions of Nixpkgs a stack of overlays was stashed so you
  # could push/pop and insert overlays in a similar fashion ( this was
  # deprecated later in favor of modules ).
  #
  # `__updateEx' recreates our attrset providing the opportunity to add
  # additional "extra" fields.
  #
  # `__new' allows `_mkExtInfo' to be used as a "base class" for creating
  # other types of extensible attrsets based on the same interface.
  # You can think of this like the "constructor".
  #
  # `extra' fields are simply functors, which will be regenerated any time
  # the attrset is modified.
  # You are welcome to override these, but pay attention to the application of
  # `self', and how this differs slightly from the default values defined
  # below ( `extra' functors must accept `self' as their first argument ).
  _mkExtInfo = {
    __serial  ? serialDefault
  , __entries ? self:
      removeAttrs self ( _meta_ext_fields ++ ( builtins.attrNames extra ) )
  , strict ? false  # Checks `__unfix__' before applying any extensions.
  , ...
  } @ extra: info: let
    # Validates that our `extInfo' wasn't modified using `//'.
    checkUnfix = entries: unfix: entries == ( lib.fix unfix );
    runStrict  = self: after:
      if ! strict then after else
      if checkUnfix self.__entries self.__unfix__ then after else
      throw "extInfo: ExtInfo was corrupted by a non-recursive update";
    infoR = asRecur info;
    self = ( infoR self ) // ( {
      # Our original recursive set.
      # NOTE: direct use of `//' will break the inner fixed point.
      __unfix__ = infoR;
      __extend  = g: let
        after = self.__new ( lib.fixedPoints.extends g self.__unfix__ );
      in runStrict self after;
      __serial    = __serial self;
      __entries   = __entries self;
      __new       = _mkExtInfo extra;
      __updateEx  = extra': _mkExtInfo ( extra // extra' ) self;
      __extendEx  = extraR: _mkExtInfo ( extraR extra ) self;
      __thunkWith = lib.callWithOvStrict self.__entries;
      # Turn a non-recursive attrset into an extension, then apply it.
      __update = info': self.__extend ( _: _: info' );
      # Apply an "add" overlay which preserves existing keys.
      __add = info': let
        ov = final: prev: let
          proc = acc: key: if prev ? ${key} then acc else acc // {
            ${key} = info'.${key};
          };
        in builtins.foldl' proc {} ( builtins.attrNames info' );
      in self.__extend ov;
    } // ( builtins.mapAttrs ( _: fn: fn self )
                             ( removeAttrs extra ["strict"] ) ) );
  in self;

  mkExtInfo = lib.libmeta._mkExtInfo {};


# ---------------------------------------------------------------------------- #

  # Was `x' a `meta(Set|Ent)' created from one of `allowedTypes'?
  # `allowedTypes' can be specialized.
  #
  # The argument parser was isolated so you can replace `__innerFunction' to
  # replace the predicate used to check against the terminal FromType string.
  #   ( lib.metaWasPlock // { __innerFunction = self: builtins.isString; } ) ""
  #   ==> true
  _metaWasFrom = allowedTypes: {
    inherit allowedTypes;
    __functionMeta = {
      name      = "_metaWasFrom";
      from      = "at-node-nix#lib.libmeta";
      signature = let
        arg1 = yt.either yt.string ( yt.attrs yt.any );
      in [arg1 yt.string];
    };
    __functionArgs = { fromType = true; entFromType = true; _meta = true; };

    # TODO: yell at user for deprecated names
    __processArgs = self: arg: let
      dargs = arg.fromType or arg._meta.fromType or arg.entFromtype or "raw";
    in if builtins.isString arg then arg else dargs;

    __innerFunction = self: targ:
      builtins.elem targ self.allowedTypes;

    __functor = self: arg:
      self.__innerFunction self ( self.__processArgs self arg );
  };

  metaWasPlock     = _metaWasFrom yt.FlocoMeta._plock_fromtypes;
  metaWasYlock     = _metaWasFrom yt.FlocoMeta._ylock_fromtypes;
  metaSupportsPlV3 = _metaWasFrom [
    "package-lock.json(v2)" "package-lock.json(v3)"
  ];


# ---------------------------------------------------------------------------- #

  # Add metadata related to output names and other misc name info.
  # NOTE: This is also available as a non-recursive "flat" addition below as
  # `metaEntNames' as a slight optimization at the expense of treating names
  # as "static", this also has the advantage of avoiding any accidental
  # recursion headaches with later extensions.
  metaEntExtendWithNames = final: prev: {
    names = let
      scoped = ( builtins.substring 0 1 prev.ident ) == "@";
    in {
      __serial = lib.libmeta.serialIgnore;
      inherit scoped;
      bname = baseNameOf prev.ident;
      scopeDir = if scoped then "${dirOf prev.ident}/" else "";
      node2nix =
        ( if scoped then "_at_${final.names.scope}_slash_" else "" )
        + "${final.names.bname}-${prev.version}";
      registryTarball = "${final.names.bname}-${prev.version}.tgz";
      localTarball =
        ( if scoped then "${final.names.scope}-" else "" ) +
        final.names.registryTarball;
      genName   = cat: "${final.names.bname}-${cat}-${prev.version}";
      tarball   = final.names.registryTarball;
      src       = "${final.names.bname}-source-${prev.version}";
      built     = "${final.names.bname}-built-${prev.version}";
      installed = "${final.names.bname}-inst-${prev.version}";
      prepared  = "${final.names.bname}-prep-${prev.version}";
      bin       = "${final.names.bname}-bin-${prev.version}";
      module    = "${final.names.bname}-module-${prev.version}";
      global    = "${final.names.bname}-${prev.version}";
      # Short "(<SCOPE>--)?<BNAME>"
      flake-id-s = let
        sp = if scoped then "${final.names.scope}--" else "";
        r  = "${sp}${final.names.bname}";
      in builtins.replaceStrings ["/" "@" "."] ["--" "--" "_"] r;
      # Long "(<SCOPE>--)?<BNAME>--<VERSION>"
      flake-id-l = let
        r = "${final.names.flake-id-s}--${prev.version}";
      in builtins.replaceStrings ["/" "@" "."] ["--" "--" "_"] r;
      flake-ref = { id = final.names.flake-id-s; ref = prev.version; };
      shardScope = let
        fl = builtins.substring 0 1 final.ident;
      in if scoped then final.names.scope else
        "unscoped/${fl}";
      shardDir = final.names.shardScope + "/" + final.names.bname;
    } // ( lib.optionalAttrs scoped {
      scope = lib.yank "@([^/]+)/.*" prev.ident;
    } );
  };

  # Exactly the same as the above function but non-recursive.
  # This form is slightly faster but names must be modified manually.
  # NOTE: This was largely added to avoid a specific instance of infinite
  # recursion that crops up when attempting merge packages which use aliases
  # such as `npm:<IDENT>'; the recursive form is still far more flexible though.
  metaEntNames = { ident ? me.name, version, ... } @ me: let
    r = lib.extends metaEntExtendWithNames ( final: { inherit ident; } // me );
  in { inherit (lib.fix r) names; };


# ---------------------------------------------------------------------------- #

  # Extensible core `meta' info for Node.js packages.
  # This aims to gather and organize information from various sources such as
  # `package.json' files, lockfiles, registry info, etc into a common object
  # that builders can refer to.
  # The intention here is to convert from `pkg spec -> meta -> derivation'
  # so that each builder doesn't have to include their own
  # `pkg spec -> derivation' routines, since these would quickly become a mess.
  #
  # By default this demands that the package `ident' ( "name" ) and version
  # are provided, and it will add verious derivation names so that they may be
  # consistent across various types of builders.
  mkMetaEntCore = {
    key         ? "${args.ident}/${args.version}"
  , ident       ? dirOf args.key
  , version     ? baseNameOf args.key
  , entFromtype ? "raw"
  } @ args: lib.libmeta._mkExtInfo {
    __serial = metaEntSerial;
    # Ignore extra fields, and similar to `__serial' recur `__entries' calls.
    __entries = self: let
      # NOTE: Do NOT use `_meta_ent_core_fields' since that would hide things
      # like `key', `version', `ident', etc.
      scrub = removeAttrs self ( _meta_ext_fields ++ ["_type" "__pscope"] );
      subEnts = _: v: if ( v ? __entries ) then v.__entries else v;
    in builtins.mapAttrs subEnts scrub;
  } {
    _type = "metaEnt";
    inherit key ident version entFromtype;
    # We don't hard code this in the serializer in case the user actually does
    # want to serialize their `entries', allowing them the ability to override.
    metaFiles.__serial = lib.libmeta.serialIgnore;
  };


  # A sane default constructor for creating a package entry.
  # We leave a few configurables available in this form that we hide for the
  # more common `mkMetaEnt' function.
  mkMetaEnt' = {
    recNames ? false  # Add `names' by extension allowing easy renaming later
  , ...
  } @ opts:
  { ident   ? members.name or dirOf members.key
  , version ? baseNameOf members.key
  , key     ? "${ident}/${version}"
  , ...
  } @ members:
  # XXX: You mispelled "entFromtype" in a `metaEnt' constructor.
  assert ! ( members ? entFromType ); let
    args = { inherit ident version key; } // members;
    core = lib.apply mkMetaEntCore args;
    base = core.__update ( {
      metaFiles = core.metaFiles // ( members.metaFiles or {} );
    } // members );
    # Add `names' either as a flat field or recursively.
    withNames = if recNames then base.__extend metaEntExtendWithNames else
                base.__add ( metaEntNames core );
  in withNames;

  mkMetaEnt = mkMetaEnt' {};


# ---------------------------------------------------------------------------- #

  # Represents a collection of `metaEnt' attrs which organizes entries by "key".
  # This carries some additional helper functors aimed at making it easy to
  # operate on entries within the set.
  # The purpose of this attrset is largely to allow references between entries
  # in a way that respects "self reference" at multiple scopes.
  # With that in mind, always remember that you're in the danger zone here -
  # you are operating on a recursive attrset which contains large numbers of
  # recursive attrsets ( which may themselves contains recursive attrsets ).
  # This level of nested self reference is a practical necessity for organizing
  # package sets with complex topo-sorts; but do your best to keep it simple.
  # XXX: I've shot my foot off more than a few times "getting fancy" with
  # deep recursion, and it has a way of getting out of hand quickly when you try
  # to compose overlays in ways where "order starts to matter".
  # So seriously, be sure you are organizing your compositions carefully, test
  # often, use your REPL, and godspeed!
  mkMetaSet = members: let
    # Make `members' recursive if it isn't, and add some core fields.
    # FIXME: There's a less repetitive way to write `membersR' but I'm not in
    #        the mood right now.
    membersR = let
      # Non-recursive case
      membersRFromAS = final: members // {
        _meta = {
          __serial = lib.libmeta.serialIgnore;
        } // ( members._meta or {} );
        _type = "metaSet";
      };
      # `members' is already recursively defined so we must extend.
      membersRFromFn = let
        addMeta = final: prev: {
          _meta = {
            __serial = lib.libmeta.serialIgnore;
          } // ( prev._meta or {} );
          _type  = "metaSet";
        };
      in lib.fixedPoints.extends addMeta members;
    in if builtins.isFunction members then membersRFromFn else
       assert builtins.isAttrs members;
       membersRFromAS;
    extras = let
      # NOTE: This hides `_meta'
      __entries = self:
        removeAttrs self ( _meta_set_core_fields ++ ["__pscope"] );
    in {
      __serial  = self:
        removeAttrs ( serialDefault self ) ["_type" "__pscope"];
      inherit __entries;
      # We need to avoid infinite recursion with `__new', so we don't call
      # `mkMetaSet' directly here.
      __new = self: lib.libmeta._mkExtInfo extras;
      # Converts keys to groups of attrs with no special characters.
      # XXX: Really just for REPL usage. Do not use this in routines.
      # TODO: possible hide this behind a conditional for REPL only?
      __unkey = unkeyAttrs __entries;
      # Apply a function to all entries preservice self reference.
      __mapEnts = self: fn:
        self.__extend ( final: prev:
          builtins.mapAttrs fn ( removeAttrs prev [
            "_meta" "_type" "__pscope"
          ] )
        );
      # Apply function to entry if it exists, otherwise do nothing.
      # This may seem superfulous but in practice this is an incredibly common
      # pattern when trying to override meta-data.
      __maybeApplyEnt = self: fn: field: let
        ov = final: prev: { ${field} = fn prev.${field}; };
      in if ! ( self.__entries ? ${field} ) then self else self.__extend ov;
      __filterEnts = self: pred: lib.filterAttrs pred self.__entries;
    };
  in lib.libmeta._mkExtInfo extras membersR;


# ---------------------------------------------------------------------------- #

  genMetaEntAdd = cond: fn: ent:
    if cond ent then ent.__add ( fn ent ) else ent;

  genMetaEntUp = cond: fn: ent:
    if cond ent then ent.__update ( fn ent ) else ent;

  genMetaEntExtend = cond: fn: ent:
    if cond ent then ent.__extend ( fn ent ) else ent;

  genMetaEntMerge = cond: fn: ent: let
    m = lib.recursiveUpdate ( fn ent.__entries ) ent.__entries;
  in if cond ent then ent.__update m else ent;

  genMetaEntRules = name: cond: fn: {
    "metaEntAdd${name}"    = genMetaEntAdd    cond fn;
    "metaEntUp${name}"     = genMetaEntUp     cond fn;
    "metaEntExtend${name}" = genMetaEntExtend cond fn;
    "metaEntMerge${name}"  = genMetaEntMerge  cond fn;
  };


# ---------------------------------------------------------------------------- #

  genMetaSetAdd = cond: fn: set:
    if cond set then set.__add ( fn set ) else set;

  genMetaSetUp = cond: fn: set:
    if cond set then set.__update ( fn set ) else set;

  genMetaSetExtend = cond: fn: set:
    if cond set then set.__extend ( fn set ) else set;

  genMetaSetMerge = cond: fn: set: let
    m = lib.recursiveUpdate ( fn set.__entries ) set.__entries;
  in if cond set then set.__update m else set;

  genMetaSetRules = name: cond: fn: {
    "metaSetAdd${name}"    = genMetaSetAdd    cond fn;
    "metaSetUp${name}"     = genMetaSetUp     cond fn;
    "metaSetExtend${name}" = genMetaSetExtend cond fn;
    "metaSetMerge${name}"  = genMetaSetMerge  cond fn;
  };


# ---------------------------------------------------------------------------- #

  # Merge `metaExt' objects ( of the same type preferably ) by recursively
  # updating attrsets, and recursively merging child `metaExt' members.
  # NOTE: This will not pick up `<metaExt>.<attrSet>.<metaExt>' "grandchild"
  # records in it's recursion; those get merged using `recursiveUpdate'.
  metaExtsMerge = a: b: let
    isMeta = let
      t = yt.either yt.FlocoMeta.meta_ent_shallow yt.FlocoMeta.meta_set_shallow;
    in t.check;
    typeCheck = v: let
      tf = lib.throwIfNot ( ( a._type or null ) == ( b._type or null ) )
           "metaExtMerge: both arguments must be of meta `_type'";
      generic = lib.throwIfNot ( ( isMeta a ) && ( isMeta b ) )
                "metaExtMerge: both argument must be `metaExt' attrsets";
    in generic ( tf v );
    # Tries various ways of merging common attrs such that `b' "updates" `a'.
    # This is "best effort", not bullet-proof - if  you need something more
    # exact that this write your own damn merger.
    mergeF = af: bf: let
      aM        = isMeta af;
      bM        = isMeta bf;
      bothAttrs = ( builtins.isAttrs af ) && ( builtins.isAttrs bf );
    in if aM && bM then metaExtsMerge af bf else
       if aM then af.__update ( lib.recursiveUpdate af.__entries bf ) else
       if bM then bf.__update ( lib.recursiveUpdate af bf.__entries ) else
       if bothAttrs then lib.recursiveUpdate af bf else bf;
    # This on it's own is likely a useful helper.
    asOverlay = final: prev: let
      common = builtins.intersectAttrs prev b.__entries;
      keys = builtins.attrNames common;
      proc = acc: key: acc // { ${key} = mergeF prev.${key} b.${key}; };
      m    = builtins.foldl' proc {} keys;
    in b.__entries // m;
  in typeCheck ( a.__extend asOverlay );


# ---------------------------------------------------------------------------- #

in {
  # Base ExtInfo
  inherit
    _mkExtInfo
    mkExtInfo
  ;
  # Meta Entries
  inherit
    metaEntExtendWithNames
    metaEntNames
    mkMetaEntCore
    mkMetaEnt'
    mkMetaEnt
    metaWasPlock
    metaWasYlock
    metaSupportsPlV3
  ;
  # Meta Sets
  inherit
    mkMetaSet
  ;
  # Utils and Misc
  inherit
    unkeyAttrs
  ;

  inherit
    genMetaEntAdd
    genMetaEntUp
    genMetaEntExtend
    genMetaEntMerge
    genMetaEntRules

    genMetaSetAdd
    genMetaSetUp
    genMetaSetExtend
    genMetaSetMerge
    genMetaSetRules
  ;

  inherit
    metaExtsMerge
  ;
}
