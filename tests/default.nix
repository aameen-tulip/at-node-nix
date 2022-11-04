# ============================================================================ #
#
# Provides sane defaults for running this set of tests.
# This is likely not the "ideal" way to utilize the test suite, but for someone
# who is consuming your project and knows nothing about it - this file should
# allow them to simply run `nix build -f .' to see if the test suite passes.
#
# ---------------------------------------------------------------------------- #

{ system      ? builtins.currentSystem
, at-node-nix ? builtins.getFlake ( toString ../. )
, pkgsFor     ? at-node-nix.legacyPackages.${system}
, lib         ? at-node-nix.lib
, writeText   ? pkgsFor.writeText
, rime        ? builtins.getFlake "github:aakropotkin/rime"

, flocoUnpack ? pkgsFor.flocoUnpack
, flocoConfig ? pkgsFor.flocoConfig
, flocoFetch  ? pkgsFor.flocoFetch

, keepFailed  ? false  # Useful if you run the test explicitly.
, doTrace     ? true   # We want this disabled for `nix flake check'
, limit       ? 100    # Limits the max dataset for certain tests.
                       # Generally subdirs raise their limit.
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  # Used to import test files.
  autoArgs = {
    inherit lib pkgsFor;

    inherit limit;

    inherit (pkgsFor)
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
    ;
    inherit flocoUnpack flocoConfig flocoFetch;
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
    ./libreg
    ./librange
    ./types
    # Derivations
    ./mkNmDir
    ./pkg-set
    ./build-support
    ./fpkgs
  ];

# ---------------------------------------------------------------------------- #

  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    purity = if lib.inPureEvalMode then "pure" else "impure";
    name = "at-node-nix tests (${system}, ${purity})";
  in lib.libdbg.mkTestHarness {
    inherit name keepFailed tests writeText;
    mkCheckerDrv = {
      __functionArgs  = lib.functionArgs lib.libdbg.mkCheckerDrv;
      __innerFunction = lib.libdbg.mkCheckerDrv;
      __processArgs   = self: args: self.__thunk // args;
      __thunk = { inherit name keepFailed writeText; };
      __functor = self: x: self.__innerFunction ( self.__processArgs self x );
    };
    checker = name: run: let
      rsl = lib.libdbg.checkerReport name run;
      msg = builtins.trace rsl null;
    in builtins.deepSeq msg rsl;
  };

in harness


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
