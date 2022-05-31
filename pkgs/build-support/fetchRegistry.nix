{ pkgs               ? import <nixpkgs> {}
, lib                ? pkgs.lib
, libpkginfo         ? import ../../lib/pkginfo.nix { inherit lib; }
, libregistry        ? import ../../lib/registry.nix
, registryUrl        ? "https://registry.npmjs.org"
, extractPackageJSON ? import ./extract-package-json.nix {
                         inherit (pkgs) runCommandNoCC;
                       }
}:
let
  inherit (libpkginfo) parsePkgJsonName mkPkgInfo readPkgInfo allDependencies;
  inherit (libregistry) fetchPackument packumentPkgLatestVersion;
  inherit (libregistry) getFetchurlTarballArgs;
  inherit (builtins) readFile fromJSON attrValues head filter
                     replaceStrings unsafeDiscardStringContext;
  # Given an entry from the registry response's version, check if the entry has
  # an integrity value.
  hasIntegrity = { dist ? {}, ... }: dist ? integrity;

in {
  inherit hasIntegrity extractPackageJSON;

  filterWithIntegrity = lib.filterAttrs ( { key, value }: hasIntegrity value );

  importTarPackageJSON = tarball:
    fromJSON ( readFile ( extractPackageJSON tarball ) );

  # This could probably skip fetching the packument altogether.
  fetchNodeTarball = { name, version ? null }:
    let
      packument = fetchPackument registryUrl name;
      version'  = if version == null
                  then packumentPkgLatestVersion packument
                  else packument.versions.${version};
    in pkgs.fetchurl ( getFetchurlTarballArgs version'.dist );
}
