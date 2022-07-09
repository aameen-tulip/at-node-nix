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

  plock2nmFocus' = depFields: plock: workspace: let
    inherit (lib.libplock) depClosureFor;
    deps  = depClosureFor depFields plock workspace;
    deps' = builtins.filter ( x: x.key != workspace ) deps;
  in linkModules { modules = ( map ftpath deps' ); };

  # FIXME: peerDeps
  plock2nmFocus = plock2nmFocus' ["dependencies" "devDependencies"];

  plock2nm = plock:
    linkModules { modules = ( map ftpath plock.packages ); };

in {
  plockEntryFetchUnpack = ftpath;
  inherit plock2nmFocus' plock2nmFocus plock2nm;
}
