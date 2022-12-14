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

: "${EXTRA_NPM_FLAGS:=}";
: "${EXTRA_NIX_FLAGS:=}";
: "${LOCKFILE:=}";

_es=0;
SPATH="$( $REALPATH ${BASH_SOURCE[0]}; )";
SDIR="${SPATH%/*}";

if test -r "$SDIR/../flake.lock"; then
  : "${FLAKE_REF:=${SDIR%/bin}}";
else
  : "${FLAKE_REF:=github:aameen-tulip/at-node-nix}";
fi

_as_me="${SPATH##*/}";
case "$_as_me" in
  .*-wrapped) _as_me="${_as_me#.}"; _as_me="${_as_me%-wrapped}"; ;;
  *) :; ;;
esac


# ---------------------------------------------------------------------------- #

usage() {
  $CAT <<EOF
Generate a Floco metaSet for an NPM registry tarball
USAGE:  genMeta [--dev|-d|--prod|-p] [--json] (DESCRIPTOR|[--lockfile] LOCKFILE)
        genMeta @foo/bar
        genMeta --dev @foo/bar@1.0.0
ARGUMENTS
  DESCRIPTOR  A Node.js package descriptor like '<NAME>@<VERSION>' or '<PATH>'
              or '<NAME>' or any other string supported by NPM/pacote.
  LOCKFILE    A 'package-lock.json' file to convert to 'meta.{json,nix}'.
OPTIONS
  -p,--prod       Drop devDependencies metadata     ( default for registry )
  -d,--dev        Preserve devDependencies metadata ( default for local tree )
  --json          Output JSON instead of a Nix expression
  -K,--keep       Keep generated project dir"
  -S,--no-256     Skip attempts to collect sha256 for tarballs.
                  Use this to workaround 'permission denied package/*'
  -l,--lockfile   Use the given lockfile instead of generating one
ENVIRONMENT
  EXTRA_NPM_FLAGS Passes additional flags to NPM when generating locks
  EXTRA_NIX_FLAGS Passes additional flags to NIX when generating metaSet
  FLAKE_REF       Flake URI to use for at-node-nix
                  default: github:aameen-tulip/at-node-nix
  The following utilities may be indicated with absolute paths:
    NIX MKTEMP CAT REALPATH PACOTE NPM JQ WC CUT
EOF
}


# ---------------------------------------------------------------------------- #

# Parse Args

while test "$#" -gt 0; do
  case "$1" in
    -d|--dev)          DEV=true;                   ;;
    -p|--prod)         DEV=false;                  ;;
    -h|--help)         usage; exit 0;              ;;
    --json)            JSON=true; OUT_TYPE=--json; ;;
    -k|--keep)         KEEP_TREE=:;                ;;
    -S|-no-256)        DO_SHA256=false;            ;;
    -l|--lockfile|*/package-lock.json)
      if test -n "${DESCRIPTOR:-}"; then
        echo "$_as_me: You may only provide a descriptor, or a lockfile" >&2;
        usage >&2;
        exit 1;
      fi
      if test -n "${LOCKFILE:-}"; then
        echo "$_as_me: You may only process one lockfile" >&2;
        usage >&2;
        exit 1;
      fi
      case "$1" in
        */package-lock.json) :; ;;
        *) shift; ;;
      esac
      if test -d "$1"; then
        LOCKFILE="$1/package-lock.json";
      else
        LOCKFILE="$1";
      fi
      if ! test -r "$LOCKFILE"; then
        echo "$_as_me: Cannot read file '$LOCKFILE'" >&2;
        exit 1;
      fi
    ;;
    *)
      if test -z "${DESCRIPTOR:-}" && test -z "${LOCKFILE:-}"; then
        DESCRIPTOR="$1";
      else
        if test -n "${DESCRIPTOR:-}"; then
          echo "$_as_me: You may only process one lockfile" >&2;
        else
          echo "$_as_me: You may only provide a descriptor, or a lockfile" >&2;
        fi
        usage >&2;
        exit 1;
      fi
    ;;
  esac
  shift;
done

: "${DO_SHA256:=true}";
: "${KEEP_TREE:=}";
: "${JSON:=false}";
: "${OUT_TYPE=--raw}";

if test -z "${DESCRIPTOR:-}" && test -z "${LOCKFILE:-}"; then
  echo "You must provide a package descriptor/identifier or lockfile" >&2;
  usage >&2;
  exit 1;
fi

# Make any pathlike descriptors absolute
case "${DESCRIPTOR:-__LOCAL}" in
  __LOCAL) : "${DEV:=true}"; ;;
  *@*)    : "${DEV:=false}"; ;;
  /*)     : "${DEV:=false}"; ;;
  .*|*/*/*)
    DESCRIPTOR="$( $REALPATH "$DESCRIPTOR"; )";
    : "${DEV:=true}";
  ;;
  *)
    if test -r "$DESCRIPTOR/package.json"; then
      if $PACOTE resolve "$DESCRIPTOR" >/dev/null 2>&1; then
        echo "'$DESCRIPTOR' could a path, or registry module." >&2;
        read -n 1 -p 'Did you mean to refer to the local path?[Yn] ';
        case "$REPLY" in
          N*|n*) : "${DEV:=false}"; ;;
          *)
            DESCRIPTOR="$( $REALPATH "$DESCRIPTOR"; )";
            : "${DEV:=true}";
          ;;
        esac
      fi
    else
      : "${DEV:=false}";
    fi
  ;;
esac


# ---------------------------------------------------------------------------- #

# Used for both descriptors and existing lockfiles
_PLMIN="$( $MKTEMP; )";
_FETCH_INFO="$( $MKTEMP; )";


# Only when we need to generate a lockfile from a descriptor.
setup_tmp() {
  trap '_es="$?"; cleanup_gen; exit "$_es";' HUP TERM EXIT INT QUIT;
  _TDIR="$( $MKTEMP -d; )";
  _MANIFEST="$( $MKTEMP; )";
  pushd "$_TDIR" >/dev/null || exit 1;
}

# Cleanup temporary files associated with `setup_tmp'.
cleanup_gen() {
  if test -n "${KEEP_TREE:-}"; then
    {
      echo "Keeping generated tree at:";
      echo "$_TDIR";
    } >&2;
    mv -f "$_FETCH_INFO" "$_TDIR/fetchInfo.json";
    mv -f "$_MANIFEST" "$_TDIR/manifest.json";
  else
    popd >/dev/null;
    rm -rf "$_TDIR" "$_FETCH_INFO" "$_MANIFEST" "$_PLMIN";
  fi
}

cleanup_have() {
  rm -f "$_PLMIN" "$_FETCH_INFO";
  # Restore backup file.
  if test -n "${_LOCKFILE_BAK:-}" && test -r "$_LOCKFILE_BAK"; then
    mv "$_LOCKFILE_BAK" "$LOCKFILE";
  fi
}


# ---------------------------------------------------------------------------- #

# Pacote's manifest info here is not exactly what we expect in a `plent'.
# We normalize it here so that routines designed to detect "fetcher family",
# "lifecycle type", etc will work as expected.
#
# Pacote manifest for a project in `PWD'.
#   {
#     "resolved": "/tmp/project",
#     "integrity": "sha512-Kco2/...",
#     "from": "file:/tmp/project"
#   }
pacote_extract() {
  # We stash the output of `pacote' which contains `fetchInfo' fields.
  $PACOTE extract "$DESCRIPTOR" . --json 2>/dev/null > "$_MANIFEST"||
    $PACOTE extract "$DESCRIPTOR" . --json;
}

manifest_to_fetch_info() {
  $JQ '{ integrity: .integrity } +
  ( .resolved as $resolved|
    ( if ( .from|test( "^file:\($resolved)" ) ) then {}
                                                else { resolved: $resolved }
      end )
  )' "$_MANIFEST" > "$_FETCH_INFO";
}


# ---------------------------------------------------------------------------- #

create_lockfile() {
  # Produce a lockfile
  NPM_CONFIG_LOCKFILE_VERSION=3  \
    $NPM install                 \
      --package-lock-only        \
      --ignore-scripts           \
      --legacy-peer-deps         \
      $EXTRA_NPM_FLAGS           \
    >/dev/null;
  LOCKFILE="$PWD/package-lock.json";
}


# ---------------------------------------------------------------------------- #

jq_fail_dump_data() {
  {
    echo '';
    echo "'jq' Failed given the following data:";
    echo "  --argjson gypfile: $_HAS_GYPFILE";
    echo "  --argjson fetchInfo: '$( $CAT "$_FETCH_INFO"; )'";
    echo "  --argjson dev: $DEV";
    echo '';
    if test "$( $WC -l "${LOCKFILE?}"|$CUT -d' ' -f1; )" -gt 100; then
      echo "Package Lock is too long to dump."
      echo "Run again with '--keep-tree' and poke around for yourself.";
    else
      echo "Package Lock was:"
      $CAT "$LOCKFILE" >&2;
    fi
    echo "Descriptor was: '$DESCRIPTOR'";
    echo "Good luck debugging <3";
  } >&2;
  exit 1;
}


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
#
# Lets go!
#
# ---------------------------------------------------------------------------- #

if test -n "${DESCRIPTOR:-}"; then
  echo "Generating NPM Lockfile" >&2;
  setup_tmp;
  pacote_extract;
  manifest_to_fetch_info;
  create_lockfile;
else
  echo "Using existing NPM Lockfile: $LOCKFILE" >&2;
  echo '{}' > "$_FETCH_INFO";
  trap '_es="$?"; cleanup_have; exit "$_es";' HUP TERM EXIT INT QUIT;
fi


_HAS_GYPFILE=;
if test -r "${LOCKFILE%/*}/binding.gyp"; then
  _HAS_GYPFILE=true;
else
  _HAS_GYPFILE=false;
fi


# ---------------------------------------------------------------------------- #

# Unless `--dev' is provided, we drop the `devDependencies' field since we
# really only care about the install deps.
# This isn't required; but it cuts out superfulous metadata.
# Additionally we add our `fetchInfo' metadata provided by `pacote' since the
# lockfile will treat it as a regular filepath otherwise ( `/tmp/XXX' ).
$JQ                                                    \
  --argjson gypfile   "$_HAS_GYPFILE"                  \
  --argjson fetchInfo "$( $JQ -c . "$_FETCH_INFO"; )"  \
  --argjson dev       "$DEV"                           \
'( if ( $dev|not ) then
     ( ( .packages|=with_entries( select( .value.dev // false|not ) ) )
       |del( .packages[""].devDependencies ) )
   else . end )
 |( .packages[""]|= . + $fetchInfo )
 |( if $gypfile then ( .packages[""]|= . + { gypfile: true } ) else . end )
' "$LOCKFILE" > "$_PLMIN"||jq_fail_dump_data;

# Create a backup of our lock if we're using an existing one.
if test -z "${DESCRIPTOR:-}"; then
  _LOCKFILE_BAK="$( $MKTEMP; )";
  cp -pr -- "$LOCKFILE" "$_LOCKFILE_BAK";
fi

# Use minimal lockfile
mv "$_PLMIN" "$LOCKFILE";


# ---------------------------------------------------------------------------- #

# Generate the `metaSet', and serialize it.

# FIXME: there's a rare edge case where a devDependency is a symlink and we are
# operating in `--prod' mode.
# The `packages."node_modules/..." = { link = true; resolved = "..."; }' entry
# is written, but there is no associated key for the resolved path.
# This should get patched in `lib.libplock', but for now we just kill those.

: "${DESCRIPTOR:=$LOCKFILE}";  # Trust me it's just for logging the CLI args.

if test "$DO_SHA256" = true; then
  {
    $CAT <<EOF

$_as_me: Analyzing tarballs to optimize fetchers.
sha-256 NAR hashes will be collected to select the fastest tarball fetcher.
This process is somewhat slow, but it improves performance for your "real build"
by allowing Nix's builtin libarchive routine.

This process can be skipped by setting '--no-256' or '-S'.
The results of these checks are "good forever", and don't need to be rerun.
Nix will store the results of these tests in the Nix store until the garbage
collector cleans them, so you after your first batch it's downhill from there.
EOF
    } >&2;
fi


# Make absolute if possible
if test -r "$FLAKE_REF"; then
  FLAKE_REF="$( $REALPATH $FLAKE_REF; )";
fi
export DEV DESCRIPTOR JSON DO_SHA256 LOCKFILE;
export FLAKE_REF EXTRA_NPM_FLAGS EXTRA_NIX_FLAGS;
$NIX eval --impure $EXTRA_NIX_FLAGS $OUT_TYPE  \
  $FLAKE_REF#legacyPackages --apply '
  lp: let
    pkgsFor = lp.${builtins.currentSystem};
    inherit (pkgsFor) lib;

    # Yank args from ENV vars.
    flakeRef = builtins.getEnv "FLAKE_REF";
    do256    = ( builtins.getEnv "DO_SHA256" ) == "true";
    dumpJSON = builtins.getEnv "JSON" == "true";
    isDev    = ( builtins.getEnv "DEV" ) == "true";
    lockPath = builtins.getEnv "LOCKFILE";
    plock    = lib.importJSON lockPath;
    lockDir  = dirOf lockPath;
    exNix    = builtins.getEnv "EXTRA_NIX_FLAGS";
    exNpm    = builtins.getEnv "EXTRA_NPM_FLAGS";

    # If DEV is set, kill any dev deps in lock.
    plockND = plock // {
      packages = let
        prods = lib.filterAttrs ( _: v: ! ( v.dev or false ) ) plock.packages;
        ddfs  = builtins.mapAttrs ( _: v: removeAttrs v ["devDependencies"] )
                                  prods;
        linkMissing = k: v:
          ( v.link or false ) && ( ! ( prods ? ${v.resolved} ) );
      in lib.filterAttrs ( k: v: ! ( linkMissing k v ) ) ddfs;
    };

    # Generate a metaSet
    metaSet = lib.metaSetFromPlockV3 {
      inherit lockDir;
      plock        = if isDev then plock else plockND;
      pure         = false;
      ifd          = true;
      allowedPaths = [lockDir];
      typecheck    = true;
    };

    # Prep metadata for export/serialization
    serial = let
      base = metaSet.__serial;
      prepEnt = ent: let
        for256 = e: if ( e.fetchInfo.type or null ) == "file" then e // {
          fetchInfo = pkgsFor.urlFetchInfo e.fetchInfo.url;
        } else if ( e.fetchInfo.type or null ) == "path" then e // {
          fetchInfo = e.fetchInfo // {
            path = if e.fetchInfo.path == lockDir then "./." else
                   builtins.replaceStrings [lockDir] ["."] e.fetchInfo.path;
          };
        } else e;
        # Optimize fetchInfo if DO_SHA256 is set
        optFi = if do256 then for256 else ( x: x );
        dropJunk = e: removeAttrs e ["scoped"];
      in dropJunk ( optFi ent );
    in builtins.mapAttrs ( _: prepEnt ) base;

    # Add metadata about the node_modules/ tree.
    rootEntWithTrees = {
      ${metaSet._meta.rootKey} = serial.${metaSet._meta.rootKey} // {
        treeInfo = let
          mkTree = dev: lib.libtree.idealTreePlockV3 {
            inherit lockDir dev metaSet;
            skipUnsupported = false;
          };
          maybeDev = lib.optionalAttrs isDev { dev = mkTree true; };
        in { prod = mkTree false; } // maybeDev;
      };
    };

    # Stash extra info in an "internal" attribute
    _meta  = {
      inherit (metaSet._meta) fromType rootKey;
    };

    # Finalize data to be written
    data = serial // rootEntWithTrees // { inherit _meta; };

    # For Nix output put a header at the top of the file with instructions
    # on how to regenerate.
    header = let
      shellArgs = builtins.concatStringsSep " " ( [
          ( if isDev then "--dev" else "--prod" )
          ( builtins.getEnv "DESCRIPTOR" )
        ] ++ ( lib.optional do256 "--no-256" )
      );
      lk  = builtins.getFlake flakeRef;
      rev = if lk.sourceInfo ? rev then "/" + lk.sourceInfo.rev else "";
      fr  = if lib.isStorePath flakeRef
            then "github:aameen-tulip/at-node-nix${rev}"
            else flakeRef;
      exl = ( lib.optional ( exNix != "" ) "EXTRA_NIX_FLAGS=${exNix}" ) ++
            ( lib.optional ( exNpm != "" ) "EXTRA_NPM_FLAGS=${exNpm}" ) ++
            ["nix run --impure ${fr}#genMeta -- ${shellArgs}"];
      cmd = builtins.concatStringsSep " " exl;
    in "# THIS FILE WAS GENERATED. Manual edits may be lost.\n" +
       "# Deserialze with:  lib.metaSetFromSerial\n" +
       "# Regen with: ${cmd}\n";
    forNix = let
      prettyNoEsc = lib.generators.toPretty { allowPrettyValues = false; } data;
      pretty = builtins.replaceStrings [
        " assert = "  " with = " " let = " " in = " " or = "
        " inherit = " " rec = "
      ] [
        " \"assert\" = "  " \"with\" = " " \"let\" = " " \"in\" = " " \"or\" = "
        " \"inherit\" = " " \"rec\" = "
      ] prettyNoEsc;
    in header + pretty + "\n";
    out = if dumpJSON then data else forNix;
  in out
'||advise_fail;


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
