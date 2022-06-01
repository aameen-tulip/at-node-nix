{ yarnParse   ? import ../parse.nix
, yarnSupport ? import ../../../pkgs/build-support/yarn-lock.nix {}
}:
let

  ylock = yarnSupport.readYarnLock ../../../test/yarn/lock/yarn-big.lock;

  bts = b: if b then "true" else "false";


/* -------------------------------------------------------------------------- */

  readDescriptors = deleteCommas:
    let
      raw = builtins.attrNames ylock;
      hasComma = s: ( builtins.match ".*, .*" s ) != null;
      parted = builtins.partition hasComma raw;
      sep = s: builtins.filter builtins.isString ( builtins.split ", " s );
      fixed = builtins.concatMap sep parted.right;
      rslCommas = parted.wrong ++ fixed;
      rslDel = builtins.filter ( s: ! ( hasComma s ) ) raw;
    in if deleteCommas then rslDel else rslCommas;
  descriptors = readDescriptors false;

  sampleSize = 500;

  dsample = let dlen = builtins.length descriptors;
                n    = if dlen < sampleSize then dlen else sampleSize;
    in builtins.genList ( builtins.elemAt descriptors ) n;


/* -------------------------------------------------------------------------- */

  idents =
    let
      merge    = a: b: a // b.dependencies;
      entries  = builtins.attrValues ylock;
      entries' = builtins.filter ( x: x ? dependencies ) entries;
      allDeps  = builtins.foldl' merge {} entries';
    in builtins.attrNames allDeps;

  isample = let ilen = builtins.length idents;
                n = if ilen < sampleSize then ilen else sampleSize;
            in builtins.genList ( builtins.elemAt idents ) n;


/* -------------------------------------------------------------------------- */

  locators = map ( x: x.resolution ) ( builtins.attrValues ylock );

  lsample = let llen = builtins.length locators;
                n = if llen < sampleSize then llen else sampleSize;
            in builtins.genList ( builtins.elemAt locators ) n;

in {

/* -------------------------------------------------------------------------- */

  testParseDescSimple =
    let
      d = "@smoke/midz@npm:~4.2.0";
      rsl = yarnParse.parseDescriptor d;
      expected =
        { descriptor = "npm:~4.2.0"; pname = "midz"; scope = "smoke"; };
      check = let pass = expected == rsl; in
              builtins.trace "parseDescriptor \"${d}\" ==> ${bts pass}" pass;
    in check;

  testParseDesc =
    let check = d: let rsl = yarnParse.parseDescriptor d;
                   in builtins.trace "trying: parseDescriptor \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;

  testParseDescStrict =
    let check = d:
          let rsl = yarnParse.parseDescriptorStrict d;
          in builtins.trace "trying: parseDescriptorStrict \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;


/* -------------------------------------------------------------------------- */

  testParseIdent =
    let check = d: let rsl = yarnParse.parseIdent d;
                   in builtins.trace "trying: parseIdent \"${d}\"" rsl;
    in builtins.deepSeq ( map check isample ) true;


/* -------------------------------------------------------------------------- */

  testParseLocatorSimple =
    let
      d = "@smoke/midz@npm:4.2.0";
      rsl = yarnParse.parseLocator d;
      expected = { reference = "npm:4.2.0"; pname = "midz"; scope = "smoke"; };
      check = let pass = expected == rsl; in
              builtins.trace "parseLocator \"${d}\" ==> ${bts pass}" pass;
    in check;

  testParseLocator =
    let check = d: let rsl = yarnParse.parseLocator d;
                   in builtins.trace "trying: parseLocator \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;

  testParseLocatorStrict =
    let check = d:
          let rsl = yarnParse.parseLocatorStrict d;
          in builtins.trace "trying: parseLocatorStrict \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;


}
