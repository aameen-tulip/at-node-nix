let
  inherit (builtins) readFile fromJSON attrValues head filter
                     replaceStrings;
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib runCommandNoCC;
  sanitizeName = replaceStrings ["@"] ["%40"];

  fetchJSON = name:
    readFile ( builtins.fetchurl
                 "https://registry.npmjs.org/${sanitizeName name}" );

  fetch = name: fromJSON ( fetchJSON name );

  # Given an entry from the registry response's version, check if the entry has
  # an integrity value.
  hasIntegrity = { dist ? {}, ... }: dist ? integrity;

  extractPkgJSON = tarball: runCommandNoCC "package.json" {} ''
    tar -xz --strip 1 --to-stdout -f ${tarball} package/package.json > $out
  '';

  latestVersion = pkgInfo:
    if pkgInfo ? dist-tags.latest
    then pkgInfo.versions.${pkgInfo.dist-tags.latest}
    else let len = builtins.length pkgInfo.versions;
         in builtins.elemAt pkgInfo.versions ( len -1 );

  getTarInfo = x:
    let
      fromDist = { integrity ? null, tarball, ... }: {
        inherit integrity tarball;
      };
      dist = if x ? dist then x.dist
             else if x ? tarball then x
             else ( latestVersion x ).dist;
    in fromDist dist;

  getFetchurlTarballArgs = x: let ti = ( getTarInfo x ); in {
    url = ti.tarball;
    sha512 = ti.integrity;
  };

in {
  inherit fetchJSON hasIntegrity extractPkgJSON latestVersion getTarInfo
          getFetchurlTarballArgs fetch;

  filterWithIntegrity = lib.filterAttrs ( { key, value }: hasIntegrity value );

  readTarPkgJSON = tarball: fromJSON ( readFile ( extractPkgJSON tarball ) );

  fetchNodeTarball = { name, version ? null }:
    let
      pkgInfo = fetch name;
      version' = if version == null then latestVersion pkgInfo
                                    else pkgInfo.versions.${version};
    in pkgs.fetchurl ( getFetchurlTarballArgs version'.dist );
}
