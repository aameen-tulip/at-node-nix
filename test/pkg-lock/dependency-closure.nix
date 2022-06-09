
/**
 * `libplock' tests related to dependency closures.
 * Run from the CLI with `nix build -f ./dependency-closure.nix', or
 * in the REPL with `run' and `check' commands.
 * In the REPL you also have access to the `env' attrset which stashes various
 * test inputs for easy access.
 */

{ lib       ? ( builtins.getFlake ( toString ../../. ) ).lib
, pkgs      ? ( builtins.getFlake "nixpkgs" ).legacyPackages.${builtins.currentSystem}
, fetchurl  ? pkgs.fetchurl
, writeText ? pkgs.writeText
}:

let

  inherit (lib) libplock;

  biglock = lib.importJSON ./data/big-package-lock.json;
  smlock  = lib.importJSON ./data/small-package-lock.json;

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
      expected = import ./data/expected-partition-res-small.nix;
    };

    testGenFetchersSmall = {
      expr = let fetchers = libplock.resolvedFetchersFromLock fetchurl smlock;
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
      coerceString = x: let
        inherit (builtins) toJSON mapAttrs isFunction isAttrs trace typeOf;
        coerceAs = as:
          toJSON ( mapAttrs ( _: v: coerceString v ) as );
      in if ( lib.strings.isCoercibleToString x ) then ( toString x ) else
         if ( isFunction x ) then "<LAMBDA>" else
         if ( isAttrs x ) then ( coerceAs x ) else
             ( trace "Unable to stringify type ${typeOf x}" "<?>" );

      msg = ''
        Test ${name} Failure: Expectation did not match result.
          expected: ${coerceString expected}
          result:   ${coerceString result}
      '';
    in builtins.trace msg false;

    ck = map ( t: ( t.result == t.expected ) || ( report t ) ) run;

  in assert ( builtins.deepSeq ck ck ) == [];
    builtins.trace "PASS" ( ck == [] );

  checkDrv = writeText "test.log" ( builtins.deepSeq check "PASS" );

} // { __functor = self: self.checkDrv; }
