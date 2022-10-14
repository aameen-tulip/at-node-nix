# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  pkgsAsAttrsets = pkgs: let
    inherit (builtins) mapAttrs head;
    inherit (lib) groupBy;
    ms        = m: if m.scope == null then "_" else m.scope;
    gscope    = groupBy ms;
    gname     = mapAttrs ( _: groupBy ( m: m.pname ) );
    gversion  = mapAttrs ( _: mapAttrs ( _: groupBy ( m: m.version ) ) );
    toAttrs   = mapAttrs ( _: mapAttrs ( _: mapAttrs ( _: head ) ) );
    scoped    = gscope pkgs;
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
