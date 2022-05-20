let

  # Fetch a packument from the registry.
  # String string contexts to ensure that the fetched result doesn't root its
  # hash from any arguments.
  # NOTE: I honestly don't know if it would do this, but I'm not going to dig
  #       through the Nix source code to find out right now.
  fetchPackument = registryUrl: name:
    let url = builtins.unsafeDiscardStringContext "${registryUrl}/${name}"; in
    builtins.readFile ( builtins.fetchurl url );

  importFetchPackument = registryUrl: name:
    builtins.fromJSON ( fetchPackument registryUrl name );


/* -------------------------------------------------------------------------- */

  # Determine the latest version of a package from its packument info.
  # First we check for `.dist-tags.latest' for a version number, otherwise we
  # use the last element of the list.
  # Nix sorts keys such that the highest version number will be last.
  packumentPkgLatestVersion = packument:
    if packument ? dist-tags.latest
    then packument.versions.${packument.dist-tags.latest}
    else let len = builtins.length packument.versions;
         in builtins.elemAt packument.versions ( len -1 );


/* -------------------------------------------------------------------------- */

  getTarInfo = x:
    let dist = x.dist or x.tarball or ( packumentPkgLatestVersion ).dist;
    in { inherit (dist) tarball; integrity = dist.integrity or null; };

  getFetchurlTarballArgs = x:
    let ti = getTarInfo x; in { url = ti.tarball; hash = ti.integrity; };


/* -------------------------------------------------------------------------- */
in {
  inherit fetchPackument importFetchPackument;
  inherit packumentPkgLatestVersion;
  inherit getTarInfo getFetchurlTarballArgs;
}
