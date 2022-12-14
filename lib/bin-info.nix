# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  binInfoFromMetaFiles' = { typecheck, ... } @ fenv: metaEnt: let
    mfs      = lib.libmeta.getMetaFiles metaEnt;
    haveInfo = ( mfs ? metaRaw.binInfo ) || ( mfs ? plent ) || ( mfs ? pjs );
    binDir   = mfs.plent.directories.bin or mfs.pjs.directories.bin or null;
    binDir'  = if binDir == null then {} else { inherit binDir; };
    bins     = mfs.plent.bin or mfs.pjs.bin or {};
    bins'    = if bins == null then {} else {
      binPairs = if builtins.isAttrs bins then bins else {
        ${metaEnt.names.bname} = bins;
      };
    };
    rsl = if ! haveInfo then null else
          if mfs ? metaRaw.binInfo then metaEnt.metaRaw.binInfo else
          binDir' // bins';
  in if typecheck
     then ( yt.either yt.nil yt.FlocoMeta.bin_info ) rsl
     else rsl;


# ---------------------------------------------------------------------------- #

  binInfoFromMetaFilesOv' = { typecheck, ... } @ fenv: let
    fn = binInfoFromMetaFiles' fenv;
  in final: prev: if ( fn prev ) == null then {} else {
    binInfo = fn prev;
  };


# ---------------------------------------------------------------------------- #

  _fenvFns = {
    inherit
      binInfoFromMetaFiles'
      binInfoFromMetaFilesOv'
    ;
  };


# ---------------------------------------------------------------------------- #

in {

  inherit
    binInfoFromMetaFiles'
    binInfoFromMetaFilesOv'
  ;

  __withFenv = fenv: let
    cw  = builtins.mapAttrs ( _: lib.callWith fenv ) _fenvFns;
    app = let
      proc = acc: name: acc // {
        ${lib.yank "(.*)'" name} = lib.apply _fenvFns.${name} fenv;
      };
    in builtins.foldl' proc {} ( builtins.attrNames _fenvFns );
  in cw // app;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
