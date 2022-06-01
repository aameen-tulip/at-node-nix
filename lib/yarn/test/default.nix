{ yarnParse   ? import ../parse.nix
, yarnSupport ? import ../../../pkgs/build-support/yarn-lock.nix {}
, parseTests  ? import ./parse.nix { inherit yarnParse yarnSupport; }
}:
let
  runTestSet = ts:
    builtins.all ( t: builtins.deepSeq t t ) ( builtins.attrValues ts );
  allTests = {
    parseTests = runTestSet parseTests;
  };
in {
  pass = runTestSet allTests;
}
