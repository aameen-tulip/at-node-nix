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
  , dependencies        ? {}
  , gypFlags            ? ["--ensure" "--nodedir=${untarx nodejs.src}"]
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
      "buildType"
    ];
    depsNm = linkModules { modules = builtins.attrValues dependencies; };
    sf = builtins.concatStringsSep " ";
  in stdenv.mkDerivation ( {
    inherit name src;
    outputs = ["out" "build"];
    nativeBuildInputs = ( attrs.nativeBuildInputs or [] ) ++ [
      nodejs
      node-gyp
      python3
    ];
    buildInputs = lib.optional stdenv.isDarwin xcbuild;
    postUnpack = ''
      ln -s -- ${depsNm} "$sourceRoot/node_modules"
    '';
    configurePhase = lib.withHooks "configure" ''
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
    passthru = { inherit src nodejs dependencies; };
  } // mkDrvAttrs );


/* -------------------------------------------------------------------------- */

in lib.makeOverridable buildGyp
