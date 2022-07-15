{ lib
, untarSanPerms
, untar
, linkModules
, linkFarm
, stdenv
, buildGyp
}: let

/* -------------------------------------------------------------------------- */

  mkBins = npkgs: key: to: let
    ftPair = n: p: {
      name = "${to}/${n}";
      path = "${npkgs.${key}}/${p}";
    };
    bins = lib.mapAttrsToList ftPair ( npkgs.${key}.meta.bin or {} );
  in bins;

  mkModule = npkgs: key: let
    name = npkgs.${key}.meta.ident or ( dirOf key );
    bname = baseNameOf name;
    version = npkgs.${key}.meta.version or ( baseNameOf key );
    lbin = mkBins npkgs key ".bin";
    nmdir = [{ inherit name; path = npkgs.${key}.built.outPath; }];
    lf = linkFarm "${bname}-${version}-module" ( lbin ++ nmdir );
  in lf // { passthru = ( lf.passthru or {} )
     // { inherit (npkgs.${key}) built; }; };

  mkGlobal = npkgs: key: let
    name = npkgs.${key}.meta.ident or ( dirOf key );
    bname = baseNameOf name;
    version = npkgs.${key}.meta.version or ( baseNameOf key );
    gbin    = mkBins npkgs key "bin";
    gnmdir = [{
      name = "lib/node_modules/${name}";
      path = npkgs.${key}.built.outPath;
    }];
    lf = linkFarm "${bname}-${version}" ( gbin ++ gnmdir );
  in lf // { passthru = ( lf.passthru or {} )
     // { inherit (npkgs.${key}) built; }; };


/* -------------------------------------------------------------------------- */

  mkRegistryPkg = {

  } @ args: let
  in {};


/* -------------------------------------------------------------------------- */

in mkNodePackagae
