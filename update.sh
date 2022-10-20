#! /usr/bin/env bash
set -eu;

: "${NIX:=nix}";
: "${FIND:=find}";
: "${BASH:=bash}";
: "${GIT:=git}";
: "${ROOT_DIR:=${BASH_SOURCE[0]%/*}}";
export GIT NIX;

$FIND "$ROOT_DIR" -name flake.lock        \
  -execdir $NIX flake update \;           \
  -execdir $BASH -c '
    if ! $NIX flake check; then
      $GIT restore ./flake.lock;
      echo "Failed to update: $PWD" >&2;
    fi' \;                                \
;
