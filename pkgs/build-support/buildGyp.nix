{ lib
, untarSanPerms
, untar
, linkModules
, stdenv
}: let

/* -------------------------------------------------------------------------- */

  buildGyp = {
    name         ? "node-gyp-build"
  , src
  , nodejs
  , node-gyp     ? nodejs.pkgs.node-gyp
  , python3
  , dependencies ? {}
  , gypFlags     ? []
  , ...
  } @ attrs: let
    mkDrvAttrs = removeAttrs attrs ["node-gyp" "python3" "dependencies"];
  in stdenv.mkDerivation ( {
    inherit name src;
    nativeBuildInputs     = [node-gyp python3];
    propagatedBuildInputs = [nodejs];
  } // mkDrvAttrs );


/* -------------------------------------------------------------------------- */

  in buildGyp
