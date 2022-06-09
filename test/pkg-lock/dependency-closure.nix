{ lib  ? ( builtins.getFlake ( toString ../../. ) ).lib
, pkgs ? ( builtins.getFlake "nixpkgs" ).legacyPackages.${builtins.currentSystem}
, fetchurl ? pkgs.fetchurl
}:
let

  inherit (lib) libplock;
  biglock = lib.importJSON ./big-package-lock.json;
  smlock  = lib.importJSON ./small-package-lock.json;

in rec {

  env = { inherit lib pkgs fetchurl libplock biglock smlock; };

  run = lib.runTests {

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
