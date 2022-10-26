
{ lib
, makeSetupHook
, jq
, bash
, nodejs
}: let
  pjsUtil = import ./pjs-util.nix { inherit jq makeSetupHook nodejs bash; };
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
