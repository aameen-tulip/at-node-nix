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

: "${globalInstall:=0}";
: "${skipMissing:=1}";
: "${scriptFallback:=:}";

# NOTE: `dontPatchShebangs' is checked with fallback every time it's referenced.


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
    pdir="${1:+${1%/package*.json}}";
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
      $JQ -r '.bin|keys[]' "${1:-package.json}";
    fi
  elif pjsHasBindir "$1"; then
#    pdir="${1:+${1%/package.json}}";
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

# addMod SRC-DIR OUT-DIR
# Ex:  addMod ./unpacked "$out/@foo/bar"
defaultAddMod() {
  if test -e "$2"; then
    test -w "${2%/*}"||$CHMOD +w "${2%/*}";
  fi
  $MKDIR -p "$2";
  $CP -r --no-preserve=mode --reflink=auto -T -- "$1" "$2";
}

# addMod FROM TO
# Ex:  addBin ./unpacked/bin/quux "$out/bin/quux"
defaultAddBin() {
  if test -e "$2"; then
    test -w "${2%/*}"||$CHMOD +w "${2%/*}";
  fi
  $MKDIR -p "${2%/*}";
  $LN -srf -- "$1" "$2";
}


# --------------------------------------------------------------------------- #

installModuleGlobal() {
  return 0;
}


# --------------------------------------------------------------------------- #

_INSTALL_NM_PARGS='
  if test -n "${node_modules_path:-}"; then
    pdir="${1:+${1%/package*.json}}";
    pdir="${pdir:=$PWD}";
    nmdir="$node_modules_path";
  elif test "$#" -eq 1; then
    pdir="$PWD";
    nmdir="${1:-node_modules}";
  elif test "$#" -eq 2; then
    pdir="${1:+${1%/package*.json}}";
    pdir="${pdir:=$PWD}";
    nmdir="$2";
  else
    nmdir="$1";
    shift;
    for p in "$@"; do
      eval "$__SELF__ $p $nmdir";
    done
    return 0;
  fi
  idir="$nmdir/$( $JQ -r ".name" "$pdir/package.json"; )";
';

installBinsNm() {
  local pdir nmdir _ADD_BIN __SELF__;
  __SELF__='installBinsNm';
  eval "$_INSTALL_NM_PARGS";
  if ! pjsHasAnyBin "$pdir/package.json"; then
    return 0;
  fi
  if test -z "${_ADD_BIN:=${ADD_BIN:-}}"; then
    if declare -F addBin; then
      _ADD_BIN=addBin;
    else
      _ADD_BIN=defaultAddBin;
    fi
  fi
  _IFS="$IFS";
  IFS=$'\n';
  for bp in $( cd "$idir" >/dev/null; pjsBinPairs "$PWD/package.json"; ); do
    f="${bp##* }";
    t="${bp%% *}";
    if test -n "${f%%/*}"; then
      bf="${idir}/$f"
    fi
    if test -n "${t%%/*}"; then
      bt="${idir}/../.bin/$t"
    fi
    IFS="$_IFS";
    eval "( $_ADD_BIN "${bf:-$f}" "${bt:-$t}"; )";
  done
}


# --------------------------------------------------------------------------- #

# installModuleNmNoBin [PJS-PATH=$PWD/package.json] [NM-DIR=$node_modules_path]
# installModuleNmNoBin NM-DIR PJS-PATH1 PJS-PATH2 [PJS-PATHS...]
installModuleNmNoBin() {
  local pdir nmdir _ADD_MOD __SELF__;
  __SELF__='installModuleNmNoBin';
  eval "$_INSTALL_NM_PARGS";
  if test -z "${_ADD_MOD:=${ADD_MOD:-}}"; then
    if declare -F addMod; then
      _ADD_MOD=addMod;
    else
      _ADD_MOD=defaultAddMod;
    fi
  fi
  eval "( $_ADD_MOD "$pdir" "$idir"; )";
}


# --------------------------------------------------------------------------- #

# installModuleNm [PJS-PATH=$PWD/package.json] [NM-DIR=$node_modules_path]
# installModuleNm NM-DIR PJS-PATH1 PJS-PATH2 [PJS-PATHS...]
installModuleNm() {
  installModuleNmNoBin "$@";
  installBinsNm "$@";
}



# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
# vim: set filetype=sh :
