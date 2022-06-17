{ lib }: let

/* -------------------------------------------------------------------------- */

  pushDownNames = builtins.mapAttrs ( name: val: val // { inherit name; } );

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


/* -------------------------------------------------------------------------- */

  # Return true if an input is a flake, or false otherwise.
  # This relies on the fact that non-flake inputs lack `sourceInfo' fields.
  # NOTE: This is necessary because you cannot check `inputs.foo.flake' in
  #       the body of an `outputs = { self, ... }: { ... };' block.
  inputIsFlake = x: ( builtins.isAttrs x ) && ( x ? sourceInfo );


/* -------------------------------------------------------------------------- */



/* -------------------------------------------------------------------------- */

in {
  inherit
    pushDownNames
    pkgsAsAttrsets
  ;
}
