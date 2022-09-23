{ lib
, nodejs
, bash

, rootKey ? metaSet.__meta.rootKey
, metaEnt ? metaSet.${rootKey}
, metaSet ? {
    inherit metaEnt;
    __meta.rootKey  = metaEnt.key;
    __meta.fromType = metaEnt.fromType;
  } // ( lib.optionalAttrs ( metaEnt ? trees ) { inherit (metaEnt) trees; } )
, keyTree ? metaEnt.trees.prod or metaSet.__meta.trees.prod
, fromType ? metaSet.__meta.fromType or metaEnt.entFromType

, tree ? FIXME

, mkNmDirCopyCmd
, mkNmDirCmd ? mkNmDirLinkCmd
, nmDirCmd ? mkNmDirCmd {
    inherit tree;
    ignoreSubBins = lib.metaWasPlock (
  }
}:
