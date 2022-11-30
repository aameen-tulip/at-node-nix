# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  inherit (yt) struct string list attrs option restrict;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  _dep_info_fields = {
    inherit (yt.PkgInfo.Strings) descriptor;
    runtime        = yt.bool;
    dev            = yt.bool;
    optional       = yt.bool;
    peer           = yt.bool;
    peerDescriptor = yt.PkgInfo.Strings.descriptor;
    pin            = yt.PkgInfo.locator;  # version or URI.
    # Custom types ( generally associated with lifecycle events )
    # NOTE: The actual type allows bools for any unrecognized fields; but these
    # are explicitly named to reserve their use by `floco' in the future.
    build   = yt.bool;
    install = yt.bool;
    test    = yt.bool;
    lint    = yt.bool;
    pack    = yt.bool;
    publish = yt.bool;
  };

  _dep_info_non_bool_keys   = ["descriptor" "peerDescriptor" "pin"];
  _dep_info_non_bool_fields = {
    inherit (_dep_info_fields) descriptor peerDescriptor pin;
  };


# ---------------------------------------------------------------------------- #

  Attrs.dep_info = let
    condNonBools = x: let
      comm = builtins.intersectAttrs x _dep_info_non_bool_fields;
      proc = acc: f: acc && ( comm.${f}.check x.${f} );
    in builtins.foldl' proc ( comm != {} ) ( builtins.attrNames comm );
    condBools = x: let
      fields = removeAttrs x _dep_info_non_bool_keys;
    in builtins.all builtins.isBool ( builtins.attrValues fields );
    cond = x: ( builtins.isAttrs x ) && ( condNonBools x ) && ( condBools x );
  in yt.__internal.typedef "dep_info" cond;


  Attrs.dep_info_direct = let
    anyTrue = x: builtins.any ( v: v == true ) ( builtins.attrValues x );
    cond = x: ( x ? descriptor ) && ( anyTrue x );
  in yt.restrict "direct" cond Attrs.dep_info;


  Attrs.dep_info_peer = let
    cond = x: ( x ? peerDescriptor ) && x.peer;
  in yt.restrict "peer" cond Attrs.dep_info;


# ---------------------------------------------------------------------------- #

  Attrs.dep_info_pinnable = let
    cond = x: x ? descriptor;
  in yt.restrict "pinnable" cond Attrs.dep_info;

  Attrs.dep_info_custom = let
    cond = x: ( removeAttrs x ( _dep_info_non_bool_fields ++ [
      "dev" "peer" "runtime" "optional"
    ] ) ) != {};
  in yt.restrict "custom" cond Attrs.dep_info;


# ---------------------------------------------------------------------------- #

in {
  inherit _dep_info_fields;
  inherit
    Attrs
  ;
  inherit (Attrs)
    dep_info
    dep_info_direct
    dep_info_pinnable
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
