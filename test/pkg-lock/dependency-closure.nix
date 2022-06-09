{ lib  ? ( builtins.getFlake ( toString ../../. ) ).lib
, pkgs ? ( builtins.getFlake "nixpkgs" ).legacyPackages.${builtins.currentSystem}
, fetchurl ? pkgs.fetchurl
}:
let

  inherit (lib) libplock;

  biglock = lib.importJSON ./big-package-lock.json;
  smlock  = lib.importJSON ./small-package-lock.json;

  resolvedDep = {
    name = "@jest/schemas";
    value = {
      version = "28.0.2";
      resolved = "https://registry.npmjs.org/@jest/schemas/-/schemas-28.0.2.tgz";
      integrity = "sha512-YVDJZjd4izeTDkij00vHHAymNXQ6WWsdChFRK86qck6Jpr3DCL5W3Is3vslviRlP+bLuMYRLbdp98amMvqudhA==";
    };
  };

  githubDep = {
    name = "lodash";
    value = {
      version = "git+https://github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c";
      from = "git+https://github.com/lodash/lodash.git";
    };
  };


in rec {

  env = {
    inherit lib pkgs fetchurl libplock biglock smlock;
    inherit resolvedDep githubDep;
  };

/* -------------------------------------------------------------------------- */

  # Run tests and a return a list of failed cases.
  # Do not throw/report errors yet.
  # Use this to compare the `expected' and `actual' contents.
  run = lib.runTests {

    testWasResolved = lib.testAllTrue [
      ( libplock.wasResolved resolvedDep.name resolvedDep.value )
      ( ! ( libplock.wasResolved githubDep.name githubDep.value ) )
      ( ! ( libplock.wasResolved "fake" {} ) )
    ];

    testPartitionResolvedSmall = {
      expr = libplock.partitionResolved smlock;
      expected = import ./expected-partition-res-small.nix;
    };

    testGenFetchersSmall = {
      expr = let
        fetchers = libplock.resolvedFetchersFromLock fetchurl smlock;
      in builtins.all lib.isDerivation ( builtins.attrValues fetchers );
      expected = true;
    };

  };


/* -------------------------------------------------------------------------- */

  # Runs tests with tracing, ends in an assertion.
  # This is set to this file's `__functor', so it /should/ get run by default
  # if evaluated from the CLI:  `nix build -f ./dependency-closure.nix'
  check = let

    report = { name, expected, result }: let
      msg = ''
        Test ${name} Failure: Expectation did not match result.
          expected: ${builtins.toJSON expected}
          result:   ${builtins.toJSON result}
      '';
    in builtins.trace msg false;

    ck = map ( t: ( t.result == t.expected ) || ( report t ) ) run;

  in assert ( builtins.deepSeq ck ck ) == [];
    builtins.trace "PASS" ( ck == [] );

} // { __functor = self: self.check; }
