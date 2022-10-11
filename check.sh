#! /usr/bin/env bash
set -eu;

: "${NIX:=nix}";
: "${NIX_FLAGS:=-L --show-trace}";
: "${SYSTEM:=$( $NIX eval --raw --impure --expr builtins.currentSystem; )}";

$NIX flake check $NIX_FLAGS;
$NIX flake check $NIX_FLAGS --impure;
$NIX flake check $NIX_FLAGS --system "$SYSTEM";
$NIX flake check $NIX_FLAGS --system "$SYSTEM" --impure;
trap '_es="$?"; rm -f ./result; exit "$_es";' HUP TERM EXIT INT QUIT;
$NIX build .#tests $NIX_FLAGS;
$NIX build .#tests $NIX_FLAGS --impure;
