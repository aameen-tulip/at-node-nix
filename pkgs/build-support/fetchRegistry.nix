{ pkgs               ? import <nixpkgs> {}
, lib                ? pkgs.lib
, lib-pkginfo        ? import ../../lib/pkginfo.nix { inherit lib; }
, lib-registry       ? import ../../lib/registry.nix
, registryUrl        ? "https://registry.npmjs.org"
, extractPackageJSON ? import ./extract-package-json.nix {
                         inherit (pkgs) runCommandNoCC;
                       }
}:
let
  inherit (lib-pkginfo) parsePkgJsonName mkPkgInfo readPkgInfo allDependencies;
  inherit (lib-registry) fetchPackument packumentPkgLatestVersion;
  inherit (lib-registry) getFetchurlTarballArgs;
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
