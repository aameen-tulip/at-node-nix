# ============================================================================ #
#
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
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  inherit (yt.FlocoMeta) _meta_ext_fields;
  inherit (lib.libmeta) metaWasPlock metaWasYlock;

# ---------------------------------------------------------------------------- #

  # The simplest type of serializer.
  serialAsIs = self: removeAttrs self ( _meta_ext_fields ++ ["passthru"] );

  # Do not serialize attrsets with this serializer, you must explicitly check
  # for this reserved serializer.
  # See notes in section above.
  serialIgnore = false;

  # A second type of reserved serializer which allows recursive `__serialize'
  # routines to dynamically hide members.
  # See notes in section above.
  serialDrop   = self: "__DROP__";


# ---------------------------------------------------------------------------- #

  # A sane default serializer.
  # Use this as a model for your implementations.
  # This is essentially similar to `lib.generators.toPretty', so if you're
  # familiar with that routine and `__toPretty' we're doing the same thing
  # except we aren't producing strings.
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
      cond = k: v:
        ( builtins.elem k hides ) && ( builtins.isBool v ) && v;
    in lib.filterAttrs cond dft;
  in assert metaWasPlock self;
     hide // keepTrue;


# ---------------------------------------------------------------------------- #

  metaEntSerialDefault = self: let
    drops = ["_type" "scoped"];
    base = removeAttrs ( serialDefault self ) drops;
    # TODO: fetchInfo relative paths
  in base;


# ---------------------------------------------------------------------------- #

  # Maps `entFromtype' to default serializers.
  # Largely these hide additional fields which can be easily inferred using
  # `entFromtype`.
  metaEntSerialByFromtype = {
    "package.json"          = metaEntSerialDefault;  # TODO
    "vinfo"                 = metaEntSerialDefault;  # TODO
    "packument"             = metaEntSerialDefault;  # TODO
    "package-lock.json"     = metaEntPlSerial;
    "package-lock.json(v1)" = metaEntPlSerial;
    "package-lock.json(v2)" = metaEntPlSerial;
    "package-lock.json(v3)" = metaEntPlSerial;
    "yarn.lock"             = metaEntSerialDefault;  # TODO
    "yarn.lock(v1)"         = metaEntSerialDefault;  # TODO
    "yarn.lock(v2)"         = metaEntSerialDefault;  # TODO
    "yarn.lock(v3)"         = metaEntSerialDefault;  # TODO
    raw                     = metaEntSerialDefault;
    _default                = metaEntSerialDefault;
  };


  metaEntSerial = { entFromtype ? "_default", ... } @ self:
    metaEntSerialByFromtype.${entFromtype} self;


# ---------------------------------------------------------------------------- #

in {

  inherit
    serialAsIs
    serialIgnore
    serialDrop
    serialDefault
  ;

  inherit
    metaEntSerialDefault
    metaEntSerial
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
