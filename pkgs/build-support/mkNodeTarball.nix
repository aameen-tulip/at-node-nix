/**
 * There's a ton of old `dO-a-TuRbAlL.nix' files already.
 * This is going to take the cream of the crop, and then
 * the old ones will be deleted.
 */
{ lib, linkToPath, linkFarm, untar, pacotecli, /* tar, */ ... }: let

  inherit (lib.libpkginfo) readPkgInfo;
  inherit (builtins) mapAttrs attrValues attrNames filter;


/* -------------------------------------------------------------------------- */

  # FIXME: This doesn't match `pacote'.
  # For the time being - use `pacote tarball <path>' to create tarballs.
  #
  # Pack a tarball from a directory without attempting to build.
  # Tarball will be named using the NPM registry style, being
  # "${pname}-${version}.tgz" without a scope prefix.
  # FIXME: This is an ideal place to add `pkgInfo' as `meta'.
  # FIXME: Read `files' and ignores hints from `package.json'.
  packNodeTarballAsIs = {
    src
  , pjs  ? readPkgInfo src
  , name ? pjs.registryTarballName
  }: let
    #tarball  = tar {
    #  inherit name;
    #  tarFlagsLate = [
    #    "-C" src.outPath
    #    "--transform=s,^\./,package/,"
    #    "--warning=no-unknown-keyword"
    #    "--delay-directory-restore"
    #  ];
    #  src = ".";
    #};
    tarball = pacotecli "tarball" {
      dest = name;
      spec = src.outPath;
    };
    meta = ( src.meta or {} ) // {
      inherit (pjs) version;
      inherit pjs;
      # FIXME: You're note scraping the `manifest' data.
      # SHA512 is the one you may need.
      # Other manifest data contains store paths, so it would belong
      # in passthru.
      manifest = { integrity = ""; };
    };
    passthru = { inherit src tarball; } // ( tarball.passthru or {} );
  in tarball // { inherit meta passthru; };


/* -------------------------------------------------------------------------- */

  # XXX: This expects that the tarball is a `package/{package.json,...}' tarball
  # You shouldn't
  unpackNodeTarball = { tarball }: let
    unpacked = untar {
      inherit tarball;
      tarFlagsLate = ["--strip-components=1"];
    };
    importedPjs = readPkgInfo "${unpacked}/package.json";
    pjs         = tarball.meta.pjs or importedPjs;
    meta        = ( tarball.meta or {} ) // { inherit pjs; };
    passthru    = { inherit tarball unpacked; } // ( tarball.passthru or {} );
  in unpacked // { inherit meta passthru; };


/* -------------------------------------------------------------------------- */

  # This form does not link `.bin/'
  linkAsNodeModule' = { package, name ? package.name + "-module-strict" }:
    linkToPath { inherit name; src = package; to = package.meta.pjs.name; };


/* -------------------------------------------------------------------------- */

  binEntries = to: package:
    assert lib.libpkginfo.pkgJsonHasBin package.meta.pjs;
    assert builtins.pathExists "${package}/package.json"; let
      entries = lib.mapAttrsToList ( n: p: {
        name = "${to}/${n}"; path = "${package}/${p}";
      } ) package.meta.pjs.bin;
    in entries;


/* -------------------------------------------------------------------------- */

  # XXX: These are not patched.
  # AGAIN: These have not bee processed by `patchShebangs'
  #
  # By default we link to regular `bin/' for the convenience of making tools.
  # Setting `to = "";' will give put them in the root of the output.
  linkBins = { src, name ? src.name + "-bindir", to ? "bin" }: let
    inherit (src.meta) pjs;
    package = src.passthru.package or src;
    bindir = linkFarm name ( binEntries to package );
    passthru = { inherit package bindir; } // ( src.passthru or {} );
  in bindir // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # This links `.bin/' "hidden" in the `node_modules' folder.
  linkAsNodeModule = { package, name ? package.name + "-module" }: let
    linked = linkFarm name ( ( binEntries ".bin" package ) ++ [
      { name = package.meta.pjs.name; path = package.outPath; }
    ] );
    bindir = builtins.storePath "${linked}/.bin";
    passthru = {
      inherit package bindir;
      module = linked;
    } // ( package.passthru or {} );
  in linked // { inherit passthru; };


/* -------------------------------------------------------------------------- */

in {
  inherit
    packNodeTarballAsIs  # FIXME: see note at top
    unpackNodeTarball
    linkAsNodeModule'
    linkAsNodeModule
    linkBins
  ;
}
