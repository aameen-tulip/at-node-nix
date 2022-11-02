#! /usr/bin/env bash
# =========================================================================== #
# -*- mode: sh; sh-shell: bash; -*-
# --------------------------------------------------------------------------- #
#
# Expects `bash', `jq', `sed', `coreutils', and `findutils' to be in path.
#
# --------------------------------------------------------------------------- #

set -u;

: "${HEAD:=head}";
: "${GREP:=grep}";

: "${PJS_UTIL_SH:=${BASH_SOURCE[0]%/*}/../pjs-util.sh}";
if test -z "$DONT_SOURCE"; then
  source "$PJS_UTIL_SH";
fi

EX1D="${BASH_SOURCE[0]%/*}/ex1";
EX1="$EX1D/package.json";
EX2D="${BASH_SOURCE[0]%/*}/ex2";
EX2="$EX2D/package.json";
EX3D="${BASH_SOURCE[0]%/*}/ex3";
EX3="$EX3D/package.json";


# --------------------------------------------------------------------------- #

es=0;

runTest() {
  if eval "$1"; then
    echo "PASS: (pjs-util.sh) $1";
    return 0;
  else
    echo "FAIL: (pjs-util.sh) $1";
    set -x;
    eval "$1" >&2;
    set +x;
    es=$(( es + 1 ));
    return 1;
  fi
}


# --------------------------------------------------------------------------- #

test_pjsBasename() {
  test "$( pjsBasename "$EX1"; )" = "ex1";
  test "$( pjsBasename "$EX2"; )" = "ex2";
  test "$( pjsBasename "$EX3"; )" = "ex3";
  return 0;
}


# --------------------------------------------------------------------------- #

test_pjsHasScript() {
  # Has "scripts.build"
  pjsHasScript "install" "$EX1";
  # Doesn't have any scripts
  { pjsHasScript "install" "$EX2"; } && return 1;  # "Not"
  { pjsHasScript "build"   "$EX2"; } && return 1;
  # Has scripts but not "build"
  { pjsHasScript "build" "$EX3"; } && return 1;
  return 0;
}


# --------------------------------------------------------------------------- #

test_pjsRunScript() {
  test "$( pjsRunScript "install" "$EX1"; )" = "hi";
  test "$( scriptFallback='echo no' pjsRunScript "install" "$EX2"; )" = "no";
  scriptFallback=':' pjsRunScript "install" "$EX2";
  if scriptFallback='exit 1' pjsRunScript "build" "$EX3"; then
    return 1;
  fi
  skipMissing=0 pjsRunScript "install" "$EX1" >/dev/null;
  if skipMissing=0 pjsRunScript "install" "$EX2" 2>/dev/null; then
    return 1;
  fi
  return 0;
}


# --------------------------------------------------------------------------- #

test_pjsHasBin() {
  pjsHasBin "$EX1";
  pjsHasBin "$EX2";
  { pjsHasBin "$EX3"; } && return 1;
  return 0;
}

test_pjsHasBinString() {
  { pjsHasBinString "$EX1"; } && return 1;
  pjsHasBinString "$EX2";
  { pjsHasBinString "$EX3"; } && return 1;
  return 0;
}

test_pjsHasBindir() {
  { pjsHasBindir "$EX1"; } && return 1;
  { pjsHasBindir "$EX2"; } && return 1;
  pjsHasBindir "$EX3";
  return 0;
}

test_pjsHasAnyBin() {
  pjsHasAnyBin "$EX1";
  pjsHasAnyBin "$EX2";
  pjsHasAnyBin "$EX3";
  return 0;
}

test_pjsBinPairs() {
  test "$( pjsBinPairs "$EX1"; )" = "foo bin/bar.js";
  test "$( pjsBinPairs "$EX2"; )" = "ex2 bin/bar.sh";
  test "$( pjsBinPairs "$EX3"; )" =                                      \
       "$( printf '%s\n' 'foo scripts/foo.js' 'bar scripts/bar.js'; )";
  return 0;
}

test_pjsBinPaths() {
  test "$( pjsBinPairs "$EX1"; )" = "bin/bar.js";
  test "$( pjsBinPairs "$EX2"; )" = "bin/bar.sh";
  test "$( pjsBinPairs "$EX3"; )" =                                      \
       "$( printf '%s\n' 'scripts/foo.js' 'scripts/bar.js'; )";
  return 0;
}


# --------------------------------------------------------------------------- #

test_installModuleNm() {
  installModuleNm "$EX1" "$PWD/nm1/node_modules";
  return 0;
}


# --------------------------------------------------------------------------- #

test_installBinsNm() {
  export dontPatchShebangs=1;

  installModuleNmNoBin "$EX1D" "$PWD/nm2/node_modules"||return 1;
  installBinsNm "$EX1D" "$PWD/nm2/node_modules"||return 1;
  test -x "$PWD/nm2/node_modules/.bin/foo"||return 1;
  $HEAD -n1 "$PWD/nm2/node_modules/.bin/foo"         \
    |$GREP -q '^#!/nix/store.*/bin/node'&&return 1;

  installModuleNmNoBin "$EX2D" "$PWD/nm3/node_modules"||return 1;
  installBinsNm "$EX2D" "$PWD/nm3/node_modules"||return 1;
  test -x "$PWD/nm3/node_modules/.bin/ex2"||return 1;
  $HEAD -n1 "$PWD/nm3/node_modules/.bin/ex2"         \
    |$GREP -q '^#!/nix/store.*/bin/node'&&return 1;

  installModuleNmNoBin "$EX3D" "$PWD/nm4/node_modules"||return 1;
  installBinsNm "$EX3D" "$PWD/nm4/node_modules"||return 1;
  test -x "$PWD/nm4/node_modules/.bin/foo"||return 1;
  $HEAD -n1 "$PWD/nm4/node_modules/.bin/foo"         \
    |$GREP -q '^#!/nix/store.*/bin/node'&&return 1;
  test -x "$PWD/nm4/node_modules/.bin/bar"||return 1;
  $HEAD -n1 "$PWD/nm4/node_modules/.bin/bar"         \
    |$GREP -q '^#!/nix/store.*/bin/node'&&return 1;

  unset dontPatchShebangs;
  rm -rf "$PWD/nm2" "$PWD/nm3" "$PWD/nm4";
}


# --------------------------------------------------------------------------- #

test_installBinsNm_patch() {
  unset dontPatchShebangs;

  installModuleNmNoBin "$EX1D" "$PWD/nm2/node_modules"||return 1;
  installBinsNm "$EX1D" "$PWD/nm2/node_modules"||return 1;
  test -x "$PWD/nm2/node_modules/.bin/foo"||return 1;
  $HEAD -n1 "$PWD/nm2/node_modules/.bin/foo"         \
    |$GREP -q '^#!/nix/store.*/bin/node'||return 1;

  installModuleNmNoBin "$EX2D" "$PWD/nm3/node_modules"||return 1;
  installBinsNm "$EX2D" "$PWD/nm3/node_modules"||return 1;
  test -x "$PWD/nm3/node_modules/.bin/ex2"||return 1;
  $HEAD -n1 "$PWD/nm3/node_modules/.bin/ex2"         \
    |$GREP -q '^#!/nix/store.*/bin/node'||return 1;

  installModuleNmNoBin "$EX3D" "$PWD/nm4/node_modules"||return 1;
  installBinsNm "$EX3D" "$PWD/nm4/node_modules"||return 1;
  test -x "$PWD/nm4/node_modules/.bin/foo"||return 1;
  $HEAD -n1 "$PWD/nm4/node_modules/.bin/foo"         \
    |$GREP -q '^#!/nix/store.*/bin/node'||return 1;
  test -x "$PWD/nm4/node_modules/.bin/foo"||return 1;
  $HEAD -n1 "$PWD/nm4/node_modules/.bin/foo"         \
    |$GREP -q '^#!/nix/store.*/bin/node'||return 1;

  rm -rf "$PWD/nm2" "$PWD/nm3" "$PWD/nm4";
}


# --------------------------------------------------------------------------- #

test_installGlobal() {
  installModuleGlobal "$EX1" "$PWD/nm2";
  test -x "$PWD/nm2/bin/foo"||return 1;
  test -x "$PWD/nm2/lib/node_modules/ex1/bin/bar.js"||return 1;
  $HEAD -n1 "$PWD/nm2/bin/foo"                       \
    |$GREP -q '^#!/nix/store.*/bin/node'||return 1;
}

# --------------------------------------------------------------------------- #

runTest test_pjsBasename;
runTest test_pjsHasScript;
runTest test_pjsRunScript;

runTest test_pjsHasBin;
runTest test_pjsHasBinString;
runTest test_pjsHasBindir;
runTest test_pjsHasAnyBin;

runTest test_pjsBinPairs;
runTest test_pjsBinPaths;

runTest test_installBinsNm;
runTest test_installBinsNm_patch;

runTest test_installGlobal;

#runTest test_installModuleNm;


# --------------------------------------------------------------------------- #

if test "$es" -eq 0; then
  echo "PASS: pjs-util.sh" >&2;
else
  echo "FAIL: pjs-util.sh" >&2;
fi
exit "$es";


# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
# vim: set filetype=sh :
