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

  addFlocoPackages = prev: pkgs: let
    fp = if prev ? flocoPackages.extend then prev.flocoPackages else
         if prev ? flocoPackages
         then lib.makeExtensible ( final: prev.flocoPackages )
         else lib.makeExtensible ( final: {} );
    pkgsE =
      if ! ( lib.isFunction pkgs ) then ( _: _: pkgs ) else
      if ! ( lib.isFunction ( pkgs {} ) ) then ( _: pkgs ) else pkgs;
  in fp.extend pkgsE;


# ---------------------------------------------------------------------------- #

in {
  inherit
    pkgsAsAttrsets
    addFlocoPackages
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
