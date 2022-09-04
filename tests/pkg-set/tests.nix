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
    installPkgEnt
    mkNmDirLinkCmd
    mkNmDirPlockV3
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

    # Run a simple build that just creates a file `greeting.txt' with `echo'.
    testBuildPkgEntSimple = let
      # The `pkgEnt' for the lock we've parsed.
      rootEnt  = mkPkgEntSource metaSet.${metaSet.__meta.rootKey};
      # Get our ideal tree, filtering out packages that are incompatible with
      # out system.
      tree = lib.idealTreePlockV3 {
        inherit metaSet;
        dev    = true;
        npmSys = lib.getNpmSys { inherit system; };
      };
      # Using the filtered tree, pull contents from our package set.
      # We are just going to install our deps as raw sources here.
      srcTree =
        builtins.mapAttrs ( _: key: mkPkgEntSource metaSet.${key} ) tree;
      # Run the build routine for the root package.
      built = buildPkgEnt ( rootEnt // {
        nmDirCmd = pkgsFor.callPackage mkNmDirLinkCmd {
          tree         = srcTree;
          handleBindir = false;
          # Helps sanity check that our modules were installed.
          postNmDir    = "ls $node_modules_path/../**;";
        };
      } );
    in {
      # Make sure that the file `greeting.txt' was created.
      # Also check that our `node_modules/' were installed to the expected path.
      expr = builtins.all builtins.pathExists [
       "${built}/greeting.txt"
       # Prevent `node_modules/' from being deleted during the install phase
       # so they get added to the output path.
       "${built.override { preInstall = ":"; }}/node_modules/chalk/package.json"
      ];
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    # Run a simple install that just creates a file `farewell.txt' with `echo'.
    testInstallPkgEntSimple = let
      # The `pkgEnt' for the lock we've parsed.
      rootEnt  = mkPkgEntSource metaSet.${metaSet.__meta.rootKey};
      # Get our ideal tree, filtering out packages that are incompatible with
      # out system.
      tree = lib.idealTreePlockV3 {
        inherit metaSet;
        dev    = false;
        npmSys = lib.getNpmSys { inherit system; };
      };
      # Using the filtered tree, pull contents from our package set.
      # We are just going to install our deps as raw sources here.
      srcTree =
        builtins.mapAttrs ( _: key: mkPkgEntSource metaSet.${key} ) tree;
      # Run the build routine for the root package.
      installed = installPkgEnt ( rootEnt // {
        nmDirCmd = pkgsFor.callPackage mkNmDirLinkCmd {
          tree         = srcTree;
          handleBindir = false;
          # Helps sanity check that our modules were installed.
          postNmDir    = "ls $node_modules_path/../**;";
        };
      } );
      keepNm = installed.override { preInstall = ":"; };
    in {
      inherit installed keepNm;
      # Make sure that the file `greeting.txt' was created.
      # Also check that our `node_modules/' were installed to the expected path.
      expr = builtins.all builtins.pathExists [
       "${installed}/farewell.txt"
       # Prevent `node_modules/' from being deleted during the install phase
       # so they get added to the output path.
       "${keepNm}/node_modules/memfs/package.json"
      ];
      expected = true;
    };


# ---------------------------------------------------------------------------- #

    # This is the "magic" `package-lock.json(v2/3)' -> `node_modules/' builder.
    # It's built on top of lower level functions that allow for fine grained
    # control of how the directory tree is built, what inputs are used, etc;
    # but this form is your "grab a `node_modules/' dir off the shelf" routine
    # that tries to do the right thing for a `package-lock.json(v2/3)'.
    _testMkNmDirPkgSetPlV3 = let
      nmDirCmd = mkNmDirPlockV3 { inherit metaSet; };
    in {
      inherit nmDirCmd metaSet;
      expr     = builtins.isString "${nmDirCmd}";
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
