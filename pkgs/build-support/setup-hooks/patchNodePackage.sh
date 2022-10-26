# =========================================================================== #
# -*- mode: sh; sh-shell: bash; -*-
# --------------------------------------------------------------------------- #
#
# Expects `bash', `jq', `sed', `node', `coreutils', and `findutils' to be
# in PATH.
#
# --------------------------------------------------------------------------- #

preConfigurePhases+=" patchNodePackage";
preInstallPhases+=" patchNodePackage";

patchNodePackage() {
  local pdir;
  if [[ -r ./package.json ]]; then
    pdir="$PWD";
  elif [[ -r "$sourceRoot/package.json" ]]; then
    pdir="$PWD/$sourceRoot";
  else
    echo "$PWD: Cannot locate Node Package to be patched" >&2;
    return 1;
  fi
  pjsSetBinPerms "$pdir";
  pjsPatchNodeShebangs "$pdir";
  export installBinsNmSkipPatch=':';
}


# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
# vim: set filetype=sh :
