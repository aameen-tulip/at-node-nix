{ lib }:
let

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

  depList' = depFields: pl: let
    deps = builtins.foldl' ( acc: f: acc // ( pl.${f} or {} ) ) {} depFields;
  in lib.mapAttrsToList lib.nameValuePair deps;

  depKeys' = depFields: pl: let
    deps = builtins.foldl' ( acc: f: acc // ( pl.${f} or {} ) ) {} depFields;
  in lib.mapAttrsToList ( name: { version, ... }@value: value // {
    key = "${name}@${version}";
    inherit name;
  } ) deps;

  depUnkey = { key, ... }@value: { name = key; inherit value; };
  depUnkeys = lst: builtins.listToAttrs ( map depUnkey lst );

  dependencyClosureKeyed' = depFields: plock: builtins.genericClosure {
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

  dependencyClosureKeyed = plock: builtins.genericClosure {
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
    in builtins.mapAttrs applyFetch ( collectResolved plock );


/* -------------------------------------------------------------------------- */

  # FIXME:
  resolvedFetcherTree = fetchurl: plock: let
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
  inherit collectResolved collectUnresolved;
  inherit partitionResolved partitionResolved';
  inherit dependencyClosureKeyed dependencyClosure;
  inherit dependencyClosureKeyed' dependencyClosure';
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
