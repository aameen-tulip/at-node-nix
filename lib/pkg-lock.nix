{ lib }:
let

  # A filter function
  wasResolved = _: v: builtins.isString ( v.resolved or null );

  collectResolved = plock: lib.filterAttrs wasResolved plock.dependencies;

  collectUnresolved = plock:
    lib.filterAttrs ( k: v: ! ( wasResolved k v ) ) plock.dependencies;

  partitionResolved = builtins.partition wasResolved;

in {
  inherit collectResolved collectUnresolved partitionResolved;

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

  toposortDeps = plock: let
    inherit (builtins) elem attrValues;
    depl = attrValues ( lib.pushDownNames ( plock.dependencies or {} ) );
    bDependsOnA = a: b: elem a.name ( attrValues ( b.dependencies or {} ) );
  in lib.toposort bDependsOnA depl;
}
