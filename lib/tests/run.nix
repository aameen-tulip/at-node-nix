# Runs your tests, and returns a list of tests cases that failed.
# A failed test is one where the evaluated `expr' does not `== expected'.
# Failed tests are listed as attrsets with the original `expected' and `result'
# fields plus `result'.
#   Ex:  [{ expected = 2; result = 3; name = "testFoo"; }]
#
# I have made `runner' an argument here in several of my own test dirs
# which default to `lib.runTests' ( refering to the Nixpkgs implementation ).
# However in these templates I have opted to leave the `tests.nix' file to be
# as simple as possible so that it may be processed by a variety of more
# specialized harnesses.
#
# I strongly recommend checking out `nixpkgs/lib/debug.nix' to find additional
# test driving helpers.
# In `libdbg' I have provided a rudimentary tracer named `report' which is a
# significantly stripped down form of `nixpkgs.lib.debug.trace*' routines.
# You may find that this file is a useful opportunity to trace your test case.
# When doing so I recommend using `builtins.trace' or extensions of it which
# print to `stderr' and return their arguments without any modifications - this
# becomes useful when we want to deactivate traces ( see below ).
#
# I have added the argument `enableTraces' which is left up to YOU to enforce -
# the rationale here is that this test runner may be used in `flake.nix' or a
# CI system like Hydra, where a flood of traces to `stderr' could be obnoxious.
# I have provided an alias for `report' here which is an example of how to
# enforce the `enableTraces' flag.
args @ { lib, enableTraces ? true, ... }: let
  inputs = args // { inherit lib; };
  tests  = import ./tests.nix inputs;
  result = lib.runTests tests;

  # You can handle `enableTraces' in a few ways, the option below is nice for
  # complex conditionals/runners.
  # This effectively makes `report' a no-op when `enableTraces == false'.
  ## report = if enableTraces then lib.libdbg.report else ( x: x );

  # However if you're using "pure" `trace' functions ( such as `report' ) that
  # don't modify their inputs, a simple conditional like this is slightly
  # more performant:
  inherit (lib.libdbg) report;
in if enableTraces then ( map report result ) else result
