# =========================================================================== #
# -*- mode: sh; sh-shell: bash; -*-
# --------------------------------------------------------------------------- #
#
# Expects `bash', `jq', `sed', `coreutils', and `findutils' to be in path.
#
# --------------------------------------------------------------------------- #

: "${JQ:=jq}";
: "${CP:=cp}";
: "${LN:=ln}";
: "${FIND:=find}";
: "${MKDIR:=mkdir}";
: "${CHMOD:=chmod}";
: "${SED:=sed}";
: "${BASH:=bash}";
: "${PATCH_SHEBANGS:=patchShebangs}";

: "${skipMissing:=1}";
: "${scriptFallback:=:}";


# --------------------------------------------------------------------------- #

pjsBasename() {
  $JQ -r '.name|capture( "(?<scope>[^/]+/)?(?<bname>[^/]+)" )|.bname'  \
      "${1:-package.json}";
}


# --------------------------------------------------------------------------- #

pjsHasScript() {
  $JQ -e --arg sn "$1" 'has( "scripts" ) and ( .scripts|has( $sn ) )'  \
      "${2:-package.json}" >/dev/null;
}

pjsRunScript() {
  if test "$skipMissing" -eq 1; then
    $BASH -c "$(
      $JQ -r --arg sn "$1" --arg fb "$scriptFallback"   \
          '.scripts[$sn] // $fb' "${2:-package.json}";
    )";
  else
    $BASH -c "$(
      $JQ -r --arg sn "$1" '.scripts[$sn]' "${2:-package.json}";
    )";
  fi
}


# --------------------------------------------------------------------------- #

pjsHasBin() {
  $JQ -e 'has( "bin" )' "${1:-package.json}" >/dev/null;
}

pjsHasBinString() {
  $JQ -e 'has( "bin" ) and ( ( .bin|type ) == "string" )'  \
      "${1:-package.json}" >/dev/null;
}

pjsHasBindir() {
  $JQ -e 'has( "directories" ) and ( .directories|has( "bin" ) )'  \
      "${1:-package.json}" >/dev/null;
}

pjsHasAnyBin() {
  $JQ -e 'has( "bin" ) or ( has( "directories" ) and
          ( .directories|has( "bin" ) ) )'  \
      "${1:-package.json}" >/dev/null;
}

pjsBinPairs() {
  local pdir bdir script bname;
  if pjsHasBin "$1"; then
    if pjsHasBinString "$1"; then
      script="$( $JQ -r '.bin' "${1:-package.json}"; )";
      bname="$( pjsBasename ${1:-}; )";
      echo "$bname $script";
    else
      $JQ -r '.bin|to_entries|map( .key + " " + .value )[]'  \
          "${1:-package.json}";
    fi
  elif pjsHasBindir "$1"; then
    pdir="${1:+${1%/*}}";
    pdir="${pdir:=.}";
    bdir="$( $JQ -r '.directories.bin' "${1:-package.json}"; )";
    $FIND "$pdir/$bdir" -maxdepth 1 -type f -printf "%f $bdir/%f\n"  \
      |$SED 's/\([^.]\+\)\(\.[^ ]\+\) /\1 /';
  fi
}

pjsBinPaths() {
  local pdir bdir;
  if pjsHasBin "$1"; then
    if pjsHasBinString "$1"; then
      $JQ -r '.bin' "${1:-package.json}";
    else
      $JQ -r '.bin|keys' "${1:-package.json}";
    fi
  elif pjsHasBindir "$1"; then
    pdir="${1:+${1%/*}}";
    pdir="${pdir:=.}";
    bdir="$( $JQ -r '.directories.bin' "${1:-package.json}"; )";
    $FIND "$pdir/$bdir" -maxdepth 1 -type f -print;
  fi
}


# --------------------------------------------------------------------------- #

pjsSetBinPerms() {
  $CHMOD +x -- $( pjsBinPaths "$1"; );
}


# --------------------------------------------------------------------------- #

pjsPatchShebangs() {
  test "${dontPatchShebangs:-0}" -ne 1 && return 0;
  $PATCH_SHEBANGS $( pjsBinPaths "$1"; );
}


# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
# vim: set filetype=sh :
