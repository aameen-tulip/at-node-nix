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

  # FIXME: You can likely convert `shasum' to a valid hash.
  getFetchurlTarballArgs = x:
    let ti = getTarInfo x; in { url = ti.tarball; hash = ti.integrity; };


/* -------------------------------------------------------------------------- */

  fetchTarInfo = registryUrl: pname: version:
    let packument = importFetchPackument registryUrl pname;
    in getTarInfo packument.versions.${version};

  fetchFetchurlTarballArgs = registryUrl: pname: version:
    let
      packument = importFetchPackument registryUrl pname;
      dist = packument.versions.${version}.dist;
    in {
      url  = dist.tarball;
      hash = dist.integrity or "";
      sha1 = dist.shasum or "";
    };

  fetchFetchurlTarballArgsNpm =
    { name ? null, pname ? null, version ? "latest" }:
      assert ( name != null ) || ( ( pname != null ) && ( version != null ) );
      let
        pns = builtins.split "@" name;
        pnsl = builtins.length pns;
        versionFromName = builtins.elemAt pns ( pnsl - 1 );
        pnameFromName = if pnsl == 5 then "@" + ( builtins.elemAt pns 2 )
                                    else ( builtins.head pns );
        pname' = if name == null then pname else pnameFromName;
        version' = if name == null then version else versionFromName;
      in fetchFetchurlTarballArgs "https://registry.npmjs.org/" pname' version';


/* -------------------------------------------------------------------------- */
in {
  inherit fetchPackument importFetchPackument;
  inherit packumentPkgLatestVersion;
  inherit getTarInfo getFetchurlTarballArgs;
  inherit fetchTarInfo fetchFetchurlTarballArgs fetchFetchurlTarballArgsNpm;
}
