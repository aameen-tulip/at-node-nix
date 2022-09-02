# ============================================================================ #
#
# Adds sane defaults for building misc derivations 'round these parts.
# These defaults are largely aimed for the convenience of local/iterative dev.
# These are NOT what you want a `flake.nix' to fall-back onto - because you
# will not get the advantage of Nix's eval cache.
#
# From a `flake.nix' you want to explicitly pass in every argument to ensure
# no "impure" procedures like `currentSystem', `getEnv', `getFlake', etc run.
#
# ---------------------------------------------------------------------------- #

{ nixpkgs ? builtins.getFlake "nixpkgs"
, system  ? builtins.currentSystem
, pkgs    ? import nixpkgs { inherit system config; }
, config  ? { contentAddressedByDefault = false; }
, ak-nix  ? builtins.getFlake "github:aakropotkin/ak-nix/main"
, lib     ? import ../lib { inherit (ak-nix) lib; }
, nodejs  ? pkgs.nodejs-14_x
, ...
}: let

# ---------------------------------------------------------------------------- #

  # This is placed outside of scope to prevent overrides.
  # Don't override its `bash' and `coreutils' args.
  snapDerivation = import ./make-derivation-simple.nix {
    inherit (pkgs) bash coreutils;
    inherit (config) contentAddressedByDefault;
    inherit system;
  };

  # Similar to `snapDerivation', these are minimal derivations used to do things
  # like "make symlink", (un)zip a tarball, etc.
  # Don't override them.
  trivial = ak-nix.trivial.${system};
  # This inherit block is largely for the benefit of the reader.
  inherit (trivial)
    runLn
    linkOut
    linkToPath
    runTar
    untar
    tar
    untarSanPerms
    copyOut
  ;


  #patch-shebangs = pkgs.callPackage ./build-support/patch-shebangs.nix {};

  pacote =
    ( import ./development/node-packages/pacote { inherit pkgs; } ).package;

  inherit ( import ./tools/floco/pacote.nix { inherit pkgs pacote; } )
    pacotecli
  ;

  buildGyp = import ./build-support/buildGyp.nix {
    inherit lib nodejs;
    inherit (pkgs) stdenv xcbuild jq pkg-config;
  };

  _mkNodeTarball = import ./build-support/mkNodeTarball.nix {
    inherit lib linkToPath untar tar pacotecli;
    inherit (pkgs) linkFarm;
  };

  _fetcher = import ./build-support/fetcher.nix {
    inherit lib;
    inherit (pkgs) fetchurl fetchgit fetchzip;
  };

  evalScripts = import ./build-support/evalScripts.nix {
    inherit lib nodejs;
    inherit (pkgs) stdenv jq;
  };

  runInstallScripts = args: let
    installed = evalScripts ( {
      runScripts  = ["preinstall" "install" "postinstall"];
      skipMissing = true;
    } // args );
    warnMsg = "WARNING: " +
              "attempting to run installation scripts on a package which " +
              "uses `node-gyp' - you likely want to use `buildGyp' instead.";
    maybeWarn = x:
      if ( args.gypfile or args.meta.gypfile or false ) then
        ( builtins.trace warnMsg x ) else x;
  in maybeWarn installed;

  genericInstall = import ./build-support/genericInstall.nix {
    inherit lib buildGyp evalScripts nodejs;
    inherit (pkgs) stdenv jq xcbuild;
  };

  runBuild = import ./build-support/runBuild.nix {
    inherit lib evalScripts nodejs;
    inherit (pkgs) stdenv jq;
  };


# ---------------------------------------------------------------------------- #

in ( pkgs.extend ak-nix.overlays.default ).extend ( final: prev: let

  callPackage  = lib.callPackageWith final;
  callPackages = lib.callPackagesWith final;

  _node-pkg-set = callPackages ./node-pkg-set.nix {
    fetchurl = lib.fetchurlDrv;  # For tarballs without unpacking
    doFetch = _fetcher.fetcher {
      cwd = throw "Override `cwd' to use local fetchers";  # defer to call-site
      preferBuiltins = true;
    };
  };

# ---------------------------------------------------------------------------- #

in {
  inherit
    snapDerivation
    trivial
    lib
    pacote
    pacotecli
    buildGyp
    evalScripts
    runInstallScripts
    genericInstall
    runBuild
  ;
  inherit (trivial)
    runLn
    linkOut
    linkToPath
    runTar
    untar
    tar
  ;
  inherit (_mkNodeTarball)
    packNodeTarballAsIs
    unpackNodeTarball
    linkAsNodeModule'
    linkAsNodeModule
    linkBins
    linkAsGlobal
    mkNodeTarball
  ;
  inherit (_fetcher) defaultFetchers getPreferredFetchers fetcher;

  inherit (_node-pkg-set)
    pkgEntFromPlockV2
    pkgSetFromPlockV2
  ;

  mkNmDir = callPackage ./mkNmDir.nix;

} )

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
