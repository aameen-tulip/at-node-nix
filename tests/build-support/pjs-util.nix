{ pjsUtil, jq, stdenv, nodejs }: stdenv.mkDerivation {
  name = "test-pjs-util.log";
  src  = builtins.path { path = ./pjs-util; };
  nativeBuildInputs = [pjsUtil jq nodejs];
  dontConfigure = true;
  dontBuild     = true;
  doCheck       = true;
  checkPhase    = ''
    export DONT_SOURCE=:;
    source ./check.sh 2>&1|tee "$out"
  '';
  dontInstall = true;
}
