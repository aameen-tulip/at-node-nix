# From a `package-lock.json' produce a tree ( compatible with `libtree' ) which
# has `outPath' values for each path.
# NOTE: This produces a single derivation for each entry - not one big drv.
#
# This will use `flocoFetch' and `flocoUnpack' to pick fetchers and ( possibly )
# run a second phase for unpacking ( this generally only applies to pure mode ).
#
# NOTE: if you are looking for a `node_modules/' dir builder, you want
# `mkNmDirCmd'; BUT you can pass this source tree to those functions to get
# a node modules dir.
#
# There are a number of inputs the `mkNmDirCmd' routines accept, and this one
# is the farthest separated from the `(meta|pkg)Set' patterns.
# If you just want "get me my sources and no other non-sense", this routine is
# for you.
#
#
# mkSourceTree { lockDir }
#   or
# mkSourceTree { plock, flocoFetch }  *** set basedir in `flocoFetch' or set
#                                         absolute paths as keys first.
#
# See `<at-node-nix>/tests/mkNmDir/tests.nix' for real examples.
#
# XXX: I have no idea if this actually still works since new `pkgEnt' and
# `coreceUnpacked'' routines were adopted.
{ lib
, mkNmDirCmdWith

, dev             ? true
, assumeHasBin    ? true
, skipUnsupported ? true

, flocoUnpack
, flocoFetch
, coerceUnpacked'

, plock   ? lib.importJSON' ( lockDir + "/package-lock.json" )
, lockDir ? null  # You better have set `flocoFetch' basedir.

, npmSys ? lib.getNpmSys args
# These are used by the `getNpmSys' fallback and must be declared for
# `callPackage' and `functionArgs' to work - see `lib/system.nix' for more
# more details. PREFER: `system' and `hostPlatform'.
, system ? null, hostPlatform ? null, buildPlatform ? null
, cpu ? null, os ? null, enableImpureMeta ? null, stdenv ? null
} @ args:
  assert ( args.lockDir or args.flocoFetch or null ) != null; let
  flocoFetch =
    if ! ( args ? lockDir ) then args.flocoFetch
    else args.flocoFetch // {
      pathFetcher = args.flocoFetch.pathFetcher // {
        __thunk = args.flocoFetch.pathFetcher.__thunk // { basedir = lockDir; };
      };
    };
  keyed = lib.callPackageWith args lib.idealTreePlockV3 {
    inherit npmSys plock skipUnsupported dev;
  };
  keeps = builtins.intersectAttrs keyed plock.packages;
  doFetch = pkey: plent: let
    doUnpack = coerceUnpacked' { inherit flocoFetch flocoUnpack; };
  in doUnpack { fetched = flocoFetch ( plent // { path = pkey; } ); };
in builtins.mapAttrs doFetch keeps
