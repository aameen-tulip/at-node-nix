/**
 * There's a ton of old `dO-a-TuRbAlL.nix' files already.
 * This is going to take the cream of the crop, and then
 * the old ones will be deleted.
 */
{ lib, linkToPath, untar, tar, snapDerivation }: let

  inherit (lib.libpkginfo) readPkgInfo;


/* -------------------------------------------------------------------------- */

  # Pack a tarball from a directory without attempting to build.
  # Tarball will be named using the NPM registry style, being
  # "${pname}-${version}.tgz" without a scope prefix.
  # FIXME: This is an ideal place to add `pkgInfo' as `meta'.
  # FIXME: Read `files' and ignores hints from `package.json'.
  packNodeTarballAsIs = {
    src
  , pkgInfo ? readPkgInfo src
  , name    ? pkgInfo.registryTarballName
  }: let
    tarball = tar { inherit src name; };
  in tarball;


/* -------------------------------------------------------------------------- */

  # FIXME: Add `package.json' info as `meta' field.
  unpackNodeTarball = { tarball }: let
    unpacked = untar { inherit tarball; };
  in unpacked;


/* -------------------------------------------------------------------------- */

  # FIXME: Add `package.json' info as `meta' field.
  # This form does not link `.bin/'
  linkAsNodeModuleNoBin = {
    src
  , pkgInfo ? readPkgInfo src
  , name    ? pkgInfo.name
  }: linkToPath {
    name = lib.sanitizeDerivationName name;
    inherit src;
    to = name;
  };


/* -------------------------------------------------------------------------- */

  linkBinsOut = { src, pkgJson ? getPkgJson src } @ args: let
    # Force reading incase the user gave use a path.
    pjs = if args ? pkgJson then getPkgJson pkgJson else pkgJson;
  in assert lib.pkgJsonHasBin pjs;
    linkToPath {
      # FIXME: make this relative to `package.json' in case we're in a subdir.
      # Maybe `getContext'?
      src = assert builtins.pathExists "${src}/package.json";
        map ( b: "${src}/${b}" ) pjs.bin;
      to  = ".bin";
    };


/* -------------------------------------------------------------------------- */

in {
  inherit packNodeTarballAsIs unpackNodeTarball linkAsNodeModuleNoBin;
}
