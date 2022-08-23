{ lib, config ? {}, ... } @ globalAttrs: let

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
  depClosureToPkgAttrsFor' = ignoreStartPeers: depFields: plock:
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
        t = getTopLevelEntry plock ident;
      in if ( version == null ) || ( t.version == version ) then t else null;
      findFrom = let
        res = ( resolveNameVersion plock ident version ).key;
        tnm = plock.packages."node_modules/${ident}";
        tp  = if tnm.link or false then tnm.resolved
                                   else "node_modules/${ident}";
      in if topName != null then tp else res;
      from' = idargs.from or findFrom;
      dc = let
        c = depClosureFor' ignoreStartPeers depFields plock from';
      # Drop the module we're checking from the closure.
      in builtins.tail c;
      toKey = { key, version, ... } @ attrs: let
        name = attrs.name or ( lib.yank ".*node_modules/(.*)" key );
      in name + "/" + version;
    in map toKey dc;

  depClosureToPkgAttrsFor = depClosureToPkgAttrsFor' true;
  runtimeClosureToPkgAttrsFor =
    depClosureToPkgAttrsFor ["dependencies" "peerDependencies"];


/* -------------------------------------------------------------------------- */

  # Direct Deps + ( maybe peers recursively if `depFields' include "peerDep*" )
  depsToPkgAttrsFor' = ignoreStartPeers: depFields: plock:
    { from ? null, ident ? null, version ? null } @ idargs:
    assert from == null -> ident != null; let
      topName = let
        t = getTopLevelEntry plock ident;
      in if ( version == null ) || ( t.version == version ) then t else null;
      findFrom = let
        res = ( resolveNameVersion plock ident version ).key;
        tnm = plock.packages."node_modules/${ident}";
        tp  = if tnm.link or false then tnm.resolved
                                   else "node_modules/${ident}";
      in if topName != null then tp else res;
      from' = idargs.from or findFrom;
      resolve = k: d:
        let r = resolveDepFor plock k d; in r.value // { key = r.resolved; };
      peerFields =
        builtins.filter ( lib.hasPrefix "peerDependencies" ) depFields;
      directFields =
        builtins.filter ( f: ! lib.hasPrefix "peerDependencies" f ) depFields;
      ent = plock.packages.${from'};
      toKey = { key, version, ... } @ attrs: let
        name = attrs.name or ( lib.yank ".*node_modules/(.*)" key );
      in name + "/" + version;
      directNames = map ( x: x.name ) ( depList' directFields ent );
      directKeys  = map ( i: toKey ( resolve from' i ) ) directNames;
      pdc = let
        pc = depClosureFor' ignoreStartPeers peerFields plock from';
      # drop the actual module we're checking from the closure list.
      in builtins.tail pc;
    in ( map toKey pdc ) ++ directKeys;

  depsToPkgAttrsFor = depsToPkgAttrsFor' true;
  runtimeDepsToPkgAttrsFor =
    depsToPkgAttrsFor ["dependencies" "peerDependencies"];


/* -------------------------------------------------------------------------- */

  # FIXME: this currently only supports v2 locks.
  # This is the part that is actually effected by the v2 lock.
  isRegistryTarball = k: v:
    ( lib.hasPrefix "node_modules/" k ) &&
    ( ! ( v.link or false ) ) &&
    # This really just aims to exclude `git+' protocol resolutions.
    ( lib.hasPrefix "https://registry." v.resolved );


/* -------------------------------------------------------------------------- */

  # FIXME: this currently only supports registry packages.
  # Adding the other types of resolution isn't "hard", I just haven't done
  # it yet.
  # Largely this just means copying/calling other routines that already handle
  # those types of resolution.
  fromPlockV2 = plock: let
    __meta = {};
    # You can probably support v1 locks by tweaking this and the "node_modules/"
    # check in `isRegistryTarball' above.
    regEntries = lib.filterAttrs isRegistryTarball plock.packages;
    toSrc = { resolved, integrity, version, hasInstallScript ? false, ... }: let
      ident =
        lib.yank "https?://registry\\.[^/]+/(.*)/-/.*\\.tgz" resolved;
    in {
      inherit version ident;
      key = "${ident}/${version}";
      url = resolved;
      hash = integrity;
      # FIXME:
    }; #// ( if hasInstallScript then { inherit hasInstallScript; } else {} );
    toSrcNV = e: let
      value = toSrc e;
    in { name = value.key; inherit value; };
    srcEntriesList = map toSrcNV ( builtins.attrValues regEntries );
    srcEntries = builtins.listToAttrs srcEntriesList;
  in srcEntries // { inherit __meta; };


/* -------------------------------------------------------------------------- */

  # FIXME: this currently only supports registry packages.
  manifestInfoFromPlockV2 = plock: let
    inherit (lib) filterAttrs;
    keeps = {
      name                 = null;
      version              = null;
      bin                  = null;
      # `devDependencies' will not appear in registry dependencies because they
      # are already "built".
      dependencies         = null;
      peerDependencies     = null;
      peerDependenciesMeta = null;
      optionalDependencies = null;
      hasInstallScript     = null;
    };
    # Values from second attrset are preserved.
    filtAttrs = builtins.intersectAttrs keeps;
    mkEntry = k: pe: let
      name = pe.name or
        ( lib.yank "https?://registry\\.[^/]+/(.*)/-/.*\\.tgz" pe.resolved );
      key = name + "/" + pe.version;
    in { name  = key; value = { inherit name key; } // ( filtAttrs pe ); };
    regEntries = lib.filterAttrs isRegistryTarball plock.packages;
    manEntryList = builtins.attrValues ( builtins.mapAttrs mkEntry regEntries );
    manEntries = builtins.listToAttrs manEntryList;
  in manEntries // { __meta.checkedInstallScripts = true; };


/* -------------------------------------------------------------------------- */

in {

  # Really just exported for testing.
  inherit
    wasResolved
    depList
    depKeys
    depUnkey
    depUnkeys
    isRegistryTarball
    depList'
    depKeys'
  ;


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
    depClosureToPkgAttrsFor'
    depClosureToPkgAttrsFor
    runtimeClosureToPkgAttrsFor
    depsToPkgAttrsFor'
    depsToPkgAttrsFor
    runtimeDepsToPkgAttrsFor
    manifestInfoFromPlockV2
    fromPlockV2
  ;
}
