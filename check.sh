#! /usr/bin/env bash
set -eu;

: "${NIX:=nix}";
: "${NIX_FLAGS:=-L --show-trace}";
: "${SYSTEM:=$( $NIX eval --raw --impure --expr builtins.currentSystem; )}";

trap '_es="$?"; exit "$_es";' HUP EXIT INT QUIT ABRT;

$NIX flake check $NIX_FLAGS;
$NIX flake check $NIX_FLAGS --impure;
$NIX flake check $NIX_FLAGS --system "$SYSTEM";
$NIX flake check $NIX_FLAGS --system "$SYSTEM" --impure;
NIX_FLAGS+=' --no-link';
$NIX build .#tests $NIX_FLAGS;
$NIX build .#tests $NIX_FLAGS --impure;

# Gen Meta
BKEY="$( $NIX run .#genMeta -- '@babel/cli' --json|jq -r '.__meta.rootKey'; )";
case "$BKEY" in
  @babel/cli/*) :; ;;
  *)
    echo "genMeta expected rookeKey '@babel/cli/*', got '$BKEY'." >&2;
    exit 1;
  ;;
esac
