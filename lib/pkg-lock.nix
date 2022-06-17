{ lib }:
let

  # A filter function that return true if an entry is resolved by NPM.
  # NOTE: This returns `false' for any non-NPM resolution.
  wasResolved = _: v: builtins.isString ( v.resolved or null );

  # Given a list of `{ name = "@scope/name"; value = { ... }; }' pairs,
  # split them into groups "right" and "wrong" ( attributes ) such that
  # `{ right = [<Resolved>]; wrong = [<Unresolved>]; }'
  partitionDirectResolved' = builtins.partition wasResolved;

  # Like `partitionDirectResolved'', except contents of `right' and `wrong' are
  # converted into attribute sets.
  # NOTE:
  # By converting from a list to a set, any repeated keys will be dedupolicated.
  # If you want to preserve duplicates, you probably want `partitionResolved'
  # instead, which handles dependencies of dependencies - since that is the
  # only case where duplicate keys are valid.
  partitionDirectResolved = plock:
    builtins.mapAttrs ( _: v: builtins.listToAttrs v )
      ( partitionDirectResolved' plock );

  # Given a lock, return a set of dependencies which are resolved by NPM.
  collectDirectResolved = plock:
    lib.filterAttrs wasResolved plock.dependencies;

  # Given a lock, return a set of dependencies which are not resolved by NPM.
  collectDirectUnresolved = plock:
    lib.filterAttrs ( k: v: ! ( wasResolved k v ) ) plock.dependencies;


/* -------------------------------------------------------------------------- */

  partitionResolved' = plock: let
    dc = map depUnkey ( dependencyClosure' plock );
  in builtins.partition ( { name, value }: wasResolved name value ) dc;

  partitionResolved = plock:
    builtins.mapAttrs ( _: v: builtins.listToAttrs v )
                      ( partitionResolved' plock );

  collectResolved = plock: ( partitionResolved plock ).right;
  collectUnresolved = plock: ( partitionResolved plock ).wrong;


/* -------------------------------------------------------------------------- */

  depList = pl: lib.mapAttrsToList lib.nameValuePair ( pl.dependencies or {} );

  depKeys = pl:
    lib.mapAttrsToList ( name: { version, ... }@value: value // {
      key = "${name}@${version}";
      inherit name;
    } ) ( pl.dependencies or {} );

  depUnkey = { key, ... }@value: { name = key; inherit value; };
  depUnkeys = lst: builtins.listToAttrs ( map depUnkey lst );

  dependencyClosure' = plock: builtins.genericClosure {
    startSet = depKeys plock;
    operator = depKeys;
  };

  dependencyClosure = plock: depUnkeys ( dependencyClosure' plock );


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
    in builtins.mapAttrs applyFetch ( collectResolved plock );


/* -------------------------------------------------------------------------- */

  resolvedFetcherTree = fetchurl: plock:
    let
      inherit (builtins) mapAttrs;
      applyFetch = _: v: fetchurl { url = v.resolved; hash = v.integrity; };
      resolved = collectResolved plock;
      fetchers = mapAttrs applyFetch  resolved;
    in null;


/* -------------------------------------------------------------------------- */

  toposortDeps = plock: let
    inherit (builtins) elem attrValues;
    depl =
      attrValues ( lib.libattrs.pushDownNames ( plock.dependencies or {} ) );
    bDependsOnA = a: b: elem a.name ( attrValues ( b.dependencies or {} ) );
  in lib.toposort bDependsOnA depl;


/* -------------------------------------------------------------------------- */

in {

  # Really just exported for testing.
  inherit wasResolved depList depKeys depUnkey depUnkeys;


  # The real lib members.
  inherit collectResolved collectUnresolved;
  inherit partitionResolved partitionResolved';
  inherit dependencyClosure' dependencyClosure;
  inherit partitionDirectResolved partitionDirectResolved';
  inherit collectDirectResolved collectDirectUnresolved;
  inherit resolvedFetchersFromLock resolvedFetcherTree;
  inherit toposortDeps;
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
