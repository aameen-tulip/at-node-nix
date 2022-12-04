#! /usr/bin/env bash
set -eu;
set -o pipefail;

: "${REALPATH:=realpath}";
: "${NIX:=nix}";
: "${NIX_FLAGS:=--no-warn-dirty}";
: "${NIX_CMD_FLAGS:=-L --show-trace}";
: "${SYSTEM:=$( $NIX eval --raw --impure --expr builtins.currentSystem; )}";
: "${GREP:=grep}";
: "${JQ:=jq}";

SDIR="$( $REALPATH "${BASH_SOURCE[0]}" )";
SDIR="${SDIR%/*}";
: "${FLAKE_REF:=$SDIR}";

trap '_es="$?"; exit "$_es";' HUP EXIT INT QUIT ABRT;

nix_w() {
  {
    {
      $NIX $NIX_FLAGS "$@" 3>&2 2>&1 1>&3||exit 1;
    }|$GREP -v 'warning: unknown flake output';
  } 3>&2 2>&1 1>&3;
}

nix_w flake check "$FLAKE_REF" $NIX_CMD_FLAGS --system "$SYSTEM";
nix_w flake check "$FLAKE_REF" $NIX_CMD_FLAGS --system "$SYSTEM" --impure;

# Swallow traces
check_lib() {
  nix_w eval "$FLAKE_REF#lib" --apply 'lib: builtins.deepSeq lib true';
  nix_w eval --impure "$FLAKE_REF#lib" --apply 'lib: builtins.deepSeq lib true';
}
check_lib 2>/dev/null||check_lib;


echo "Testing 'genMeta' Script" >&2;
# Gen Meta
BKEY="$(
  nix_w run "$FLAKE_REF#genMeta" -- '@babel/cli' --json  \
    |$JQ -r '._meta.rootKey';
)";
case "$BKEY" in
  @babel/cli/*) echo "PASS: genMeta"; ;;
  *)
    echo "FAIL: genMeta";
    echo "genMeta expected rookeKey '@babel/cli/*', got '$BKEY'." >&2;
    exit 1;
  ;;
esac
