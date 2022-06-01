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


in {

/* -------------------------------------------------------------------------- */

  parseDescSimple =
    let
      d = "@smoke/midz@npm:4.2.0";
      rsl = yarnParse.parseDescriptor d;
      expected = { descriptor = "npm:4.2.0"; pname = "midz"; scope = "smoke"; };
      check = let pass = expected == rsl; in
              builtins.trace "parseDescriptor \"${d}\" ==> ${bts pass}" pass;
    in check;

  parseDesc =
    let check = d: let rsl = yarnParse.parseDescriptor d;
                   in builtins.trace "trying: parseDescriptor \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;

  parseDescStrict =
    let check = d:
          let rsl = yarnParse.parseDescriptorStrict d;
          in builtins.trace "trying: parseDescriptorStrict \"${d}\"" rsl;
    in builtins.deepSeq ( map check dsample ) true;


/* -------------------------------------------------------------------------- */

}
