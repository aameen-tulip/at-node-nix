# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  inherit (yt) struct string list attrs option restrict;
  inherit (yt.__internal) typedef' typedef;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  Structs = {
  };  # End Structs


# ---------------------------------------------------------------------------- #

  Attrs = {

    meta_ent_shallow = let
      cond = x: ( builtins.isAttrs x ) && ( ( x._type or null ) == "metaEnt" );
    in typedef "meta_ent[shallow]" cond;

  };  # End Attrs


# ---------------------------------------------------------------------------- #

in {
  inherit
    Structs
    Attrs
  ;
  #inherit (Structs)
  #  meta_ent
  #;
  inherit (Attrs)
    meta_ent_shallow
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
