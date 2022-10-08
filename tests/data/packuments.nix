let
  idents = import ./idents.nix;
  fij = url: builtins.fromJSON ( builtins.readFile ( builtins.fetchurl url ) );
  fip-npmjs = i: fij "https://registry.npmjs.org/${i}";
in map fip-npmjs idents
