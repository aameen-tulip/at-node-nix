#! /usr/bin/env bash
# ============================================================================ #

: "${NIX:=nix}";
: "${MKTEMP:=mktemp}";
: "${CAT:=cat}";
: "${REALPATH:=$NIX run nixpkgs#coreutils -- --coreutils-prog=realpath};"
: "${PACOTE:=$NIX run github:aameen-tulip/at-node-nix#pacote --}";
: "${NPM:=$NIX run nixpkgs#nodejs-14_x.pkgs.npm --}";
: "${JQ:=$NIX run nixpkgs#jq --}";
: "${WC:=wc}";
: "${CUT:=cut}";

: "${FLAKE_REF:=github:aameen-tulip/at-node-nix}";

_es=0;


# ---------------------------------------------------------------------------- #

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
    echo "  -K,--keep    Keep generated project dir"
    echo "  -S,--no-256  Skip attempts to collect sha256 for tarballs.";
    echo "               Use this to workaround 'permission denied package/*'.";
    echo "ENVIRONMENT";
    echo "  FLAKE_REF    Flake URI to use for at-node-nix";
    echo "               default: github:aameen-tulip/at-node-nix";
    echo "  The following utilities may be indicated with absolute paths:";
    echo "  NIX MKTEMP CAT PACOTE NPM JQ";
  }
}


# ---------------------------------------------------------------------------- #

# Parse Args

while test "$#" -gt 0; do
  case "$1" in
    -d|--dev)   DEV=true;                   ;;
    -p|--prod)  DEV=false;                  ;;
    -h|--help)  usage; exit 0;              ;;
    --json)     JSON=true; OUT_TYPE=--json; ;;
    -k|--keep)  KEEP_TREE=:;                ;;
    -S|-no-256) DO_SHA256=false;            ;;
    *)          DESCRIPTOR="$1";            ;;
  esac
  shift;
done

: "${DO_SHA256:=true}";
: "${KEEP_TREE:=}";
: "${DEV:=false}";
: "${JSON:=false}";
: "${OUT_TYPE=--raw}";

if test -z "${DESCRIPTOR:-}"; then
  echo "You must provide a package descriptor or identifier" >&2;
  usage;
  exit 1;
fi

# Make any pathlike descriptors absolute
case "$DESCRIPTOR" in
  *@*)   :; ;;
  /*)    :; ;;
  .*|*/*/*) DESCRIPTOR="$( $REALPATH "$DESCRIPTOR"; )"; ;;
  *)
    if test -r "$DESCRIPTOR/package.json"; then
      if $PACOTE resolve "$DESCRIPTOR" >/dev/null 2>&1; then
        echo "'$DESCRIPTOR' could a path, or registry module." >&2;
        read -n 1 -p 'Did you mean to refer to the local path?[Yn] ';
        case "$REPLY" in
          N*|n*) :; ;;
          *) DESCRIPTOR="$( $REALPATH "$DESCRIPTOR"; )"; ;;
        esac
      fi
    fi
  ;;
esac


# ---------------------------------------------------------------------------- #

dir="$( $MKTEMP -d; )";
srcInfo="$( $MKTEMP; )";
pushd "$dir" >/dev/null || exit 1;

cleanup() {
  if test -n "${KEEP_TREE:-}"; then
    {
      echo "Keeping generated tree at:";
      echo "$dir";
    } >&2;
    mv -f "$srcInfo" "$dir/sourceInfo.json";
  else
    popd >/dev/null;
    rm -rf "$dir" "$srcInfo";
  fi
}
trap '_es="$?"; cleanup; exit "$_es";' HUP TERM EXIT INT QUIT;


# ---------------------------------------------------------------------------- #

# We stash the output of `pacote' which contains `sourceInfo' fields.
$PACOTE extract "$DESCRIPTOR" . --json 2>/dev/null|$JQ -c > "$srcInfo";

# Produce a lockfile
NPM_CONFIG_LOCKFILE_VERSION=3                                    \
  $NPM install --package-lock-only --ignore-scripts >/dev/null;

_HAS_GYPFILE=;
if test -r ./binding.gyp; then
  _HAS_GYPFILE=true;
else
  _HAS_GYPFILE=false;
fi


# ---------------------------------------------------------------------------- #

jq_fail_dump_data() {
  {
    echo '';
    echo "JQ Failed given the following data:";
    echo "  --argjson gypfile: $_HAS_GYPFILE";
    echo "  --argjson srcInfo: '$( $CAT "$srcInfo"; )'";
    echo "  --argjson dev: $DEV";
    echo '';
    if test "$( $WC -l ./package-lock.json|$CUT -d' ' -f1; )" -gt 100; then
      echo "Package Lock is too long to dump."
      echo "Run again with '--keep-tree' and poke around for yourself.";
    else
      echo "Package Lock was:"
      $CAT ./package-lock.json;
    fi
    echo "Descriptor was: '$DESCRIPTOR'";
    echo "Good luck debugging <3";
  } >&2;
  exit 1;
}


# ---------------------------------------------------------------------------- #

# Unless `--dev' is provided, we drop the `devDependencies' field since we
# really only care about the install deps.
# This isn't required; but it cuts out superfulous metadata.
# Additionally we add our `sourceInfo' metadata provided by `pacote' since the
# lockfile will treat it as a regular filepath otherwise ( `/tmp/XXX' ).
$JQ                                          \
  --argjson gypfile "$_HAS_GYPFILE"          \
  --argjson srcInfo "$( $CAT "$srcInfo"; )"  \
  --argjson dev     "$DEV"                   \
' ( if ( $dev|not ) then
      ( ( .packages|=with_entries( select( .value.dev // false|not ) ) )
        |del( .packages[""].devDependencies ) )
    else . end )
  |( .packages[""]|= . + $srcInfo )
  |( if $gypfile then ( .packages[""]|= . + { gypfile: true } ) else . end )
' ./package-lock.json > plmin.json||jq_fail_dump_data;
mv ./plmin.json ./package-lock.json;


# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #

advise_fail() {
  {
    echo '';
    echo 'Nix encountered an error generating metadata.';
    echo '';
    if test "$DO_SHA256" = true; then
      echo "If you received a 'Permission denied' error this means that you";
      echo 'depend on a tarball encoded with bullshit directory entries';
      echo "produced by some author using a bogus 'gzip' implementation.";
      echo '';
      echo "To work around this you can use the flag '--no-256' or '-S' to";
      echo "generate entries without 'narHash' or 'gypfile' hints.";
      echo "This will likely mean that you need to use 'flocoUnpack' in your";
      echo 'build pipeline if you have written one manually.';
      echo '';
      echo "It is strongly recommended that you manually fill 'gypfile' fields";
      echo "for any registry tarballs recorded with 'hasInstallScript' info.";
      echo '';
    fi
    echo 'If you were trying to fetch private packages you may need to setup';
    echo 'special authorization for Nix providing any NPM, GitHub, or other';
    echo "access tokens to in 'nix.conf: access-tokens = ...', and 'netrc'.";
    echo "For more info refer to the Nix manual's 'nix.conf' section."
    echo '';
  } >&2;
}


# ---------------------------------------------------------------------------- #

export DEV DESCRIPTOR JSON DO_SHA256;
$NIX eval --impure $OUT_TYPE $FLAKE_REF#legacyPackages --apply '
  lp: let
    pkgsFor = lp.${builtins.currentSystem}.extend ( final: prev: {
      # FIXME: needed because of some bullshit tarballs with bad compression.
      # This really fucks out ability to scrape SHA-256 hashes.
      # TODO: write a wrapper routine to collect those, essentially a try/catch,
      # that tries fetchTree and falls back to unpackSafe + builtins.path.
      lib = prev.lib.extend ( _: libPrev: {
        flocoConfig = libPrev.flocoConfig // {
          enableImpureMeta     = true;
          enableImpureFetchers = builtins.getEnv "DO_SHA256" == "true";
          fetchers = {
            tarballFetcher = libPrev.libfetch.fetchurlNoteUnpackDrvW;
          };
        };
      } );
    } );
    inherit (pkgsFor) lib;
    lockDir  = toString ./.;
    metaSet  = lib.metaSetFromPlockV3 { inherit lockDir; };
    serial   = metaSet.__serial;
    isDev    = builtins.getEnv "DEV" == "true";
    dumpJSON = builtins.getEnv "JSON" == "true";
    trees = let
      mkTree = dev: lib.libtree.idealTreePlockV3 {
        inherit lockDir dev;
        skipUnsupported = false;
      };
      maybeDev = lib.optionalAttrs isDev { dev = mkTree true; };
    in { prod = mkTree false; } // maybeDev;
    __meta  = {
      inherit (metaSet.__meta) fromType rootKey;
      inherit trees;
    };
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
'||advise_fail;


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
