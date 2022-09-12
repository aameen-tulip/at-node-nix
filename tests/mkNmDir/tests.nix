# ============================================================================ #
#
# General tests for `mkNmDir' routines.
#
# ---------------------------------------------------------------------------- #

{ lib
, _mkNmDirCopyCmd
, _mkNmDirLinkCmd
, _mkNmDirAddBinWithDirCmd
, _mkNmDirAddBinNoDirsCmd
, _mkNmDirAddBinCmd
, mkNmDirCmdWith
, mkNmDirCopyCmd
, mkNmDirLinkCmd
, ...
} @ globalArgs: let

# ---------------------------------------------------------------------------- #

  dataDir = toString ../libfetch/data;
  lockDir = "${dataDir}/proj2";
  plock   = lib.importJSON' "${lockDir}/package-lock.json";
  metaSet = lib.metaSetFromPlockV3 { inherit lockDir; };
  # FIXME: These end up being identical.
  treeD   = lib.idealTreePlockV3 { inherit lockDir; };
  treeP   = lib.idealTreePlockV3 { inherit lockDir; dev = false; };
  msTreeD = builtins.mapAttrs ( p: key: flocoFetch metaSet.${key} ) treeD;
  msTreeP = builtins.mapAttrs ( p: key: flocoFetch metaSet.${key} ) treeP;

  flocoConfig   = lib.mkFlocoConfig {};
  flocoFetch    = lib.mkFlocoFetcher {};
  flocoFetchCwd = lib.mkFlocoFetcher { cwd = lockDir; };

  sourceTree = builtins.mapAttrs ( p: flocoFetchCwd ) plock.packages;

  plockBig = lib.importJSON' ( toString ../libplock/data/plv2-it.json );

  tests = {

    testAllBindirs = {
      expr = let
        gnm = path: _: let
          m = lib.yank "(.*node_modules)/.*" path;
        in if ( m == null ) || ( m == "node_modules" )
           then "$node_modules_path"
           else "$node_modules_path/${lib.yank "node_modules/(.*)" m}";
      in lib.unique ( lib.mapAttrsToList gnm plockBig.packages );
      expected = [
        "$node_modules_path"
        "$node_modules_path/pretty-format/node_modules"
      ];
    };

    testLinkFromPlTree = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };

    testCopyFromPlTree = {
      expr = builtins.isString ( mkNmDirCopyCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };

    # Make sure no paths outside of `$node_modules_path' are touched.
    # This specifically deals with symlinked projects that are outside of a
    # projects filesystem "subtree".
    testNoOutOfTreePaths = {
      expr = let
        nmd = mkNmDirCopyCmd { tree = sourceTree; };
        isSub = p: ! ( lib.hasPrefix ".." p );
      in builtins.all isSub ( builtins.attrNames nmd.passthru.tree );
      expected = true;
    };

    testLinkFromMS = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };

    testCopyFromMS = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };

    testLinkFromITP = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = msTreeP; } ).cmd;
      expected = true;
    };

    testCopyFromITP = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = msTreeP; } ).cmd;
      expected = true;
    };

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
