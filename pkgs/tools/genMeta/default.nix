# ===========================================================================- #
#
# Generates `metaSet' file from a package descriptor.
# Particularly useful for generating flakes for registry tarballs with
# install scripts since these rarely need to be dynamically generated.
# NOTE: This isn't really recommended for projects that are under active
#       development ( because their lockfiles change frequently ).
#
#
# ---------------------------------------------------------------------------- #

{ runCommandNoCC
, nix
, coreutils
, jq
, makeWrapper
, pacote
, nodejs-14_x
, npm          ? nodejs-14_x.pkgs.npm
, flakeRef     ? "github:aameen-tulip/at-node-nix"
}: runCommandNoCC "genMeta" {
  _SCRIPT  = builtins.path { path = ../../../bin/genMeta.sh; };
  NIX      = "${nix}/bin/nix";
  MKTEMP   = "${coreutils}/bin/mktemp";
  CAT      = "${coreutils}/bin/cat";
  REALPATH = "${coreutils}/bin/realpath";
  PACOTE   = "${pacote}/bin/pacote";
  NPM      = "${nodejs-14_x.pkgs.npm}/bin/npm";
  JQ       = "${jq}/bin/jq";
  WC       = "${coreutils}/bin/wc";
  CUT      = "${coreutils}/bin/cut";
  nativeBuildInputs = [makeWrapper];
} ''
  mkdir -p "$out/bin";
  cp "$_SCRIPT" "$out/bin/genMeta";
  wrapProgram "$out/bin/genMeta"         \
    --set-default FLAKE_REF ${flakeRef}  \
    --set-default NIX       "$NIX"       \
    --set-default MKTEMP    "$MKTEMP"    \
    --set-default CAT       "$CAT"       \
    --set-default REALPATH  "$REALPATH"  \
    --set-default PACOTE    "$PACOTE"    \
    --set-default NPM       "$NPM"       \
    --set-default JQ        "$JQ"        \
    --set-default WC        "$WC"        \
    --set-default CUT       "$CUT"       \
  ;
''


# ---------------------------------------------------------------------------- #
#
#
#
# ===========================================================================- #
