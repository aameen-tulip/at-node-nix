{ yarnSupport ? import ../../../pkgs/build-support/yarn-lock.nix {} }:
let
  inherit (yarnSupport) readYarnLock resolvesWithNpm;
  yarnLock = readYarnLock ./yarn.lock;
  bts = x: if x then "true" else "false";
in rec {

  resolveBasic =
    let
      check = x: let r = resolvesWithNpm x; in
        builtins.trace "resolvesWithNpm ${x.resolution} ==> ${bts r}" r;
      # Good
      spec1 = { resolution = "foo@npm:1.0.0"; };
      spec2 = { resolution = "@foo/bar@npm:1.0.0"; };
      checkGoods = builtins.all check [spec1 spec2];

      # Bad
      spec3 = { resolution = "foo@workspace:common/npm/realtime-api-client"; };
      spec4 = { resolution = "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#commit=8c9530eda76357686e36ae389ed8c302486a3944"; };
      spec5 = { resolution = "electron-builder-squirrel-windows@patch:electron-builder-squirrel-windows@npm%3A22.10.4#./patches/electron-builder-squirrel-windows.patch::version=22.10.4&hash=d6011d&locator=tulip-player-desktop%40workspace%3Aelectron"; };
      checkBads = ( builtins.all ( x: ! ( check x ) ) [spec3 spec4 spec5] );
    in checkGoods && checkBads;

}
