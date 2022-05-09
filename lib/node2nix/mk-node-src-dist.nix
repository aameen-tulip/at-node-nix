# Usage: Import this file with the given arguments to define the function
# `buildNodeSourceDist' as seen in `node2nix'.
# NOTE: This file adds missing calls to hook functions, and other minor
#       improvements to optimize caching.
{ pkgs        ? import <nixpkgs> {}
, stdenv      ? pkgs.stdenv
, nodejs      ? pkgs.nodejs-14_x
, enableHydra ? false
}:

# Function that generates a TGZ file from a NPM project
{ pname
, version
, src
}:
stdenv.mkDerivation {
  pname = "node-tarball-${pname}";
  inherit version;
  inherit src;
  nativeBuildInputs = [nodejs];
  # Hooks to the pack command will add output.
  # (https://docs.npmjs.com/misc/scripts)
  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    tgzFile="$( ${nodejs}/bin/npm pack|tail -n 1; )"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/tarballs
    mv $tgzFile $out/tarballs
  '' + ( if enableHydra then ''
    mkdir -p $out/nix-support
    echo "file source-dist $out/tarballs/$tgzFile"  \
         >> $out/nix-support/hydra-build-products
  '' else ""
  ) + ''
    runHook postInstall
  '';
}
