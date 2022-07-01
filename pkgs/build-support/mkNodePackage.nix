{ lib
, untarSanPerms
, untar
, linkModules
, stdenv
, buildGyp
}: let

/* -------------------------------------------------------------------------- */

  mkNodePackage = {
    name
  , src
  , global      ? false
  , pjs         ? args.meta.pjs or null
  , meta        ? if args ? pjs then { inherit pjs; } else {}
  , skipInstall ? false  # You almost always want to skip in practice.
  , nodejs
  , ...
  } @ args: let
  in {};


/* -------------------------------------------------------------------------- */

in mkNodePackagae
