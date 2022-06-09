{ lib ? ( builtins.getFlake ( toString ../../. ) ).lib }:
let

  inherit (lib) libplock;
  biglock = lib.importJSON ./big-package-lock.json;
  smlock  = lib.importJSON ./small-package-lock.json;

in rec {

  testPartitionResolvedSmall = {
    expr = libplock.partitionResolved smlock;
    expected = import ./expected-partition-res-small.nix;
  };

  run = lib.runTests {
    inherit testPartitionResolvedSmall;
  };

  check = map ( t: t.result == t.expected ) run;

}
