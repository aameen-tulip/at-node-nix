{ lib
, linkModules
, stdenv
, untar
, xz
, xcbuild  # Darwin only
}: let

/* -------------------------------------------------------------------------- */

  # The Node.js sources use `.tar.xz' so we need to add `xz' to `untar'.
  untarx = tarball: untar { inherit tarball; extraPkgs = [xz]; };


/* -------------------------------------------------------------------------- */

  buildGyp = {
    name                ? "gyp-pkg"
  , src
  , buildType           ? "Release"
  , nodejs
  , node-gyp            ? nodejs.pkgs.node-gyp
  , python3
  , nodeModules         ? null  # drv to by symlinked as the `node_modules' dir
  , gypFlags            ? ["--ensure" "--nodedir=${untarx nodejs.src}"]
  , configureFlags      ? []
  , buildFlags          ? []
  , dontLinkNodeModules ? nodeModules == null
  , ...
  } @ attrs: let
    mkDrvAttrs = removeAttrs attrs [
      "nodejs"
      "node-gyp"
      "python3"
      "nodeModules"
      "gypFlags"
      "configureFlags"
      "buildFlags"
      "dontLinkNodeModules"
      "buildType"
    ];
    sf = builtins.concatStringsSep " ";
  in stdenv.mkDerivation ( {
    inherit name src;
    outputs = ["out" "build"];
    nativeBuildInputs = ( attrs.nativeBuildInputs or [] ) ++ [
      nodejs
      node-gyp
      python3
    ];
    buildInputs = ( attrs.buildInputs or [] ) ++
                  ( lib.optional stdenv.isDarwin xcbuild );
    postUnpack = lib.optionalString ( ! dontLinkNodeModules ) ''
      ln -s -- ${nodeModules} "$sourceRoot/node_modules"
    '';
    configurePhase = lib.withHooks "configure" ''
      ls
      ls ./node_modules
      ls ./node_modules/**/*
      export BUILDTYPE="${buildType}"
      node-gyp ${sf gypFlags} configure ${sf configureFlags}
    '';
    buildPhase = lib.withHooks "build" ''
      node-gyp ${sf gypFlags} build ${sf buildFlags}
    '';
    installPhase = lib.withHooks "install" ''
      cp -pr --reflink=auto -- "./build/${buildType}" "$out"
      mv -- ./build "$build"
    '';
    passthru = { inherit src nodejs nodeModules; };
  } // mkDrvAttrs );


/* -------------------------------------------------------------------------- */

in lib.makeOverridable buildGyp
