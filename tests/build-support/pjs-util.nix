{ pjsUtil, jq, stdenv }: stdenv.mkDerivation {
  name = "test-pjs-util.log";
  src  = builtins.path { path = ./pjs-util; };
  nativeBuildInputs = [pjsUtil jq];
  dontConfigure = true;
  dontBuild     = true;
  doCheck       = true;
  checkPhase    = ''
    export DONT_SOURCE=:;
    source ./check.sh 2>&1|tee "$out"
  '';
  dontInstall = true;
}
