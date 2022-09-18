#! /usr/bin/env bash

: "${NIX:=nix}";
: "${MKTEMP:=mktemp}";
: "${CAT:=cat}";
: "${PACOTE:=$NIX run github:aameen-tulip/at-node-nix#pacote --}";
: "${NPM:=$NIX run nixpkgs#nodejs-14_x.pkgs.npm --}";
: "${JQ:=$NIX run nixpkgs#jq --}";

: "${DESCRIPTOR:=@datadog/native-metrics@1.2.0}";

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

# We drop the `devDependencies' field since we really only care about the
# install deps.
# This isn't required; but it cuts out superfulous metadata.
# Additionally we add our `sourceInfo' metadata provided by `pacote' since the
# lockfile will treat it as a regular filepath otherwise ( `/tmp/XXX' ).
$JQ                                                                           \
  --argjson gypfile "$( test -r ./binding.gyp && echo true || echo false; )"  \
  --argjson srcInfo "$( $CAT "$srcInfo"; )"                                   \
' ( .packages|=with_entries( select( .value.dev // false|not ) ) )
  |del( .packages[""].devDependencies )
  |( .packages[""]|= . + $srcInfo )
' ./package-lock.json > plmin.json;
mv ./plmin.json ./package-lock.json;

$NIX eval --impure --raw github:aameen-tulip/at-node-nix#lib --apply '
  lib: let
    metaSet = lib.metaSetFromPlockV3 { lockDir = toString ./.; };
    serial  = metaSet.__serial;
    extra   = { __meta = { inherit (metaSet.__meta) fromType rootKey; }; };
  in lib.librepl.pp ( serial // extra )
';
