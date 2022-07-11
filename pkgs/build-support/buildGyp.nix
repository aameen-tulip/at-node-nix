
{ lib, stdenv, xcbuild /* for darwin */ }: let

/* -------------------------------------------------------------------------- */

  # Outputs two targets.
  #   - `out' is the unpacked source tree, where `node-gyp build' has been run.
  #     The `node_modules/' directory is not output - because this may not
  #     be suitable for the `idealTree' expected by `npm' or `yarn'.
  #     XXX: This is placed in a subdirectory `package/' which mimics the layout
  #     of a registry tarball.
  #     The rationale is that if someone adds `propagatedBuildInputs' we don't
  #     want `nix-support' to accidentally appear in the package.
  #     Keep this in mind when converting this tree into a module/global dir.
  #
  #   - `build' is a copy of the `build/' directory after `node-gyp build' has
  #     been run.
  #     You could, in most cases simply symlink this into an unpacked registry
  #     tarball to create an equivalent of `out'.
  #     FIXME: for now I am leaving `out' because I'm not 100% sure that the
  #     "theory" stated here is bullet-proof.
  #     Once this thing gets some more field testing `out' can likely be
  #     removed, and `build' can be symlinked based on platform/arch.
  #
  #   - NOTE: No fixup is performed. This may be a useful addition later.
  buildGyp = {
    name                ? "gyp-pkg"
  , src
  , buildType           ? "Release"
  , nodejs
  , node-gyp            ? nodejs.pkgs.node-gyp
  , python              ? nodejs.python  # python3 in most cases.
  , nodeModules         ? null  # drv to by symlinked as the `node_modules' dir
  , gypFlags            ? ["--ensure" "--nodedir=${nodejs}"]
  , configureFlags      ? []
  , buildFlags          ? []
  , dontLinkNodeModules ? nodeModules == null
  , ...
  } @ attrs: let
    mkDrvAttrs = removeAttrs attrs [
      "nodejs"
      "node-gyp"
      "python"
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
      python
    ] ++ ( lib.optional stdenv.isDarwin xcbuild );
    postUnpack = lib.optionalString ( ! dontLinkNodeModules ) ''
      ln -s -- ${nodeModules} "$sourceRoot/node_modules"
    '';
    configurePhase = lib.withHooks "configure" ''
      export BUILDTYPE="${buildType}"
      node-gyp ${sf gypFlags} configure ${sf configureFlags}
    '';
    buildPhase = lib.withHooks "build" ''
      node-gyp ${sf gypFlags} build ${sf buildFlags}
    '';
    installPhase = lib.withHooks "install" ''
      mkdir -p "$build"
      cp -pr --reflink=auto -- ./build "$build"
      rm -f -- ./node_modules
      cd "$NIX_BUILD_TOP"
      mv -- "$sourceRoot" "$out"
    '';
    passthru = { inherit src nodejs nodeModules; };
  } // mkDrvAttrs );


/* -------------------------------------------------------------------------- */

in lib.makeOverridable buildGyp
