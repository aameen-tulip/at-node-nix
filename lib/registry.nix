{ libparse ? import ./parse.nix
, lib      ? ( builtins.getFlake "github:NixOS/nixpkgs?dir=lib" ).lib
, libpi    ? import ./pkginfo.nix { inherit lib; }
}:  # FIXME
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

  addPackumentExtras = packument:
    let
      nid' = libparse.parseIdent packument._id;
      scopeDir = if ( nid'.scope != null ) then "@${nid'.scope}/" else "";
      nid = nid' // { inherit scopeDir; };
      addNiVers = vers: val: val // nid // { reference = vers; };
      addTarInfoVers = val:
        let
          fetchTarballArgs = ( { tarball, integrity ? "", shasum ? "", ... }: {
            url = tarball;
            hash = integrity;
            sha1 = shasum;
          } ) val.dist;
          fetchWith = {
            fetchurl ? ( { url, ... }: builtins.fetchurl url )
          }: fetchurl fetchTarballArgs;
        in val // {
          inherit fetchTarballArgs fetchWith;
          inherit (val.dist) tarball;
        };
      addAllDeps = val: val // { allDependencies = libpi.allDependencies val; };
      addPerVers = vers: val:
        ( addAllDeps ( addTarInfoVers ( addNiVers vers val ) ) );
      # FIXME:
      versions = builtins.mapAttrs addPerVers ( packument.versions or {} );
      packument' = packument // nid // { inherit versions; };
      latest = packumentPkgLatestVersion packument';
    in packument' // {
      latest = if versions != {} then latest else null;
      versions = packument'.versions // { inherit latest; };
    };


/* -------------------------------------------------------------------------- */

  # Determine the latest version of a package from its packument info.
  # First we check for `.dist-tags.latest' for a version number, otherwise we
  # use the last element of the list.
  # Nix sorts keys such that the highest version number will be last.
  packumentPkgLatestVersion = packument:
    if packument ? dist-tags.latest
    then packument.versions.${packument.dist-tags.latest}
    else let vlist = builtins.attrValues packument.versions;
             len = builtins.length vlist;
             last = builtins.elemAt vlist ( len -1 );
         in if ( 0 < len  ) then last else
           throw "Package ${packument._id} lacks a version list";


/* -------------------------------------------------------------------------- */

  getTarInfo = x:
    let dist = x.dist or x.tarball or ( packumentPkgLatestVersion ).dist;
    in { inherit (dist) tarball; integrity = dist.integrity or null; };

  # FIXME: You can likely convert `shasum' to a valid hash.
  getFetchurlTarballArgs = x:
    let ti = getTarInfo x; in { url = ti.tarball; hash = ti.integrity; };


/* -------------------------------------------------------------------------- */

  fetchTarInfo = registryUrl: name: version:
    let packument = importFetchPackument registryUrl name;
    in getTarInfo packument.versions.${version};

  fetchFetchurlTarballArgs = registryUrl: name: version:
    let
      packument = importFetchPackument registryUrl name;
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

  /**
   * A lazily evaluated extensible packument database.
   * Packuments will not be fetched twice.
   *   let
   *     pr   = packumenter;
   *     pr'  = pr.extend ( pr.lookup "lodash" );
   *     pr'' = pr.extend ( pr.lookup "3d-view" );
   *   in pr''.packuments
   *
   * Or use the packumenter itself as a function:
   *   let
   *     pr   = packumenter;
   *     pr'  = pr "lodash";
   *     pr'' = pr "lodash";
   *   in pr''.packuments;
   *
   * This is particularly useful with `builtins.foldl'':
   *   ( builtins.foldl' ( x: x ) packumenter ["lodash" "3d-view"] ).packuments
   */
  packumenter = lib.makeExtensible ( final: {
    packuments = {};
    registry = "https://registry.npmjs.org/";
    # Create an override extending a packumenter with a packument
    lookup = str:
      let
        ni = libparse.nameInfo str;
        fetchPack = prev:
          let raw = importFetchPackument prev.registry ni.name;
          in addPackumentExtras raw;
        addPack = final: prev:
          if ( prev.packuments ? ${ni.name} ) then {} else {
            packuments =
              prev.packuments // { ${ni.name} = ( fetchPack prev ); };
          };
      in addPack;
    __functor = self: str: self.extend ( self.lookup str );
  } );

  extendWithLatestDeps' = pr:
    let
      inherit (builtins) concatMap attrNames attrValues foldl';
      allDeps = concatMap ( x: attrNames ( x.latest.allDependencies or {} ) )
                          ( attrValues pr.packuments );
    in foldl' ( acc: x: let t = builtins.tryEval ( let r = acc x; in builtins.deepSeq r r ); in if t.success then t.value else acc ) pr allDeps;


/* -------------------------------------------------------------------------- */

in {
  inherit fetchPackument importFetchPackument;
  inherit packumentPkgLatestVersion;
  inherit getTarInfo getFetchurlTarballArgs;
  inherit fetchTarInfo fetchFetchurlTarballArgs fetchFetchurlTarballArgsNpm;
  inherit packumenter extendWithLatestDeps';
  test =
    let
      pr = builtins.foldl' ( x: x ) packumenter ["lodash" "3d-view"];
      pr' = lib.converge extendWithLatestDeps' pr;
    in builtins.length ( builtins.attrNames pr'.packuments );
}
