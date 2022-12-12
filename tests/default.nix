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

, flocoUnpack  ? pkgsFor.flocoUnpack
, flocoFetch   ? lib.mkFlocoFetcher { inherit ifd pure allowedPaths typecheck; }
, ifd          ? ( builtins.currentSystem or null ) == system
, pure         ? lib.inPureEvalMode
, allowedPaths ? []
, typecheck    ? true

, flocoScrape ? at-node-nix.flocoScrape  # Only usable in impure with IFD

, keepFailed  ? false  # Useful if you run the test explicitly.
, doTrace     ? true   # We want this disabled for `nix flake check'
, limit       ? 100    # Limits the max dataset for certain tests.
                       # Generally subdirs raise their limit.
, ...
} @ args: let

# ---------------------------------------------------------------------------- #

  # Used to import test files.
  auto = let
    flocoScrape' = if pure || ( ! ifd ) then {} else { inherit flocoScrape; };
  in {
    inherit lib pkgsFor;

    inherit limit;

    inherit (pkgsFor)
      mkNmDirCmdWith mkNmDirCopyCmd mkNmDirLinkCmd
      mkTarballFromLocal
      snapDerivation
    ;
    inherit
      flocoUnpack
      flocoFetch
      ifd
      pure
      typecheck
      allowedPaths
    ;
  } // args // flocoScrape';

  tests = let
    testsFrom = file: let
      fn    = import file;
      fargs = builtins.functionArgs fn;
      ts    = fn ( builtins.intersectAttrs fargs auto );
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
    ./libtree
    ./libevent
    # Derivations
    ./mkNmDir
    ./pkg-set
    ./build-support
    ./fpkgs
    ./scrapePlock.nix
  ];

# ---------------------------------------------------------------------------- #

  # We need `check' and `checkerDrv' to use different `checker' functions which
  # is why we have explicitly provided an alternative `check' as a part
  # of `mkCheckerDrv'.
  harness = let
    purity = if lib.inPureEvalMode then "pure" else "impure";
    name = "at-node-nix tests ${system} ${purity}";
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
