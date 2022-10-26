#! /usr/bin/env bash
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
: "${GREP:=grep}";
: "${READLINK:=readlink}";
: "${REALPATH:=realpath}";
: "${PATCH_NODE_SHEBANGS:=pjsPatchNodeShebangsForce}";

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
  if [[ "$skipMissing" -eq 1 ]]; then
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
# --------------------------------------------------------------------------- #

pjsBinPairs() {
  local pdir bdir script bname;
  pdir="${1:+${1%/package.json}}";
  pdir="${pdir:=$PWD}";
  if pjsHasBin "$pdir/package.json"; then
    if pjsHasBinString "$pdir/package.json"; then
      script="$( $JQ -r '.bin' "$pdir/package.json"; )";
      bname="$( pjsBasename "$pdir/package.json"; )";
      echo "$bname $script";
    else
      $JQ -r '.bin|to_entries|map( .key + " " + .value )[]'  \
          "$pdir/package.json";
    fi
  elif pjsHasBindir "$pdir/package.json"; then
    bdir="$( $JQ -r '.directories.bin' "$pdir/package.json"; )";
    $FIND "$pdir/$bdir" -maxdepth 1 -type f -printf "%f $bdir/%f\n"  \
      |$SED 's/\([^.]\+\)\(\.[^ ]\+\) /\1 /';
  fi
}

# pjsBinPaths [PKG-DIR:=$PWD]
pjsBinPaths() {
  local pdir bdir;
  pdir="${1:+${1%/package.json}}";
  pdir="${pdir:=$PWD}";
  if pjsHasBin "$pdir/package.json"; then
    if pjsHasBinString "$pdir/package.json"; then
      $JQ -r '.bin' "$pdir/package.json";
    else
      $JQ -r '.bin[]' "$pdir/package.json";
    fi
  elif pjsHasBindir "$pdir/package.json"; then
    bdir="$( $JQ -r '.directories.bin' "$pdir/package.json"; )";
    ( cd "$pdir" >/dev/null; $FIND "$bdir/" -maxdepth 1 -type f -print; );
  fi
}


# --------------------------------------------------------------------------- #

# pjsSetBinPerms [PKG-DIR:=PWD]
# Set executable permissions for bins declared in `package.json'.
pjsSetBinPerms() {
  local pdir bpaths;
  pdir="${1:+${1%/package.json}}";
  pdir="${pdir:=$PWD}";
  bpaths=( $( pjsBinPaths "$pdir"; ) );
  if [[ -n "${bpaths[*]:-}" ]]; then
    $CHMOD +x -- $( printf "$pdir/%s " "${bpaths[@]}"; );
  fi
}


# --------------------------------------------------------------------------- #

pjsHasField() {
  $JQ -e "( .${1#.} // \"_%FAIL%_\" ) != \"_%FAIL%_\"" "${2:-package.json}"  \
      >/dev/null 2>&1;
}


# --------------------------------------------------------------------------- #

pjsFilesOr() {
  local _default
  _default="$1";
  if $JQ -e 'has( "files" )' "${2:-package.json}" >/dev/null; then
    $JQ -r '.files[]' "${2:-package.json}";
  else
    eval printf '%s\\n' "$_default";
  fi
}

# FIXME: remove ignore files and junk
pjsPacklist() {
  declare -a fs;
  if [[ "$#" -gt 0 ]]; then
    pushd "${1%/*}" >/dev/null;
  else
    pushd . >/dev/null;
  fi
  if $JQ -e 'has( "files" )' package.json >/dev/null; then
    _fs=( $( $JQ -r ".files[]|\"-o -name \" + ." package.json; ) );
    _fs=( $( $FIND . -iname 'readme*' -o -iname 'license*' ${_fs[@]}; ) );
  else
    _fs=( * );
  fi
  printf '%s\n' "${_fs[@]}";
  popd >/dev/null 2>&1||:;
}


# --------------------------------------------------------------------------- #

pjsPatchNodeShebangsForce_one() {
  local timestamp oldInterpreterLine oldPath arg0 args;
  pjsIsScript "$1"||return 0;
  read -r oldInterpreterLine < "$f";
  read -r oldPath arg0 args <<< "${oldInterpreterLine:2}";
  # Only modify `node' shebangs.
  case "$oldPath $arg0" in
    */bin/env\ *node) :; ;;
    */node\ |node\ )
      case "$oldPath" in
        $NIX_STORE/*) return 0; ;;
        *) :; ;;
      esac
      :;
    ;;
    *) return 0; ;;
  esac
  : "${_NODE_BIN:=$( $READLINK -f "$( command -v node; )"; )}";
  timestamp="$( stat --printf '%y' "$1"; )";
  printf '%s'                                                         \
    "$1: interpreter directive changed from \"$oldInterpreterLine\""  \
    " to \"#!${_NODE_BIN:?}\"" >&2;
  echo '' >&2;
  $SED -i -e "1 s|.*|#\!$_NODE_BIN|" "$1";
  touch --date "$timestamp" "$1";
}

pjsPatchNodeShebangsForce() {
  : "${_NODE_BIN:=$( $READLINK -f $( command -v node; ); )}";
  while IFS= read -r -d $'\0' f; do
    pjsPatchNodeShebangsForce_one "$f";
  done < <( $FIND "$@" -type f -perm -0100 -print0; );
}

pjsPatchNodeShebangs() {
  local pdir bpaths;
  if [[ -n "${dontPatchShebangs-}" ]]; then
    return 0;
  fi
  pdir="${1:+${1%/package.json}}";
  pdir="${pdir:=$PWD}";
  bpaths=( $( pjsBinPaths "$pdir"; ) );
  if [[ -n "${bpaths[*]:-}" ]]; then
    $PATCH_NODE_SHEBANGS $( printf "$pdir/%s " "${bpaths[@]}"; );
  fi
}


# --------------------------------------------------------------------------- #

# addMod SRC-DIR OUT-DIR
# Ex:  addMod ./unpacked "$out/@foo/bar"
defaultAddMod() {
  if [[ -e "$2" ]]; then
    [[ -w "${2%/*}" ]]||$CHMOD +w "${2%/*}";
  fi
  $MKDIR -p "$2";
  $CP -r --no-preserve=mode --reflink=auto -T -- "$1" "$2";
}

# addMod FROM TO
# Ex:  addBin ./unpacked/bin/quux "$out/bin/quux"
defaultAddBin() {
  if [[ -e "$2" ]]; then
    [[ -w "${2%/*}" ]]||$CHMOD +w "${2%/*}";
  fi
  $MKDIR -p "${2%/*}";
  $LN -srf -- "$1" "$2";
}


# --------------------------------------------------------------------------- #

# Process args for NM Dir installers.
# `pdir' refers to the "package.json" dir.
# `idir' refers to the "install" prefix, being a `node_modules/*' subdir.
# `nmdir' refers to the "parent" `node_modules/' dir above `idir'.
#
# If `node_modules_path' is set, "package dir" `pdir' is arg1 or PWD if omitted.
# Otherwise, a single arg sets `pdir=$PWD' and `nmdir=$1'.
# Two args sets `pdir=$1' ( strips `package.json' if given ), `nmdir=$2'.
# Otherwise `nmdir=$1' and remaining args are treated as multiple `pdirs'.
_INSTALL_NM_PARGS='
  if [[ -n "${node_modules_path:-}" ]]; then
    pdir="${1:+${1%/package*.json}}";
    pdir="${pdir:=$PWD}";
    nmdir="$node_modules_path";
  elif [[ "$#" -eq 1 ]]; then
    pdir="$PWD";
    nmdir="${1:-node_modules}";
  elif [[ "$#" -eq 2 ]]; then
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


# --------------------------------------------------------------------------- #

# installModuleNmNoBin [PJS-PATH=$PWD/package.json] [NM-DIR=$node_modules_path]
# installModuleNmNoBin NM-DIR PJS-PATH1 PJS-PATH2 [PJS-PATHS...]
installModuleNmNoBin() {
  local pdir nmdir _ADD_MOD __SELF__;
  __SELF__='installModuleNmNoBin';
  eval "$_INSTALL_NM_PARGS";
  if [[ -z "${_ADD_MOD:=${ADD_MOD:-}}" ]]; then
    if declare -F addMod; then
      _ADD_MOD=addMod;
    else
      _ADD_MOD=defaultAddMod;
    fi
  fi
  eval "( $_ADD_MOD "$pdir" "$idir"; )";
}


# --------------------------------------------------------------------------- #

# Install executables from `idir' to `$nmdir/.bin/'.
# `idir' is expected to already contain an installed module.
# `pdir' may point elsewhere and is only used to collect the bin entries.
installBinsNm() {
  local pdir nmdir _bindir _ADD_BIN __SELF__;
  __SELF__='installBinsNm';
  eval "$_INSTALL_NM_PARGS";
  if ! pjsHasAnyBin "$pdir/package.json"; then
    return 0;
  fi
  if [[ -z "${_ADD_BIN:=${ADD_BIN:-}}" ]]; then
    if declare -F addBin; then
      _ADD_BIN=addBin;
    else
      _ADD_BIN=defaultAddBin;
    fi
  fi

  # Set executable permissions first.
  pjsSetBinPerms "$idir";

  # Maybe patch shebangs.
  pjsPatchNodeShebangs "$idir";

  # Install relative symlinks into parent `$nmdir'.
  _IFS="$IFS";
  IFS=$'\n';
  for bp in $( cd "$idir" >/dev/null; pjsBinPairs "$PWD/package.json"; ); do
    f="${bp##* }";
    t="${bp%% *}";
    if [[ -n "${f%%/*}" ]]; then
      bf="$idir/$f"
    fi
    if [[ -n "${t%%/*}" ]]; then
      _bindir="${bindir:-}";
      if [[ -z "${_bindir:-}" ]]; then
        if [[ "$idir" =~ "@" ]]; then
          _bindir="$idir/../../.bin"
        else
          _bindir="$idir/../.bin"
        fi
      fi
      bt="$_bindir/$t";
    fi
    IFS="$_IFS";
    eval "( $_ADD_BIN "${bf:-$f}" "${bt:-$t}"; )";
  done
}


# --------------------------------------------------------------------------- #

# installModuleNm [PJS-PATH=$PWD/package.json] [NM-DIR=$node_modules_path]
# installModuleNm NM-DIR PJS-PATH1 PJS-PATH2 [PJS-PATHS...]
installModuleNm() {
  installModuleNmNoBin "$@";
  installBinsNm "$@";
}



# --------------------------------------------------------------------------- #

# installModuleGlobal [PJS-PATH=$PWD/package.json] [PREFIX:=$out]
installModuleGlobal() {
  local _prefix pdir;
  pdir="${1:+$( $REALPATH ${1%/package.json}; )}";
  if [[ ! -r "$pdir/package.json" ]]; then
    _prefix="$pdir";
    pdir="${2:=$PWD}";
  fi
  : "${_prefix:=${2:-${prefix:-$out}}}";
  bindir="$_prefix/bin" installModuleNm "$pdir" "$_prefix/lib/node_modules";
}


# --------------------------------------------------------------------------- #

# Identical to `<nixpkgs>/pkgs/stdenv/generic/setup.sh'
pjsIsScript() {
  local fn="$1";
  local fd;
  local magic;
  exec {fd}< "$fn";
  read -r -n 2 -u "$fd" magic;
  exec {fd}<&-
  if [[ "$magic" =~ \#! ]]; then
    return 0;
  else
    return 1;
  fi
}


# --------------------------------------------------------------------------- #
#
#
#
# =========================================================================== #
# vim: set filetype=sh :
