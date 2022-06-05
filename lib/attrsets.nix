{ lib ? ( import <nixpkgs> {} ).lib }:
let
  inherit (lib) mapAttrs groupBy;
in {

  pushDownNames = lib.mapAttrs ( name: val: val // { inherit name; } );

  pkgsAsAttrsets = pkgs:
    let
      ms = m: if m.scope == null then "_" else m.scope;
      gscope = groupBy ms;
      gname = mapAttrs ( _: s: groupBy ( m: m.pname ) s );
      gversion =
        mapAttrs ( _: s: mapAttrs ( _: n: groupBy ( m: m.version ) n ) s );
      toAttrs = let inherit (builtins) head; in
        mapAttrs ( _: s: mapAttrs ( _: n: mapAttrs ( _: v: head v ) n ) s );
      scoped = gscope pkgs;
      named = gname scoped;
      versioned = gversion named;
    in toAttrs versioned;


}
