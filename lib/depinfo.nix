# FIXME: this is a draft to be merged into `depInfo' normalization.
{ lib }: let
  depInfos = plock: assert lib.libplock.supportsPlockV3; let
    pinned  = lib.libplock.pinVersionsFromPlockV3 plock;
    pFields = {
      dependencies         = true;
      devDependencies      = true;
      optionalDependencies = true;
      requires             = true;
    };
    dFields = pFields // {
      peerDependencies     = true;
      peerDependenciesMeta = true;
      bundledDependencies  = true;
      bundleDependencies   = true;
    };
    diOne = _: ent: {
      depInfo = {
        descriptors = let
          fs = builtins.intersectAttrs dFields ent;
          hasBund = fs ? bundledDependencies || fs ? bundleDependencies;
          bundled = lib.optionalAttrs hasBund {
            bundledDependencies = ( fs.bundledDependencies // {} ) //
                                  ( fs.bundleDependencies // {} );
          };
        in ( removeAttrs fs ["bundleDependencies"] ) // bundled;
        pins = builtins.intersectAttrs pFields ent;
      };
    };
  in builtins.mapAttrs diOne pinned.packages;
in depInfos
