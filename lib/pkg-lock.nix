{ lib }:
let

  inherit (builtins)
    attrValues
    partition
    mapAttrs
    listToAttrs
    isString
    foldl'
    genericClosure
    elem
    match
    head
    groupBy
    attrNames
  ;

/* -------------------------------------------------------------------------- */

  # FIXME:
  #   Most of these were written referencing a lockfile created by NPM v6.
  #   NPM v8 made notable changes to the "top level" keys of their lockfile
  #   to support workspaces.
  #   Luckily these changes largely just effect treatment of the top-level; but
  #   these functions should be updated accordingly.


/* -------------------------------------------------------------------------- */

  # A filter function that return true if an entry is resolved by NPM.
  # NOTE: This returns `false' for any non-NPM resolution.
  wasResolved = _: v: isString ( v.resolved or null );

  # Given a list of `{ name = "@scope/name"; value = { ... }; }' pairs,
  # split them into groups "right" and "wrong" ( attributes ) such that
  # `{ right = [<Resolved>]; wrong = [<Unresolved>]; }'
  partitionDirectResolved' = partition wasResolved;

  # Like `partitionDirectResolved'', except contents of `right' and `wrong' are
  # converted into attribute sets.
  # NOTE:
  # By converting from a list to a set, any repeated keys will be dedupolicated.
  # If you want to preserve duplicates, you probably want `partitionResolved'
  # instead, which handles dependencies of dependencies - since that is the
  # only case where duplicate keys are valid.
  partitionDirectResolved = plock:
    mapAttrs ( _: v: listToAttrs v ) ( partitionDirectResolved' plock );

  # Given a lock, return a set of dependencies which are resolved by NPM.
  collectDirectResolved = plock:
    lib.filterAttrs wasResolved plock.dependencies;

  # Given a lock, return a set of dependencies which are not resolved by NPM.
  collectDirectUnresolved = plock:
    lib.filterAttrs ( k: v: ! ( wasResolved k v ) ) plock.dependencies;


/* -------------------------------------------------------------------------- */

  _partitionResolved' = depFields: plock: let
    dc = map depUnkey ( attrValues ( dependencyClosure' depFields plock ) );
  in partition ( { name, value }: wasResolved name value ) dc;

  partitionResolved' = _partitionResolved' ["dependencies"];

  partitionResolved = plock:
    mapAttrs ( _: v: listToAttrs v )
                      ( partitionResolved' plock );

  collectResolved = plock: ( partitionResolved plock ).right;
  collectUnresolved = plock: ( partitionResolved plock ).wrong;


/* -------------------------------------------------------------------------- */

  depList' = depFields: pl: let
    deps = foldl' ( acc: f: acc // ( pl.${f} or {} ) ) {} depFields;
  in lib.mapAttrsToList lib.nameValuePair deps;

  depKeys' = depFields: pl: let
    deps = foldl' ( acc: f: acc // ( pl.${f} or {} ) ) {} depFields;
  in lib.mapAttrsToList ( name: { version, ... }@value: value // {
    key = "${name}@${version}";
    inherit name;
  } ) deps;

  depUnkey = { key, ... }@value: { name = key; inherit value; };
  depUnkeys = lst: listToAttrs ( map depUnkey lst );

  dependencyClosureKeyed' = depFields: plock: genericClosure {
    startSet = depKeys' depFields plock;
    operator = depKeys' depFields;
  };

  dependencyClosure' = depFields: plock:
    depUnkeys ( dependencyClosureKeyed' depFields plock );


/* -------------------------------------------------------------------------- */

  depList = pl: lib.mapAttrsToList lib.nameValuePair ( pl.dependencies or {} );

  depKeys = pl:
    lib.mapAttrsToList ( name: { version, ... }@value: value // {
      key = "${name}@${version}";
      inherit name;
    } ) ( pl.dependencies or {} );

  dependencyClosureKeyed = plock: genericClosure {
    startSet = depKeys plock;
    operator = depKeys;
  };

  dependencyClosure = plock: depUnkeys ( dependencyClosureKeyed plock );


/* -------------------------------------------------------------------------- */

  /**
   * Proved with a JSON representation of a `package-lock.json' file, apply a
   * fetchurl routine to all resolvable dependencies in the lock-file.
   *
   * let
   *   pkgs = import <nixpkgs> {};
   *   inherit (pkgs) fetchurl linkFarmFromDrvs;
   *   plock = with builtins; fromJSON ( readFile ./package-lock.json );
   *   resolvedFetchers = deriveFetchersForResolvedLockEntries fetchurl plock;
   * in linkFarmFromDrvs "fetchAllResolved"
   *                     ( builtins.attrValues resolvedFetchers )
   *
   */
  resolvedFetchersFromLock = fetchurl: plock:
    let applyFetch = _: v: fetchurl { url = v.resolved; hash = v.integrity; };
    in mapAttrs applyFetch ( collectResolved plock );


/* -------------------------------------------------------------------------- */

  # FIXME:
  resolvedFetcherTree = fetchurl: plock: let
    applyFetch = _: v: fetchurl { url = v.resolved; hash = v.integrity; };
    resolved = collectResolved plock;
    fetchers = mapAttrs applyFetch  resolved;
  in null;


/* -------------------------------------------------------------------------- */

  toposortDeps = plock: let
    depl =
      attrValues ( lib.libattrs.pushDownNames ( plock.dependencies or {} ) );
    bDependsOnA = a: b: elem a.name ( attrValues ( b.dependencies or {} ) );
  in lib.toposort bDependsOnA depl;


/* -------------------------------------------------------------------------- */

  # Helper that follows linked entries.
  realEntry = plock: path: let
    e = plock.packages."${path}";
    entry = if e.link or false then plock.packages."${e.resolved}" else e;
  in assert plock.lockfileVersion == 2; entry;


  # Given an NPM v8 `package-lock.json', return the top-level lock entry for
  # package with `name'.
  # This does not search nested entries.
  # This "follows" links to get the actual package info.
  # The field `name' will be pushed down into entries if it is not present.
  getTopLevelEntry = plock: name: assert plock.lockfileVersion == 2;
    { inherit name; } // ( realEntry plock "node_modules/${name}" );

  entriesByName' = plock: let
    getName = x: let
      m = match ".*node_modules/(.*)" x.name;
    in if m == null then "__DROP__" else head m;
    # Leaving the `dev' field foils our attempts to use `lib.unique' later.
    packages = builtins.mapAttrs ( _: x: removeAttrs x ["dev"] ) plock.packages;
    grouped = groupBy getName ( lib.attrsToList packages );
    grouped' = removeAttrs grouped ["__DROP__"];
  in assert plock.lockfileVersion == 2;
    builtins.mapAttrs ( _: lib.unique ) grouped';

  entriesByName = plock: let
    es = entriesByName' plock;
    resolveE = { name, value }: realEntry plock name;
  in mapAttrs ( _: vs: lib.unique ( map resolveE vs ) ) es;


/* -------------------------------------------------------------------------- */

  resolveNameVersion = plock: name: version: let
    ebn = entriesByName' plock;
    toRealKeyed = x: let
      red = realEntry plock x.name;
      key = red.key or x.value.resolved or x.name;
    in red // { inherit key; };
    realsK = map toRealKeyed ebn.${name};
    tgt = builtins.filter ( x: x.version == version ) realsK;
  in builtins.head tgt;

  resolveDepFor = plock: from: name: let
    isSub = k: _: lib.test "${from}/node_modules/.*${name}" k;
    subs = lib.filterAttrs isSub plock.packages;
    path = if subs == {} then "node_modules/${name}" else
           ( head ( attrNames subs ) );
    entry = realEntry plock path;
  in { resolved = path; value = entry; };


  depClosureFor' = ignoreStartPeers: depFields: plock: from: let
    operator = { key, ... }@attrs: let
      resolve = d:
        let r = resolveDepFor plock key d; in r.value // { key = r.resolved; };
    in map resolve ( map ( x: x.name ) ( depList' depFields attrs ) );
    startEnt = ( realEntry plock from ) // { key = from; };
    startEnt' = startEnt // ( lib.optionalAttrs ignoreStartPeers {
      peerDependencies     = {};
      peerDependenciesMeta = {};
    } );
  in genericClosure {
    startSet = [startEnt'];
    inherit operator;
  };

  depClosureFor = depClosureFor' true;

  # Slightly faster by only referencing `dependencies' field.
  runtimeClosureFor = depClosureFor ["dependencies" "peerDependencies"];

  # bcd = lib.libplock.runtimeClosureFor plock "node_modules/@babel/core"
  # map ( { key, resolved, integrity, hasInstallScript ? false, devDependencies ? {}, ... }: { inherit key resolved integrity; } // ( if hasInstallScript then { inherit hasInstallScript devDependencies; } else {} ) ) bcd


/* -------------------------------------------------------------------------- */

  # Returns the package set attr names corresponding to a v2 package lock
  # entry's dependencies.
  # The package set attr is of the form "(@<SCOPE>/)?<NAME>/<VERSION>", which
  # aligns with the "global" style install paths recommended by NPM's
  # distro package management "best practices".
  depsToPkgAttrsFor' = ignoreStartPeers: depFields: plock:
    # `from' is a lockfile path in which case `ident' and `version' may
    # be excluded.
    # If `from' is not given, `ident' ( the pjs `.name' field ) and `version'
    # should be given to resolve `from' in the lock.
    # You /can/ exclude `version' but it is really not recommended - doing so
    # will use the top level entry with `name' - this is provided for
    # convenience but don't expect to get away with it on any lockfile with
    # multiple versions of a package.
    { from ? null, ident ? null, version ? null } @ idargs:
    assert from == null -> ident != null; let
      topName = let
        t = getTopLevelEntry ident;
      in if ( version == null ) || ( t.version == version ) then t else null;
      findFrom = let
        res = ( resolveNameVersion plock ident version ).key;
        tnm = plock.packages."node_modules/${ident}";
        tp  = if tnm.link or false then tnm.resolved
                                   else "node_modules/${ident}";
      in if topName != null then tp else res;
      from' = idargs.from or findFrom;
      dc = depClosureFor' ignoreStartPeers depFields plock from';
      toKey = { key, version, ... } @ attrs: let
        name = attrs.name or ( lib.yank' ".*node_modules/(.*)" key );
      in name + "/" + version;
    in map toKey dc;

  depsToPkgAttrsFor = depsToPkgAttrsFor' true;
  runtimeDepsToPkgAttrsFor =
    depsToPkgAttrsFor ["dependencies" "peerDependencies"];


/* -------------------------------------------------------------------------- */

  # "pkg" must match a key in `<TOP>.packages'.
  #
  # We assume that the top level is a fake package, and we ignore all of those
  # fields - the dependency declarations at the top level will already have
  # been propagated into `packages.<PATH>' members, and we don't implement a
  # semver parser at time of writing - so the top level info is useless to us.
  #
  # NOTE: Packages in `node_modules/' subdirs don't have "name" fields.
  # This is actually fine because the you can yank that from the field,
  #   "path/to/foo/node_modules/@bar/quux": { version: "1.0.0", ... }
  # The closure is going to be found by looking for other keys with the same
  # prefix as `pkg' + "/node_modules/", and you may also get a few stragglers
  # at the top level.
  #
  # Strategy:
  #   1. Construct a list of package IDs + versions from `dependencies' lists.
  #   2. Collect any subdir `node_modules/' matches, and remove those from the
  #      working list.
  #   3. Locate remaining packages at top level.
  #
  # When packages are "located", keys must include both the package name
  # and version.
  # Remember that package resolution is only performed up/down RELATIVE to the
  # dependant - you cannot "locate" a package that is a subdir of sibling.
  # In theory you should never need to, assuming NPM's lock did in fact
  # calculate the ideal tree properly.
  #
  # Keep in mind that the goal of this function is ultimately to "remove"
  # packages unrelated to the closure from the lock-file.
  # With that in mind, perform operations in an additive manner to a "new" tree;
  # but when doing so take subtrees "as is" - this simplifies the effort,
  # because we won't "form a top level closure, and reduce to scoped trees" -
  # we're already started with ( in theory ) properly scoped trees.
  #
  #
  # An example of this process after executing `npm i --legacy-peer-deps --ignore-scripts'
  # Jump to a package's subdir to inspect their local `node_modules/' packages.
  #   comm -23 <( jq -r '.dependencies + .devDependencies|keys[]' ./package.json|sort; ) <( find ./node_modules -type f -name package.json -exec jq -r '.name' {} \; |sort; )
  # This produce a list of packages that need to be found at the top level.
  # The top level keys are paths, not names, so you'll need to check the names
  # of top level members, or traverse into the top level `node_modules/' path
  # and do the obnoxious trimming on names.
  # You can honestly probably just do:
  #   if <TOP>.packages ? node_modules/${dep.name} then ... else
  #   filterAttrs ( _: v: v.name == dep.name ) <TOP>.packages
  #
  # # XXX: we can probably get away with assuming that there's no repeated
  #        names with conflicting versions at the top level - but this isn't
  #        safe for a "general purpose" solution.
  #
  # NEVERMIND: The lockfile makes the links for us! we can just follow the
  #   { link = true; resolved = <REL-PATH>; }
  #
  workspaceClosureFor = plock: pkg:
    {};


/* -------------------------------------------------------------------------- */

in {

  # Really just exported for testing.
  inherit wasResolved depList depKeys depUnkey depUnkeys;
  inherit depList' depKeys';


  # The real lib members.
  inherit
    collectResolved
    collectUnresolved
    partitionResolved
    partitionResolved'
    dependencyClosureKeyed
    dependencyClosure
    dependencyClosureKeyed'
    dependencyClosure'
    partitionDirectResolved
    partitionDirectResolved'
    collectDirectResolved
    collectDirectUnresolved
    resolvedFetchersFromLock
    resolvedFetcherTree
    toposortDeps
    realEntry
    getTopLevelEntry
    entriesByName'
    entriesByName
    resolveDepFor
    resolveNameVersion
    depClosureFor'
    depClosureFor
    runtimeClosureFor
    depsToPkgAttrsFor'
    depsToPkgAttrsFor
    runtimeDepsToPkgAttrsFor
  ;
}

/**
 * Cannot be read back because it contains store paths.
 *
 * fetcherSerial = drv: {
 *   inherit (drv) name;
 *   value = {
 *     drv = { inherit (drv) outPath drvAttrs drvPath; };
 *     tarball = {
 *       inherit (drv) url;
 *       hash = drv.outputHash;
 *     };
 *     unpacked = builtins.fetchTree ( builtins.storePath drv.outPath );
 *   };
 * }
 *
 *
 * THIS works
 *
 * fetcherSerial = drv: {
 *   inherit (drv) name;
 *   fetchTarballArgs = {
 *     inherit (drv) url;
 *     hash = drv.outputHash;
 *   };
 *   unpacked = {
 *     name = "source";
 *     inherit ( builtins.fetchTree drv.outPath ) narHash;
 *   };
 * }
 */
