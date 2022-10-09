# ============================================================================ #
#
# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build -f .' to see if the test suite passes.
#
# ---------------------------------------------------------------------------- #

{ nixpkgs     ? builtins.getFlake "nixpkgs"
, system      ? builtins.currentSystem
, pkgsFor     ? nixpkgs.legacyPackages.${system}
, writeText   ? pkgsFor.writeText
, rime        ? builtins.getFlake "github:aakropotkin/rime"
, lib         ? import ../lib { inherit (rime) lib; }
, annPkgs     ? ( builtins.getFlake ( toString ../. ) ).legacyPackages.${system}

, flocoUnpack ? annPkgs.flocoUnpack
, flocoConfig ? annPkgs.flocoConfig
, flocoFetch  ? annPkgs.flocoFetch

, keepFailed  ? false  # Useful if you run the test explicitly.
, doTrace     ? true   # We want this disabled for `nix flake check'
, limit       ? 100    # Limits the max dataset for certain tests.
                       # Generally subdirs raise their limit.
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  # Used to import test files.
  autoArgs = {
    inherit lib;

    inherit limit;

    inherit (annPkgs)
      _mkNmDirCopyCmd
      _mkNmDirLinkCmd
      _mkNmDirAddBinWithDirCmd
      _mkNmDirAddBinNoDirsCmd
      _mkNmDirAddBinCmd
      mkNmDirCmdWith
      mkNmDirCopyCmd
      mkNmDirLinkCmd

      mkSourceTree
      mkSourceTreeDrv
      mkTarballFromLocal

      # FIXME
      _node-pkg-set
    ;
    inherit flocoUnpack flocoConfig flocoFetch;
    pkgsFor = annPkgs;
  } // args;

  tests = let
    testsFrom = file: let
      fn    = import file;
      fargs = builtins.functionArgs fn;
      ts    = fn ( builtins.intersectAttrs fargs autoArgs );
    in assert builtins.isAttrs ts;
       ts.tests or ts;
  in builtins.foldl' ( ts: file: ts // ( testsFrom file ) ) {} [
    ./libpkginfo
    ./libplock
    ./libfetch
    ./libsys
    ./libdep
    ./mkNmDir
    ./pkg-set
    ./libreg
    ./librange
    ./types
  ];

# ---------------------------------------------------------------------------- #

  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    name = "all-tests";
  in lib.libdbg.mkTestHarness {
    inherit name keepFailed tests writeText;
    mkCheckerDrv = args: lib.libdbg.mkCheckerDrv {
      inherit name keepFailed writeText;
      check = lib.libdbg.checkerReport name harness.run;
    };
    checker = name: run: let
      msg = lib.libdbg.checkerMsg name run;
      rsl = lib.libdbg.checkerDefault name run;
    in if doTrace then builtins.trace msg rsl else rsl;
  };


# ---------------------------------------------------------------------------- #

in harness


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
