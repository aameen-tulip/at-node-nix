{ lib
, linkModules
, stdenv
}: let

/* -------------------------------------------------------------------------- */

  buildGyp = {
    name                ? "node-gyp-build"
  , src
  , nodejs
  , node-gyp            ? nodejs.pkgs.node-gyp
  , python3
  , dependencies        ? {}
  , gypFlags            ? ["--ensure"]
  , configureFlags      ? []
  , buildFlags          ? []
  , dontLinkNodeModules ? dependencies == {}
  , ...
  } @ attrs: let
    mkDrvAttrs = removeAttrs attrs [
      "nodejs"
      "node-gyp"
      "python3"
      "dependencies"
      "gypFlags"
      "configureFlags"
      "buildFlags"
      "dontLinkNodeModules"
    ];
    depsNm = linkModules { modules = builtins.attrValues dependencies; };
    sf = builtins.concatStringsSep " ";
  in stdenv.mkDerivation ( {
    inherit name src;
    nativeBuildInputs = ( attrs.nativeBuildInputs or [] ) ++ [
      nodejs
      node-gyp
      python3
    ];
    postUnpack = ''
      ln -s -- ${depsNm} ./node_modules
    '';
    configurePhase = lib.withHooks "configure" ''
      node-gyp ${sf gypFlags} configure ${sf configureFlags}
    '';
    buildPhase = lib.withHooks "build" ''
      node-gyp ${sf gypFlags} build ${sf buildFlags}
    '';
    installPhase = lib.withHooks "install" ''
      mv ./build "$out"
    '';
    passthru = { inherit src nodejs dependencies; };
  } // mkDrvAttrs );


/* -------------------------------------------------------------------------- */

in lib.makeOverridable buildGyp
