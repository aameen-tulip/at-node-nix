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
{ lib
, _mkNmDirCopyCmd
, _mkNmDirLinkCmd
, _mkNmDirAddBinNoDirsCmd
, mkNmDirCmdWith

, dev             ? true
, assumeHasBin    ? true
, skipUnsupported ? true

, flocoUnpack
, flocoConfig
, flocoFetch

, plock       ? lib.importJSON' "${lockDir}/package-lock.json"
, lockDir     ? null  # You better have set `flocoFetch' basedir.

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
    else lib.mkFlocoFetcher { basedir = lockDir; inherit flocoConfig; };

  doFetch = pkey: plent: let
    hasBin = ( plent.bin or {} ) != {};
    bin' = lib.optionalAttrs hasBin { inherit (plent) bin; };
    fetched = flocoFetch plent;
    core = {
      meta.needsUnpack   = fetched.needsUnpack or false;
      meta.hasBin        = hasBin;
      meta.entries.plent = plent;
      passthru.fetched   = fetched;
    } // bin';
    forNeedsUnpack = let
      unpacked = flocoUnpack { meta = core; tarball = fetched; };
    in lib.recursiveUpdate core {
      outPath         = unpacked.outPath;
      passthru.source = unpacked;
    };
    forUnpacked = lib.recursiveUpdate core {
      outPath         = fetched.outPath;
      passthru.source = fetched;
    };
  in if core.meta.needsUnpack then forNeedsUnpack else forUnpacked;
  keyed = lib.callPackageWith args lib.idealTreePlockV3 {
    inherit npmSys plock skipUnsupported dev;
  };
  keeps = builtins.intersectAttrs keyed plock.packages;
in builtins.mapAttrs doFetch keeps
