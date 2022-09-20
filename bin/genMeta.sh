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

_es=0;

usage() {
  {
    echo "Generate a Floco metaSet for an NPM registry tarball";
    echo "USAGE:  genMeta [--dev|-d|--prod|-p] [--json] DESCRIPTOR";
    echo "        genMeta @foo/bar";
    echo "        genMeta --dev @foo/bar@1.0.0";
    echo "ARGUMENTS";
    echo "  DESCRIPTOR   A Node.js package descriptor like '<NAME>@<VERSION>'";
    echo "               or '<PATH>' or '<NAME>' or any other string supported";
    echo "               by NPM/pacote";
    echo "OPTIONS";
    echo "  -p,--prod    Drop devDependencies metadata";
    echo "  -d,--dev     Preserve devDependencies metadata";
    echo "  --json       Output JSON instead of a Nix expression";
    echo "ENVIRONMENT";
    echo "  FLAKE_REF    Flake URI to use for at-node-nix";
    echo "               default: github:aameen-tulip/at-node-nix";
    echo "  The following utilities may be indicated with absolute paths:";
    echo "  NIX MKTEMP CAT PACOTE NPM JQ";
  }
}

while test "$#" -gt 0; do
  case "$1" in
    -d|--dev)  DEV=true;                   ;;
    -p|--prod) DEV=false;                  ;;
    -h|--help) usage; exit 0;              ;;
    --json)    JSON=true; OUT_TYPE=--json; ;;
    *)         DESCRIPTOR="$1";            ;;
  esac
  shift;
done

: "${DEV:=false}";
: "${JSON:=false}";
: "${OUT_TYPE=--raw}";

if test -z "${DESCRIPTOR:-}"; then
  echo "You must provide a package descriptor or identifier" >&2;
  usage;
  exit 1;
fi

dir="$( mktemp -d; )";
srcInfo="$( mktemp; )";
pushd "$dir" >/dev/null || exit 1;
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
  |( if $gypfile then ( .packages[""]|= . + { gypfile: true } ) else . end )
' ./package-lock.json > plmin.json;
mv ./plmin.json ./package-lock.json;

# FIXME: Use this to generate all subtrees.
#needsTree=( $( $JQ -r '
#  ( .packages|with_entries( select( .value as $v|
#      ( ( .key != "" ) and (
#          ( $v.hasInstallScript // false ) or
#          ( ( $v|has( "scripts" ) ) and ( $v.scripts as $s|(
#              ( $s|has( "preprepare" ) )  or
#              ( $s|has( "prepare" ) )     or
#              ( $s|has( "postprepare" ) ) or
#              ( $s|has( "build" ) )
#            ) ) ) ) ) ) )
#  )|keys[]
#' ./package-lock.json|sed 's,.*node_modules/\(\(@[^@/]\+/\)\?[^@/]\+\)$,\1,';
#) );
#
#printf '%s\n' "${needsTree[@]}";

export DEV DESCRIPTOR JSON;
$NIX eval --impure $OUT_TYPE $FLAKE_REF#lib --apply '
  lib: let
    lockDir = toString ./.;
    metaSet = lib.metaSetFromPlockV3 { inherit lockDir; };
    serial  = metaSet.__serial;
    isDev    = builtins.getEnv "DEV" == "true";
    dumpJSON = builtins.getEnv "JSON" == "true";
    trees = let
      mkTree = dev: lib.libtree.idealTreePlockV3 {
        inherit lockDir dev;
        skipUnsupported = false;
      };
      maybeDev = lib.optionalAttrs isDev { dev = mkTree true; };
    in { prod = mkTree false; } // maybeDev;
    __meta  = { inherit (metaSet.__meta) fromType rootKey; inherit trees; };
    data   = serial // { inherit __meta; };
    shellArgs = builtins.concatStringsSep " " [
      ( if isDev then "--dev" else "--prod" )
      ( builtins.getEnv "DESCRIPTOR" )
    ];
    header =
      "# THIS FILE WAS GENERATED. Manual edits may be lost.\n" +
      "# Deserialze with:  lib.libmeta.metaSetFromSerial\n" +
      "# Regen with: nix run --impure at-node-nix#genMeta -- ${shellArgs}\n";
    out = if dumpJSON then data else header + ( lib.librepl.pp data ) + "\n";
  in out
';
