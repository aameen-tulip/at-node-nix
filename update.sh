#! /usr/bin/env bash
set -eu;

: "${NIX:=nix}";
: "${FIND:=find}";
: "${BASH:=bash}";
: "${GIT:=git}";
: "${ROOT_DIR:=${BASH_SOURCE[0]%/*}}";
export GIT NIX;

CMD='update';
NARGS=();

while test "$#" -gt 0; do
  case "$1" in
    -u|--update-input)
      CMD='lock';
      NARGS+=( --update-input "${2?missing input}" );
      shift;
    ;;
    *)
      echo "unrecognized args: $*" >&2;
      echo "USAGE:  update.sh [(-u|--update-input) FLAKE_REF]..." >&2;
      exit 1;
    ;;
  esac
  shift;
done

$FIND "$ROOT_DIR" -name flake.lock           \
  -execdir $NIX flake "$CMD" ${NARGS[@]} \;  \
  -execdir $BASH -c '
    if ! $NIX flake check; then
      $GIT restore ./flake.lock;
      echo "\nFailed to update: $PWD" >&2;
    fi' \; ;
