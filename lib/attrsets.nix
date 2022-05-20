{ lib ? ( import <nixpkgs> {} ).lib }:
{
  pushDownNames = lib.mapAttrs ( name: val: val // { inherit name; } );
}
