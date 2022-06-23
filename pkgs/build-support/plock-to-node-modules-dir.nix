{ lib
, linkModules
, fetcher
, mkNodeTarball
}: let

  ftpath = plock: { key, ... }@attrs: let
    r        = lib.libplock.realEntry plock key;
    tb       = mkNodeTarball ( fetcher r );
    unpacked = attrs.unpacked or tb.unpacked;
  in { name = key; path = unpacked.outPath or unpacked; };

  plock2nmFocus = plock: workspace: let
    deps  = depClosureFor ["dependencies" "devDependencies"] plock workspace;
    deps' = builtins.filter ( x: x.key != workspace ) deps;
  in linkModules "node_modules" ( map ftpath deps' );

  plock2nm = plock:
    linkModules "node_modules" ( map ftpath plock.packages );

in { inherit plock2nmFocus plock2nm; }
