{ nixpkgs   ? builtins.getFlake "nixpkgs"
, system    ? builtins.currentSystem
, pkgs      ? nixpkgs.legacyPackages.${system}
, lib       ? import ../../lib { lib = nixpkgs.lib }
, stdenv    ? pkgs.stdenvNoCC
, fetchurl  ? pkgs.fetchurl
, nodejs    ? pkgs.nodejs-14_x
}:
let

  coercePkgInfo = x: let
    inherit (builtins) readDir isPath isString;
    isFile  = x:
    catPath = if builtins.isPath
    type = if builtinsisPath x then "path"
  in


  mkPackageLock = pkgJson:


in  mkPackageLock
