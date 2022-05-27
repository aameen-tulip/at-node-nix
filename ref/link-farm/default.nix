{ pkgs             ? import <nixpkgs> {}
, lndir            ? pkgs.xorg.lndir
, runCommandNoCC   ? pkgs.runCommandNoCC
}:
let
  mkModule = scope: pname: runCommandNoCC "${scope}-${pname}" {
    inherit pname scope;
    version = "1.0.0";
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    mkdir -p $out/lib/node_modules/@${scope}/${pname}
    echo '\
    { "name": "@${scope}/${pname}",
      "version": "1.0.0"
    }' > $out/lib/node_modules/@${scope}/${pname}/package.json
  '';

  linkyModule = runCommandNoCC "linky-module" {
    scope = null;
    pname = "linky";
    version = "1.0.0";
    m1 = mkModule "hey" "there";
    m2 = mkModule "hey" "dude";
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    mkdir -p "$out/lib/node_modules/linky/node_modules/@hey"
    echo '\
    { "name": "linky",
      "version": "1.0.0"
    }' > $out/lib/node_modules/linky/package.json
    ln -s -- $m1/lib/node_modules/@hey/there $out/lib/node_modules/linky/node_modules/@hey/there
    ln -s -- $m2/lib/node_modules/@hey/dude $out/lib/node_modules/linky/node_modules/@hey/dude
  '';

  modules = [
    ( mkModule "foo" "bar" )
    ( mkModule "foo" "sally" )
    ( mkModule "baz" "quux" )
    ( mkModule "petr" "kropotkin" )
    linkyModule
  ];

  linkedModules = runCommandNoCC "my-node_modules" {
      inherit modules;
      preferLocalBuild = true;
      allowSubstitutes = false;
  } ( "mkdir -p $out\n" + (  builtins.concatStringsSep "\n" ( map ( m:
    "${lndir}/bin/lndir -silent -ignorelinks ${m} $out" ) modules ) ) );
in { inherit modules linkedModules; }

