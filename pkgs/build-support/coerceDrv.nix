
# If `src' is already a derivation do nothing.
# If `src' is not a derivation and is a tarball `unpackSafe'.
# If `src' is not a derivaiton and is some other form of source, copy out.
#
# FIXME: `mkDerivation' copies twice which isn't great, but it does provide
# a million other useful helpers like hooks so we're using it.
# Write an `unpackPhase' that avoids double copying AND still patches.
# XXX: Use `pjsUtil'.
#
# FIXME: this can't tell from `builtins.fetchTree { type = "file"; ... }'
# whether a path is a tarball or not because the store path is always `*-source'
# `builtins.fetchurl' on the other hand does work.
# You can probably handle this in `libfetch' more gracefully.

{ lib
, stdenv
, nodejs           # For `patchShebangs'.
, unpackSafe

, name             ? meta.name or src.name or src.meta.name or src
, src
, meta             ? {}
, system           ? stdenv.system
, allowSubstitutes ? ( builtins.currentSystem or null ) != system
, ...
} @ args: let
  drvAttrs = ( removeAttrs args ["lib" "stdenv" "unpackSafe"] ) // {
    inherit name src system allowSubstitutes;
  };
  isTarball = let
    srcName = src.name or src.meta.name or src.outPath or src;
  in lib.test ".*\\.(tar.xz|tar.lzma|txz|tar.*|tgz|tbz2|tbz)" srcName;
in if lib.isDerivation src then src else
   if isTarball then unpackSafe drvAttrs else
   stdenv.mkDerivation ( drvAttrs // {
     dontConfigure = true;
     dontBuild     = true;
     installPhase  = "cp -pr --reflink=auto -- . \"$out\";";
   } )
