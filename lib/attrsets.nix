# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  pkgsAsAttrsets = pkgs: let
    inherit (builtins) mapAttrs groupBy;
    mscope    = m: if ( m.scope or null ) == null then "unscoped" else m.scope;
    gscope    = builtins.groupBy mscope;
    gname     = mapAttrs ( _: builtins.groupBy ( m: m.pname ) );
    gversion  = mapAttrs ( _: mapAttrs ( _: groupBy ( m: m.version ) ) );
    toAttrs   = mapAttrs ( _: mapAttrs ( _: mapAttrs ( _: builtins.head ) ) );
    plist     = if builtins.isList pkgs then pkgs else builtins.attrValues pkgs;
    scoped    = gscope plist;
    named     = gname scoped;
    versioned = gversion named;
  in toAttrs versioned;


# ---------------------------------------------------------------------------- #

in {
  inherit
    pkgsAsAttrsets
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
