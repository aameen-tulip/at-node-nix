{ pkgs             ? import <nixpkgs> {}
, lndir            ? pkgs.xorg.lndir
, runCommandNoCC   ? pkgs.runCommandNoCC
}:
let
  mkModule = scope: pname: runCommandNoCC "${scope}-${pname}" {
    inherit pname scope;
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    mkdir -p $out/lib/node_modules/@${scope}/${pname}
    echo '\
    { "name": "@${scope}/${pname}",
      "version": "1.0.0"
    }' > $out/lib/node_modules/@${scope}/${pname}/package.json
  '';
  modules = [
    ( mkModule "foo" "bar" )
    ( mkModule "foo" "sally" )
    ( mkModule "baz" "quux" )
    ( mkModule "petr" "kropotkin" )
  ];
in runCommandNoCC "my-node_modules" {
     inherit modules;
     preferLocalBuild = true;
     allowSubstitutes = false;
} ( "mkdir -p $out\n" + (  builtins.concatStringsSep "\n" ( map ( m:
      "${lndir}/bin/lndir -silent -ignorelinks ${m} $out" ) modules ) ) )
