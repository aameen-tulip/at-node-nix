# ============================================================================ #
#
# General tests for `mkNmDir' routines.
#
# ---------------------------------------------------------------------------- #

{ lib
, pkgsFor
, ...
} @ globalArgs: let

# ---------------------------------------------------------------------------- #

  inherit (pkgsFor)
    mkNmDirCmdWith
    mkNmDirCopyCmd
    mkNmDirLinkCmd
  ;

# ---------------------------------------------------------------------------- #

  dataDir = toString ../libfetch/data;
  lockDir = toString ../libfetch/data/proj2;
  plock = lib.importJSON' ( toString ../libfetch/data/proj2/package-lock.json );
  metaSet = lib.metaSetFromPlockV3 { inherit lockDir; };

  plockBig = lib.importJSON' ( toString ../libplock/data/plv2-it.json );

  # FIXME: These end up being identical.
  treeD = lib.idealTreePlockV3 { inherit lockDir; };
  treeP = lib.idealTreePlockV3 { inherit lockDir; dev = false; };

  msTreeD = builtins.mapAttrs ( pkey: key: flocoFetch metaSet.${key} ) treeD;
  msTreeP = builtins.mapAttrs ( pkey: key: flocoFetch metaSet.${key} ) treeP;


# ---------------------------------------------------------------------------- #

  flocoFetchCwd = lib.mkFlocoFetcher { basedir = lockDir; };
  flocoFetch    = lib.mkFlocoFetcher {};


# ---------------------------------------------------------------------------- #

  # Fetches directly from lockfile, pushing down `pkey' to allow `dir'/`link'
  # entries to be fetched.
  sourceTree = let
    doFetch = pkey: plent:
      pkgsFor.coerceUnpacked' { flocoFetch = flocoFetchCwd; }
                              ( { resolved = pkey; } // plent );
  in builtins.mapAttrs doFetch plock.packages;


# ---------------------------------------------------------------------------- #

  tests = {

    inherit plock metaSet treeD msTreeD flocoFetchCwd sourceTree;

# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

    testLinkFromPlTree = {
      expr = builtins.isString ( mkNmDirLinkCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };

    testCopyFromPlTree = {
      expr = builtins.isString ( mkNmDirCopyCmd { tree = sourceTree; } ).cmd;
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    # Make sure no paths outside of `$node_modules_path' are touched.
    # This specifically deals with symlinked projects that are outside of a
    # projects filesystem "subtree".
    testNoOutOfTreePaths = {
      expr = let
        nmd = mkNmDirCopyCmd { tree = sourceTree; };
        isSub = p: ! ( lib.hasPrefix ".." p );
      in builtins.all isSub ( builtins.attrNames nmd.passthru.subtree );
      expected = true;
    };


# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

    # These are checked in `libfetch' already, but these two test cases were
    # added here as well for visibility.
    # If `libfetch' is being edited we want breaking changes to `resolved'
    # fallbacks to be noticed in relation to `mkNmDirCmd' as well.
    testPlRootIsDir = {
      expr     = sourceTree."".ltype;
      expected = "dir";
    };

    testPlDotsIsLink = {
      expr     = sourceTree."node_modules/projd".ltype;
      expected = "link";
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
