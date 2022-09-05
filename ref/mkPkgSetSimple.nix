# ============================================================================ #
#
# A simple build pipeline to build a `package-lock.json(v2/3)' project.
# This is limited insofar as it doesn't pass an `nmDirCmd' to non-root builders.
#
# I have dealt with this in most projects by manually writing a small snippet
# to drop in any directoryies I actually need; honestly the vast majority of
# `installScript' run fine without modules as long as you provide `node-gyp',
# ocassionally the "NaN" module, and those that don't take only a few minutes
# to whip up a tree for using:
#
#   nmDirCmd = mkNmDir {
#     # Use something from the package set.
#     tree."node_modules/foo" = pkgSet."foo/1.0.0";
#     # Use a local path
#     tree."node_modules/bar" = flocoFetch { type = "path"; path = "./bar"; };
#     # Use a `flocoPackage' output from a flake. ( just an arbitrary field )
#     tree."node_modules/baz" = ( builtins.getFlake "baz" ).flocoPackages.baz;
#     ...
#   };
#
# I am going to whip up some extensions to `libtree' soon to make this automatic
# but for now that's the way it works.
#
# If you have a package with a large number of deps, make a lock:
#   NPM_CONFIG_LOCKFILE_VERSION=2 npm i @foo/bar--package-lock-only;
#   jq '.packages[""]' > ./package.json;
#
#
# ---------------------------------------------------------------------------- #


# If you made `final' an arg here at the top, and drop `let' in the body,
# you have an overlay that you can compose with other package sets.
#
# If you just want a recursive attrset then take this as it is.
#
# If reading this just helped you understand what an overlay is: High Five!

{ lib
, lockDir
, flocoConfig

, pkgsFor
, mkPkgEntSource
, mkNmDirPlockV3
, runCommandNoCC
, buildPkgEnt
, installPkgEnt

, nodejs  ? pkgsFor.nodejs-14_x
} @ prev: let

  final = prev // {

    callPackageWith  = autoArgs: pkgsFor.callPackageWith ( final // autoArgs );
    callPackagesWith = autoArgs: pkgsFor.callPackagesWith ( final // autoArgs );
    callPackage      = final.callPackageWith {};
    callPackages     = final.callPackagesWith {};

    metaSet = lib.libmeta.metaSetFromPlockV3 { inherit lockDir; };
    mkNmDir = mkNmDirPlockV3 {
      # Packages will be pulled from here when their "key" ( "<IDENT>/<VERSION>" )
      # matches an attribute in the set.
      inherit (final) pkgSet;
      # Default settings. These are wiped out if you pass args again.
      copy = false;  # Symlink
      dev  = true;   # Include dev modules
    };

    # FIXME: handle subtrees
    doNmDir = { hasBuild, hasInstallScript, hasTest, ... } @ pkgEnt: let
    in pkgEnt // ( lib.optionalAttrs needsNm {
      inherit (final) mkNmDir;
    } );

    doBuild = { hasBuild } @ pkgEnt:
      pkgEnt // ( lib.optionalAttrs hasBuild {
        built   = final.buildPkgEnt pkgEnt;
        outPath = build'.built.outPath;
      } );

    doInstall = { hasInstallScript, ... } @ pkgEnt:
      pkgEnt // ( lib.optionalAttrs hasInstallScript {
        installed = final.installPkgEnt pkgEnt;
        outPath   = installed'.installed.outPath;
      } );

    doTest = { hasTest ? false, ... } @ pkgEnt:
      pkgEnt // ( lib.optionalAttrs hasTest {
        test = final.testPkgEnt pkgEnt;
      } );

    mkPkgEnt = path: {
      hasBuild
    , hasInstallScript
    , hasBin
    , hasTest ? false
    , ...
    } @ metaEnt: let
      simple = ! ( hasBuild || hasInstallScript || hasBin || hasTest );
      base   = ( mkPkgEntSource metaEnt ) // {
        # Add phony `mkNmDir' as a stub for non-root pkgs.
        #
        # FIXME: you can reuse the root's `node_modules/' dir until you have a
        # smarted solution here.
        # What you'll need to do is use `mkNmDir' to dump trees, and then `cd'
        # to the relevant project to run the build.
        # This is a PITA though because you have to manually arrange the build
        # order or toposort or something.
        #
        # Previously I was writing the ~7-10 packages that actually needed
        # installs to run by hand, honestly they run fine with just NaN in most
        # cases; but if people want "run in any project" then there's no way
        # around sitting down to write a routine to pull-down subtrees from
        # parent dirs to "refocus" a lock.
        mkNmDir = if path == "" then final.mkNmDir else ":";
      };
      done   = ( doTest ( doInstall ( doBuild ( doNmDir base ) ) ) );
    in if simple then base else done;

    pkgSet = builtins.mapAttrs mkPkgEnt metaSet.__entries;

  };

in final
