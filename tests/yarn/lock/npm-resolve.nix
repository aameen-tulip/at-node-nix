{ yarnSupport ? import ../../../pkgs/build-support/yarn-lock.nix {} }:
let
  yarnLockBig = yarnSupport.readYarnLock ./yarn-big.lock;
  yarnLockBasic = yarnSupport.readYarnLock ./yarn-basic.lock;
  bts = x: if x then "true" else "false";

  # Good
  spec1 = { resolution = "foo@npm:1.0.0"; };
  spec2 = { resolution = "@foo/bar@npm:1.0.0"; };
  # Bad
  spec3 = { resolution = "foo@workspace:common/npm/realtime-api-client"; };
  spec4 = { resolution = "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#commit=8c9530eda76357686e36ae389ed8c302486a3944"; };
  spec5 = { resolution = "electron-builder-squirrel-windows@patch:electron-builder-squirrel-windows@npm%3A22.10.4#./patches/electron-builder-squirrel-windows.patch::version=22.10.4&hash=d6011d&locator=tulip-player-desktop%40workspace%3Aelectron"; };

in rec {

  resolveBasic =
    let
      check = x: let r = yarnSupport.resolvesWithNpm x; in
        builtins.trace "resolvesWithNpm ${x.resolution} ==> ${bts r}" r;
      checkGoods = builtins.all check [spec1 spec2];
      checkBads = ( builtins.all ( x: ! ( check x ) ) [spec3 spec4 spec5] );
    in checkGoods && checkBads;

  resolveFromFile =
    let
      expectedBasic = ["7zip-bin@5.0.3"];
      expectedBig = let inherit (builtins) fromJSON readFile; in
        fromJSON ( readFile ./yarn-big-expected-npm-resolutions.json );
      check = name: lock: expected:
        let
          resolves = yarnSupport.getNpmResolutions lock;
          pass = expected == resolves;
        in builtins.trace "resolveFromFile ${name}: ${bts pass}" pass;
      checkBasic = check "yarn-basic.lock" yarnLockBasic expectedBasic;
      checkBig = check "yarn-big.lock" yarnLockBig expectedBig;
    in builtins.all ( x: x ) [checkBasic checkBig];

}
