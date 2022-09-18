#! /usr/bin/env bash

# FIXME: currently only designed to support NPM registry tarballs.
# I think it will probably work for other sorts of packages; but I haven't
# tested anything else.

: "${NIX:=nix}";
: "${MKTEMP:=mktemp}";
: "${CAT:=cat}";
: "${PACOTE:=$NIX run github:aameen-tulip/at-node-nix#pacote --}";
: "${NPM:=$NIX run nixpkgs#nodejs-14_x.pkgs.npm --}";
: "${JQ:=$NIX run nixpkgs#jq --}";

: "${FLAKE_REF:=github:aameen-tulip/at-node-nix}";

usage() {
  {
    echo "Generate a Floco metaSet for an NPM registry tarball";
    echo "USAGE:  genMeta [--dev|-d|--prod|-p] DESCRIPTOR";
    echo "        genMeta @foo/bar";
    echo "        genMeta --dev @foo/bar@1.0.0";
    echo "ARGUMENTS";
    echo "  DESCRIPTOR   A Node.js package descriptor like '<NAME>@<VERSION>'";
    echo "               or '<PATH>' or '<NAME>' or any other string supported";
    echo "               by NPM/pacote";
    echo "OPTIONS";
    echo "  -p,--prod    Drop devDependencies metadata";
    echo "  -d,--dev     Preserve devDependencies metadata";
    echo "ENVIRONMENT";
    echo "  FLAKE_REF    Flake URI to use for at-node-nix";
    echo "               default: github:aameen-tulip/at-node-nix";
    echo "  The following utilities may be indicated with absolute paths:";
    echo "  NIX MKTEMP CAT PACOTE NPM JQ";
  }
}

while test "$#" -gt 0; do
  case "$1" in
    -d|--dev)  DEV=true;        ;;
    -p|--prod) DEV=false;       ;;
    -h|--help) usage; exit 0;   ;;
    *)         DESCRIPTOR="$1"; ;;
  esac
  shift;
done

: "${DEV:=false}";
if test -z "${DESCRIPTOR:-}"; then
  echo "You must provide a package descriptor or identifier" >&2;
  usage;
  exit 1;
fi

dir="$( mktemp -d; )";
srcInfo="$( mktemp; )";
pushd "$dir" >/dev/null;
trap '_es="$?"; popd >/dev/null; rm -rf "$dir" "$srcInfo"; exit "$_es";'  \
  HUP TERM EXIT INT QUIT;

# We stash the output of `pacote' which contains `sourceInfo' fields.
$PACOTE extract "$DESCRIPTOR" . --json > "$srcInfo" 2>/dev/null;

# Produce a lockfile
NPM_CONFIG_LOCKFILE_VERSION=3                                    \
  $NPM install --package-lock-only --ignore-scripts >/dev/null;

# Unless `--dev' is provided, we drop the `devDependencies' field since we
# really only care about the install deps.
# This isn't required; but it cuts out superfulous metadata.
# Additionally we add our `sourceInfo' metadata provided by `pacote' since the
# lockfile will treat it as a regular filepath otherwise ( `/tmp/XXX' ).
$JQ                                                                           \
  --argjson gypfile "$( test -r ./binding.gyp && echo true || echo false; )"  \
  --argjson srcInfo "$( $CAT "$srcInfo"; )"                                   \
  --argjson dev     "$DEV"                                                    \
' ( if ( $dev|not ) then
      ( ( .packages|=with_entries( select( .value.dev // false|not ) ) )
        |del( .packages[""].devDependencies ) )
    else . end )
  |( .packages[""]|= . + $srcInfo )
' ./package-lock.json > plmin.json;
mv ./plmin.json ./package-lock.json;

$NIX eval --impure --raw $FLAKE_REF#lib --apply '
  lib: let
    metaSet = lib.metaSetFromPlockV3 { lockDir = toString ./.; };
    serial  = metaSet.__serial;
    extra   = { __meta = { inherit (metaSet.__meta) fromType rootKey; }; };
  in lib.librepl.pp ( serial // extra )
';
