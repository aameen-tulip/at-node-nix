
{ lib
, makeSetupHook
, jq
, bash
, nodejs
, gnugrep
, gnused
, findutils
, coreutils
}: let
  pjsUtil = import ./pjs-util.nix {
    inherit makeSetupHook jq nodejs bash gnused gnugrep findutils coreutils;
  };
in {

  inherit pjsUtil;

  patchNodePackageHook = makeSetupHook {
    name = "patchNodePackage";
    deps = [pjsUtil];
  } ./patchNodePackage.sh;

  # FIXME: doesn't install runtime `node_modules/'.
  installGlobalNodeModuleHook = makeSetupHook {
    name = "installGlobalNodeModule";
    deps = [pjsUtil];
  } ./installGlobal.sh;

}
