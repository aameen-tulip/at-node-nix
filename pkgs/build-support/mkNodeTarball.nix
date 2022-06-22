/**
 * There's a ton of old `dO-a-TuRbAlL.nix' files already.
 * This is going to take the cream of the crop, and then
 * the old ones will be deleted.
 */
{ lib, linkToPath, linkFarm, untar, pacotecli, /* tar, */ ... }: let

  inherit (lib.libpkginfo) readPkgInfo;
  inherit (builtins) mapAttrs attrValues attrNames filter;


/* -------------------------------------------------------------------------- */

  # derivation types and passthru attrs
  #   tarball     registry style tarball.
  #   unpacked    *built* tree ready for consumption.
  #   bindir      linked bindir ( only when `package.json' has `bins' field ).
  #   module      `node_modules/' style tree, including `.bin/' if any.
  #   package     global style tree, including `bin/' if any'. TODO


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
      spec = toString src;
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
  linkAsNodeModule' = { unpacked, name ? unpacked.name + "-module-strict" }:
    linkToPath { inherit name; src = unpacked; to = unpacked.meta.pjs.name; };


/* -------------------------------------------------------------------------- */

  binEntries = to: unpacked:
    assert lib.libpkginfo.pkgJsonHasBin unpacked.meta.pjs;
    assert builtins.pathExists "${unpacked}/package.json"; let
      entries = lib.mapAttrsToList ( n: p: {
        name = "${to}/${n}"; path = "${unpacked}/${p}";
      } ) unpacked.meta.pjs.bin;
    in entries;


/* -------------------------------------------------------------------------- */

  # XXX: These are not patched.
  # AGAIN: These have not bee processed by `patchShebangs'
  #
  # By default we link to regular `bin/' for the convenience of making tools.
  # Setting `to = "";' will give put them in the root of the output.
  linkBins = { src, name ? src.name + "-bindir", to ? "bin" }: let
    inherit (src.meta) pjs;
    unpacked' = src.passthru.unpacked or src;
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked'}/package.json"; } //
             ( unpacked'.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked' // { inherit meta passthru; };
    unpacked = if unpacked' ? meta.pjs then unpacked' else withMetaPass;
    bindir = linkFarm name ( binEntries to unpacked );
    passthru = { inherit unpacked bindir; } // ( src.passthru or {} );
  in bindir // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # This links `.bin/' "hidden" in the `node_modules' folder.
  linkAsNodeModule = { unpacked, name ? unpacked.name + "-module" }: let
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked}/package.json"; } //
             ( unpacked.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked // { inherit meta passthru; };
    unpacked' = if unpacked ? meta.pjs then unpacked else withMetaPass;
    linked = linkFarm name ( ( binEntries ".bin" unpacked' ) ++ [
      { name = unpacked'.meta.pjs.name; path = unpacked'.outPath; }
    ] );
    bindir = if lib.libpkginfo.pkgJsonHasBin unpacked'.meta.pjs then
      builtins.storePath "${linked}/.bin" else null;
    module = if bindir != null then linked else linkAsNodeModule' {
      unpacked = unpacked';
    };
    passthru = {
      inherit module;
      unpacked = unpacked';
    } // ( unpacked'.passthru or {} ) // ( if bindir == null then {} else {
      inherit bindir;
    } );
  in module // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # This links `.bin/' "hidden" in the `node_modules' folder.
  linkAsGlobal = { unpacked, name ? unpacked.name + "-global" }: let
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked}/package.json"; } //
             ( unpacked.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked // { inherit meta passthru; };
    unpacked' = if unpacked ? meta.pjs then unpacked else withMetaPass;
    linked = linkFarm name ( ( binEntries "bin" unpacked' ) ++ [
      {
        name = "lib/node_modules/" + unpacked'.meta.pjs.name;
        path = unpacked'.outPath;
      }
    ] );
    bindir = if lib.libpkginfo.pkgJsonHasBin unpacked'.meta.pjs then
      builtins.storePath "${linked}/bin" else null;
    global = if bindir != null then linked else linkAsNodeModule' {
      unpacked = unpacked';
    };
    passthru = {
      inherit global;
      unpacked = unpacked';
    } // ( unpacked'.passthru or {} ) // ( if bindir == null then {} else {
      inherit bindir;
    } );
  in global // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  mkNodeTarball = src: let
    # FIXME: You really need to build
    tarball  = packNodeTarballAsIs { inherit src; };
    unpacked = unpackNodeTarball { inherit tarball; };
  in {
    inherit tarball unpacked;
    module = linkAsNodeModule { inherit unpacked; };
    global = linkAsGlobal { inherit unpacked; };
  };


/* -------------------------------------------------------------------------- */

in {
  inherit
    packNodeTarballAsIs  # FIXME: see note at top
    unpackNodeTarball
    linkAsNodeModule'
    linkAsNodeModule
    linkBins
    linkAsGlobal
    mkNodeTarball
  ;
}
