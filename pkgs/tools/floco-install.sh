#!/usr/bin/env bash
# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

_as_me='floco install';
_version='0.0.1';


# ---------------------------------------------------------------------------- #

perror() { echo "$_as_me: ERROR: $*" >&2; }

die() {
  local _ecode;
  _ecode="$1";
  shift;
  perror "$@";
  exit "$_ecode";
}


# ---------------------------------------------------------------------------- #

version() { echo "$_version"; }

usage() {
  :;
}


# ---------------------------------------------------------------------------- #

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --prefix=*)  PREFIX="${1#*=}"; ;;
    --prefix)    shift; PREFIX="$1"; ;;

    --bindir=*)  BINDIR="${1#*=}"; ;;
    --bindir)    shift; BINDIR="$1"; ;;

    --libdir=*)  LIBDIR="${1#*=}"; ;;
    --libdir)    shift; LIBDIR="$1"; ;;

    -g|--global) FSH=standard; ;;
    -l|--local)  FSH=nmroot; ;;

    --node=*)    NODE="${1#*=}"; ;;
    --node)      shift; NODE="$1"; ;;

    -l|--lndirs) STYLE=lndirs; ;;
    -c|--copy)   STYLE=copy; ;;

    --bin-links) BSTYLE=link; ;;
    --bin-wraps) BSTYLE=wrap; ;;
    --no-bins)   BSTYLE=skip; ;;

    --umask=*)    UMASK="${1#*=}"; ;;
    --umask)      shift; UMASK="$1"; ;;
    --fmode=*)    FMODE="${1#*=}"; ;;
    --fmode)      shift; FMODE="$1"; ;;
    --emode=*)    EMODE="${1#*=}"; ;;
    --emode)      shift; EMODE="$1"; ;;
    --dmode=*)    DMODE="${1#*=}"; ;;
    --dmode)      shift; DMODE="$1"; ;;

    -p|--patch)    PATCH=1; ;;
    -P|--no-patch) PATCH=0; ;;

    -u|-h|--help) usage; exit 0; ;;
    -V|--version) version; exit 0; ;;

    --from=*)  FDIR="${1#*=}"; FDIR="${FDIR%/package.json}"; ;;
    -f|--from) shift; FDIR="$1"; FDIR="${FDIR%/package.json}"; ;;
  esac
  shift;
done


# ---------------------------------------------------------------------------- #

: "${PREFIX:=${out:-/usr}}";
: "${FSH:=nmroot}";
if [[ "$FSH" = nmroot ]]; then
  : "${LIBDIR:=$PREFIX}";
  NMDIR="$LIBDIR/node_modules";
  : "${BINDIR:=$NMDIR/.bin}";
else
  : "${LIBDIR:=$PREFIX/lib}";
  : "${BINDIR:=$PREFIX/bin}";
  NMDIR="$LIBDIR/node_modules";
fi

if [[ -z "${FDIR:-}" ]]; then
  if [[ -r "$PWD/package.json" ]]; then
    FDIR="$PWD";
  else
    perror                                                                     \
      "Unable to determine package to be installed. "                          \
      "Set '--from=<PATH>' or run in a directory containing 'package.json'.";
    usage >&2;
    exit 1;
  fi
fi


# ---------------------------------------------------------------------------- #

: "${STYLE:=copy}";
: "${BSTYLE:=link}";

# Sets default permissions.
# NOTE: `0###' below is "octal", so `06 - 02 = 05'.
# Executables and Dirs have a "max" of 0777, while files have `0666'.
# "Executables" are identified by scraping `bin' info from `package.json'.
# Given the `*MODE' perms, we substract `UMASK' to allow limiting by the user.
# By default we would get:
#   executable/dirs: 0777 - 0022 = 0755
#   files:           0666 - 0022 = 0555
: "${UMASK:=0022}";
: "${FMODE:=0666}";
: "${EMODE:=0777}";
: "${DMODE:=0777}";


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
