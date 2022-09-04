# ============================================================================ #
#
# General tests for builders.
#
#
# ---------------------------------------------------------------------------- #

{ lib
, system
, flocoConfig
, flocoFetch
, flocoUnpack
, pkgsFor
}: let

# ---------------------------------------------------------------------------- #

  inherit (pkgsFor)
    mkPkgEntSource
    buildPkgEnt
    mkNmDirLinkCmd
  ;

# ---------------------------------------------------------------------------- #

  lockDir = toString ./data;
  metaSet = lib.libmeta.metaSetFromPlockV3 { inherit lockDir; };

  # An arbitrary tarball to fetch.
  # We know this one doesn't have the directory permissions issue.
  tsMeta    = metaSet."typescript/4.7.4";
  fetchedTs = flocoFetch tsMeta;


# ---------------------------------------------------------------------------- #

  tests = {

    inherit lockDir metaSet;

# ---------------------------------------------------------------------------- #

    testMkPkgEntSource = let
      pkgEnt   = mkPkgEntSource tsMeta;
      srcFiles = builtins.readDir pkgEnt.source.outPath;
    in {
      expr = {
        srcValid = ( builtins.tryEval srcFiles ) ? success;
        tbValid  = pkgEnt ? tarball.outPath;
      };
      expected = {
        srcValid = true;
        tbValid  = true;
      };
    };


# ---------------------------------------------------------------------------- #

    testBuildPkgEntSimple = let
      pkgSet   = builtins.mapAttrs ( _: mkPkgEntSource ) metaSet.__entries;
      rootEnt  = pkgSet.${metaSet.__meta.rootKey};
      tree = lib.idealTreePlockV3 {
        inherit metaSet;
        dev    = true;
        npmSys = lib.getNpmSys { inherit system; };
      };
      srcTree =
        builtins.mapAttrs ( _: key: mkPkgEntSource metaSet.${key} ) tree;
      built = buildPkgEnt ( rootEnt // {
        nmDirCmd = pkgsFor.callPackage mkNmDirLinkCmd {
          tree         = srcTree;
          handleBindir = false;
          postNmDir    = "ls $node_modules_path/../**;";
        };
        src = rootEnt.source;
      } );
    in {
      expr = builtins.all builtins.pathExists [
       "${built}/greeting.txt"
       # Prevent `node_modules/' from being deleted so they get output.
       "${built.override { preInstall = ":"; }}/node_modules/chalk/package.json"
      ];
      expected = true;
    };


# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
