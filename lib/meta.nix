# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #

  # Metadata must be "flat" plain old data.
  # No derivations, no store paths, no string contexts.
  # If you want any of those things, scroll down and use `passthru'.
  #
  # Metadata fields should not need to be "recomputed" once retrieved, and
  # need to be able to write to/from JSON to be saved on disk.
  # Derivations cannot be serialized, except in the Nix store;
  # similarly Store Paths cannot be read from a regular file or from JSON,
  # because Nix has no way of determining which derivation produced the path.
  # This is why the separation between `passthru' and `meta' exists.
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
  # XXX: For a local tree, you shouldn't record that metadata to disk, because
  # presumably whatever version number is in your `package.json' isn't "real".
  # You could add some ridiculous hash to ensure you don't write "bad"
  # metadata, OR you can let Nix do that for you - all you do it
  # "don't call `builtins.unsafeRemoveStringContext'".
  # Yep, that's it, pretty easy.
  # No need to generate a unique hash for your source tree, because y'know,
  # that's that thing that Nix does all the time for every file using
  # string contexts.
  # This giant block about "meta" is really aiming to tell you "meta" is the
  # exception to Nix's tracking, so we treat it with exceptional caution.
  #
  # These functions never call `builtins.unsafeDiscardStringConext' - and this
  # is intentional ( and I know it seems inconvenient ).
  # This is because we NEED the user to take responsibility for explicitly
  # deciding when contexts should be stripped, so that we can use `meta' tags
  # in "impure" builds without poisoning the cache.


# ---------------------------------------------------------------------------- #

  # `__serial' is a functor attached to attrsets which produces a reduced
  # attrset of fields which may be written to disk.
  # This functor is recursive by default, so any fields which are attrsets and
  # have their own `__serial' function will be respected recursively.
  # The use case here is largely for stashing values which were realized through
  # impure operations or "import from derivation" routines, which we want to
  # purify in later builds.
  #
  # For example, we may as an optimization lookup the `narHash' of fetched
  # tarballs to allow us to use `builtins.fetchTree' in pure evaluation mode in
  # later runs.
  # Alternatively we may query an NPM registry to look up package information
  # that we want to save for later runs to avoid running those queries again.
  #
  # `__serial' functions are written with the intention of being used with
  # "recursive attrsets", such as those seen in overlays and fixed-points.
  # With that in mind they are always written to accept the argument `self' -
  # with the single exception of `serialIgnore' which accepts no argument and
  # is simply the boolean value `false' ( indicating that this attrset should
  # be ignored entirely - this is done to distinguish from the literal value
  # false, and is a slight optimization over `serialDrop' which requires
  # string comparison ).
  #
  # I expect that in many cases you will want to write your own implementation
  # of `__serial' to suit your use case; but a sane default implementation may
  # be found below and used as a jumping off point for your own custom routine.
  # Please remember our rules for serializing data in Nix though:
  #   1. Serialized data must be readable and writable by `(to|from)JSON' -
  #      this means only attrsets, strings, booleans, lists, floats, and
  #      integers may be written.
  #   2. Store paths must not appear in strings - this means derivations may
  #      not be serialized because both their inputs and `outPath' fields
  #      contain Nix store paths.
  #   3. Fields with the name `__serial', `__extend', and `passthru' should
  #      never be written, and in general you should treat any field beginning
  #      with "__" as hidden by default.
  #      You may have cases where you actually do want to write "__" prefixed
  #      fields, but you are expected to explicitly whitelist those in a custom
  #      `__serial' implementation.
  #   4. The string value "__DROP__" is reserved and should not be written.
  #      This allows recursive `__serial' functions to dynamically hide fields.
  #   5. You should always respect the `serialIgnore' pattern for recursive
  #      `__serial' functions.
  #      This simply means ignoring `v ? __serial && v.__serial == serialIgnore'
  #      attrset values in an object ( see `serialDefault' `keepAttrs' ).

  extInfoExtras = [
    "__update" "__add" "__extend" "__serial" "__entries" "__unfix__"
    "__updateEx" "__extendEx" "__new" "__thunkWith" "__thunksWith"
  ];

  # The simplest type of serializer.
  serialAsIs   = self: removeAttrs self ( extInfoExtras ++ ["passthru"] );
  # Do not serialize attrsets with this serializer, you must explicitly check
  # for this reserved serializer.
  # See notes in section above.
  serialIgnore = false;
  # A second type of reserved serializer which allows recursive `__serialize'
  # routines to dynamically hide members.
  # See notes in section above.
  serialDrop   = self: "__DROP__";

  # A sane default serializer.
  # Use this as a model for your implementations.
  serialDefault = self: let
    keepF = k: v: let
      inherit (builtins) isAttrs isString typeOf elem;
      keepType = elem ( typeOf v ) ["set" "string" "bool" "list" "int" "float"];
      keepAttrs =
        if v ? __serial then v.__serial != serialIgnore else
          ( ! lib.isDerivation v );
      keepStr = ! lib.hasPrefix "/nix/store/" v;
      keepT =
        if isAttrs  v then keepAttrs else
        if isString v then keepStr   else keepType;
      keepKey = ! lib.hasPrefix "__" k;
    in keepKey && keepT;
    keeps = lib.filterAttrs keepF ( serialAsIs self );
    serializeF = k: v: let
      fromSerial =
        if builtins.isFunction v.__serial then v.__serial v else v.__serial;
      fromAttrs = if v ? __serial then fromSerial else
                  if v ? __toString then toString v else
                  serialDefault v;
    in if builtins.isAttrs v then fromAttrs else v;
    serialized = builtins.mapAttrs serializeF keeps;
  in lib.filterAttrs ( _: v: v != "__DROP__" ) serialized;


# ---------------------------------------------------------------------------- #

  # Coerce arg to be a recursive attrset.
  # Arg must be either a recursive or non-recursive attrset.
  asRecur = x: if builtins.isFunction x then x else
    assert builtins.isAttrs x;
    ( self: x );


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
  # I strongly recommend using `extInfoExtras' as a base list of fields to
  # always exclude.
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
  # This is literally just `callPackageWith' and is provided for convenience,
  # this does not modify our attrset in any way.
  # The argument to `__thunkWith' must be a function which accepts an attrset as
  # its argument.
  # The result will be a "thunk" which holds unapplied args and the orginal
  # function as fields in an attrset.
  # The function will be applied when an additional attrset of arguments is
  # given; the entries of the `metaExt' will be updated with these args, and
  # applied to the stashed function.
  # The resulting return value will be extended with the fields `override' and
  # maybe `overrideDerivation' ( for derivations only ) which allow users to
  # re-evaluate the thunk with modified args.
  # I strongly suggest reading the Nixpkgs' manual about "overrides" and
  # `callPackage[s][With]' for more info.
  #
  # `__thunksWith' is just an alias for `callPackagesWith'.
  # This one should be used on "functions that return functions/drvs".
  # The arg to `__thunksWith' must be a function which takes a single attrset as
  # as arg which returns an attrset of functions.
  # The difference is the `override*' fields are added to members of the
  # returned attrset rather than the return value itself.
  # This is likely what you want to use on a file full of helper routines; for
  # example you would evaluate THIS file ( `meta.nix' ) as:
  #   ( mkExtInfo' {} {
  #     inherit ( import <nixpkgs> {} ) lib;
  #   } ).__thunksWith ./meta.nix {}
  # NOTE: this example is just to show the usage; but because this file only
  #       takes a single arg this example is pretty contrived.
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
  # `__new' allows `mkExtInfo'' to be used as a "base class" for creating
  # other types of extensible attrsets based on the same interface.
  # You can think of this like the "constructor".
  #
  # `extra' fields are simply functors, which will be regenerated any time
  # the attrset is modified.
  # You are welcome to override these, but pay attention to the application of
  # `self', and how this differs slightly from the default values defined
  # below ( `extra' functors must accept `self' as their first argument ).
  mkExtInfo' = {
    __serial  ? serialDefault
  , __entries ? self:
      removeAttrs self ( extInfoExtras ++ ( builtins.attrNames extra ) )
  , ...
  } @ extra: info: let
    infoR = asRecur info;
    self = ( infoR self ) // ( {
      __update    = info': self.__new ( self // info' );
      __add       = info': self.__new ( info' // self );
      __extend    = g: self.__new ( lib.fixedPoints.extends g self.__unfix__ );
      __serial    = __serial self;
      __entries   = __entries self;
      __unfix__   = infoR;
      __updateEx  = extra': mkExtInfo' ( extra // extra' ) self;
      __extendEx  = extraR: mkExtInfo' ( extraR extra ) self;
      __new       = mkExtInfo' extra;
      __thunkWith = lib.callPackageWith self.__entries;
      # Use this for functions which return other functions or drvs.
      # It yields a `callPackages' equivalent.
      __thunksWith = lib.callPackagesWith self.__entries;
    } // ( builtins.mapAttrs ( _: fn: fn self ) extra ) );
  in self;

  mkExtInfo = mkExtInfo' {};


# ---------------------------------------------------------------------------- #

  # FIXME: make `entFromtype' use this to type-check in `metaEntCore'.
  metaEntryFromtypes = [
    "package.json"
    "package-lock.json"      # Detect version
    "package-lock.json(v1)"
    "package-lock.json(v2)"
    "package-lock.json(v3)"
    "yarn.lock"              # Detect version
    "yarn.lock(v1)"
    "yarn.lock(v2)"
    "yarn.lock(v3)"
    "manifest"
    "packument"
    "raw"                    # Fallback/Default for manual entries
  ];

  metaEntWasPlock = { entFromtype ? "raw", ... }:
    builtins.elem entFromtype [
      "package-lock.json"
      "package-lock.json(v1)"
      "package-lock.json(v2)"
      "package-lock.json(v3)"
    ];


# ---------------------------------------------------------------------------- #

  # Hide values which can be easily inferred from `package-lock.json' entry.
  # For example we know the entry must declare `hasInstallScript' so we can
  # safely omit it.
  metaEntPlSerial = self: let
    # Start with the default serializer's output.
    dft = metaEntSerialDefault self;
    # Drop values which are assumed to be false when unspecified.
    hides = [
      "hasBin"
      "hasBuild"
      "hasInstallScript"
    # When `hasInstallScript == true' we always preserve `gypfile', otherwise
    # we always drop it.
    ] ++ ( lib.optional ( ! ( self.hasInstallScript or false ) ) "gypfile" );
    hide = removeAttrs dft hides;
    keepTrue = let
      cond = k: v: ( builtins.elem k hides ) && ( v == true );
    in lib.filterAttrs cond dft;
  in assert metaEntWasPlock self;
     hide // keepTrue;


# ---------------------------------------------------------------------------- #

  metaEntSerialDefault = self: removeAttrs ( serialDefault self ) [
    "_type" "__pscope"
  ];

  # Maps `entFromtype' to default serializers.
  # Largely these hide additional fields which can be easily inferred using
  # `entFromtype`.
  metaEntSerialByFromtype = {
    "package-lock.json"     = metaEntPlSerial;
    "package-lock.json(v1)" = metaEntPlSerial;
    "package-lock.json(v2)" = metaEntPlSerial;
    "package-lock.json(v3)" = metaEntPlSerial;
    _default                = metaEntSerialDefault;
  };

  metaEntSerial = { entFromtype ? "_default", ... } @ self:
    metaEntSerialByFromtype.${entFromtype} self;


# ---------------------------------------------------------------------------- #

  # Add metadata related to output names and other misc name info.
  # NOTE: This is also available as a non-recursive "flat" addition below as
  # `metaEntNames' as a slight optimization at the expense of treating names
  # as "static", this also has the advantage of avoiding any accidental
  # recursion headaches with later extensions.
  metaEntExtendWithNames = final: prev: {
    scoped = ( builtins.substring 0 1 prev.ident ) == "@";
    names = {
      __serial = false;
      bname = baseNameOf prev.ident;
      scopeDir = if final.scoped then "${dirOf prev.ident}/" else "";
      node2nix =
        ( if final.scoped then "_at_${final.names.scope}_slash_" else "" ) +
        "${final.names.bname}-${prev.version}";
      registryTarball = "${final.names.bname}-${prev.version}.tgz";
      localTarball =
        ( if final.scoped then "${final.names.scope}-" else "" ) +
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
    } // ( lib.optionalAttrs final.scoped {
      scope = lib.yank "@([^/]+)/.*" prev.ident;
    } );
  };

  # Exactly the same as the above function but non-recursive.
  # This form is slightly faster but names must be modified manually.
  # NOTE: This was largely added to avoid a specific instance of infinite
  # recursion that crops up when attempting merge packages which use aliases
  # such as `npm:<IDENT>'; the recursive form is still far more flexible though.
  metaEntNames = { ident, version, ... } @ me: let
    scoped = ( builtins.substring 0 1 ident ) == "@";
    names = {
      __serial = false;
      bname = baseNameOf ident;
      scopeDir = if scoped then "${dirOf ident}/" else "";
      node2nix =
        ( if scoped then "_at_${names.scope}_slash_" else "" ) +
        "${names.bname}-${version}";
      registryTarball = "${names.bname}-${version}.tgz";
      localTarball =
        ( if scoped then "${names.scope}-" else "" ) + names.registryTarball;
      genName   = cat: "${names.bname}-${cat}-${version}";
      tarball   = names.registryTarball;
      src       = "${names.bname}-source-${version}";
      built     = "${names.bname}-built-${version}";
      installed = "${names.bname}-inst-${version}";
      prepared  = "${names.bname}-prep-${version}";
      bin       = "${names.bname}-bin-${version}";
      module    = "${names.bname}-module-${version}";
      global    = "${names.bname}-${version}";
    } // ( lib.optionalAttrs scoped { scope = lib.yank "@([^/]+)/.*" ident; } );
  in { inherit scoped names; };


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
    key         ? args.ident + "/" + args.version
  , ident       ? dirOf args.key
  , version     ? baseNameOf args.key
  , entFromtype ? "raw"
  } @ args: mkExtInfo' {
    __serial  = metaEntSerial;
    # Ignore extra fields, and similar to `__serial' recur `__entries' calls.
    __entries = self: let
      scrub = removeAttrs self ( extInfoExtras ++ [
        "_type" "__pscope"
      ] );
      subEnts = _: v: if ( v ? __entries ) then v.__entries else v;
    in builtins.mapAttrs subEnts scrub;
  } {
    _type = "metaEnt";
    inherit key ident version entFromtype;
    # We don't hard code this in the serializer in case the user actually does
    # want to serialize their `entries', allowing them the ability to override.
    entries.__serial = false;
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
  } @ members: let
    args =
      builtins.intersectAttrs ( lib.functionArgs mkMetaEntCore )
                              ( { inherit ident version key; } // members );
    core = mkMetaEntCore args;
    base = core.__update members;
    # Add `names' either as a flat field or recursively.
    withNames = if recNames then base.__extend metaEntExtendWithNames else
                base.__add ( metaEntNames core );
  in withNames;

  mkMetaEnt = mkMetaEnt' {};


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
    getPname = x: baseNameOf x.ident;
    is = mapVals ( groupBy getPname ) gs;
    getVers = x: "v${replaceStrings ["." "+"] ["_" "_"] x.version}";
    vs = mapVals ( mapVals ( ids: mapVals head ( groupBy getVers ids ) ) ) is;
  in vs;


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
        __meta = ( members.__meta or {} ) // { __serial = false; };
        _type = "metaSet";
      };
      # `members' is already recursively defined so we must extend.
      membersRFromFn = let
        addMeta = final: prev: {
          __meta = ( prev.__meta or {} ) // { __serial = false; };
          _type  = "metaSet";
        };
      in lib.fixedPoints.extends addMeta members;
    in if builtins.isFunction members then membersRFromFn else
       assert builtins.isAttrs members;
       membersRFromAS;
    extras = let
      __entries = self: removeAttrs self ( extInfoExtras ++ [
        "__meta" "__pscope" "__unkey" "__mapEnts" "_type"
        "__maybeApplyEnt"
      ] );
    in {
      __serial  = self: removeAttrs ( serialDefault self ) ["_type" "__pscope"];
      inherit __entries;
      # We need to avoid infinite recursion with `__new', so we don't call
      # `mkMetaSet' directly here.
      __new = self: lib.libmeta.mkExtInfo' extras;
      # Converts keys to groups of attrs with no special characters.
      # XXX: Really just for REPL usage. Do not use this in routines.
      # FIXME: possible hide this behind a conditional for REPL only.
      __unkey = unkeyAttrs __entries;
      # Apply a function to all entries.
      __mapEnts = self: fn: self.__new ( builtins.mapAttrs fn self.__entries );
      # Apply function to entry if it exists, otherwise do nothing.
      # This may seem superfulous but in practice this is an incredibly common
      # pattern when trying to override meta-data.
      __maybeApplyEnt = self: fn: field:
        if ! ( self.__entries ? ${field} ) then self else
          self.__update { ${field} = fn self.${field}; };
    };
  in lib.libmeta.mkExtInfo' extras membersR;


# ---------------------------------------------------------------------------- #

  # Determines if a package needs any `nodeModulesDir[-dev]' fields.
  # If `hasBuild' is not yet set, we will err on the safe side and assume it
  # has a build.
  # XXX: It is strongly recommended that you provide a `hasBuild' field.
  metaEntIsSimple = {
    hasBuild         ? true
  , hasInstallScript ? false
  , hasPrepare       ? false
  , hasBin           ? false
  , ...
  } @ attrs: ! ( hasBuild || hasInstallScript || hasPrepare || hasBin );

  metaSetPartitionSimple = mset: let
    lst = builtins.attrValues mset.__entries;
    parted = builtins.partition metaEntIsSimple lst;
  in {
    simple       = parted.right;
    needsModules = parted.wrong;
  };


# ---------------------------------------------------------------------------- #

  genMetaEntAdd = cond: fn: ent:
    if cond ent then ent.__add ( fn ent ) else ent;

  genMetaEntUp = cond: fn: ent:
    if cond ent then ent.__update ( fn ent ) else ent;

  genMetaEntExtend = cond: fn: ent:
    if cond ent then ent.__extend ( fn ent ) else ent;

  genMetaEntMerge = cond: fn: ent: let
    m = lib.recursiveUpdate ( fn ent.__entries ) ( ent.__entries );
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
    m = lib.recursiveUpdate ( fn set.__setries ) ( set.__setries );
  in if cond set then set.__update m else set;

  genMetaSetRules = name: cond: fn: {
    "metaSetAdd${name}"    = genMetaSetAdd    cond fn;
    "metaSetUp${name}"     = genMetaSetUp     cond fn;
    "metaSetExtend${name}" = genMetaSetExtend cond fn;
    "metaSetMerge${name}"  = genMetaSetMerge  cond fn;
  };


# ---------------------------------------------------------------------------- #

in {
  # Base Serializers
  inherit
    serialAsIs
    serialIgnore
    serialDrop
    serialDefault
  ;
  # Base ExtInfo
  inherit
    mkExtInfo'
    mkExtInfo
  ;
  # Meta Entries
  inherit
    metaEntryFromtypes
    metaEntSerialDefault
    metaEntSerial
    metaEntExtendWithNames
    metaEntNames
    mkMetaEntCore
    mkMetaEnt'
    mkMetaEnt
    metaEntIsSimple
    metaEntWasPlock
  ;
  # Meta Sets
  inherit
    mkMetaSet
    metaSetPartitionSimple  # by `metaEntIsSimple'
  ;
  # Utils and Misc
  inherit
    unkeyAttrs
    extInfoExtras
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
}
