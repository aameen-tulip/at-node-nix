
# If `src' is already a derivation do nothing.
# If `src' is not a derivation and is a packed archive/tarball `unpackSafe'.
# If `src' is not a derivaiton and is some other form of source, copy out.
#
# NOTE: If we aren't sure whether a `src' is archived or not, err on the side
# of `stdenv.mkDerivation' - the unpack routine there will cover either case.
# The only downside is that you waste time copying redundantly.

{ lib
, stdenv
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
  needsUnpack = let
    srcName = src.name or src.meta.name or ( toString src );
    byName  = lib.test ".*\\.(tar.xz|tar.lzma|txz|tar.*|tgz|tbz2|tbz)" srcName;
    byType  = ( src.type or src.fetchInfo.type or null ) == "file";
  in byName || byType;
in if needsUnpack then unpackSafe drvAttrs else
   if lib.isDerivation src then src else stdenv.mkDerivation ( drvAttrs // {
     dontConfigure = true;
     dontBuild     = true;
     installPhase  = ''
       pjsAddMod . "$out";
     '';
     preferLocal = true;
   } )
