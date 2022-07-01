{ lib
, untarSanPerms
, untar
, linkModules
, stdenv
}: let

/* -------------------------------------------------------------------------- */

  withHooks = type: body: let
    up = let
      u = lib.toUpper ( builtins.substring 0 1 type );
    in u + ( builtins.substring 1 ( builtins.stringLength type ) type );
  in "runHook pre${up}\n${body}\nrunHook post${up}";


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
