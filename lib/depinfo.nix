# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  # Runtime Fields
  rtFields = {
    dependencies         = true;
    optionalDependencies = true;
    requires             = true;
  };

  # Pinnable Fields
  # These are dependencies "consumed" either during a build, install, or at
  # runtime by a package.
  # NOTE: We do not want to rewrite `peerDependencies' since we do not support
  # `--legacy-peer-deps' in these routines.
  # Legacy peer deps should be handled before invoking the pin routines by
  # adding missing peers to a lock in the appropriate dependency fields using
  # `peerDependenciesMeta' ( see `lib/pkginfo.nix' for these routines ).
  # XXX: Do not pin peer deps.
  pinFields = rtFields // { devDependencies = true; };

  # Bundled Fields
  # NOTE: Both spellings are accepted and treated as equivalent by NPM.
  # I throw an error if a package declares both fields.
  bFields = {
    bundledDependencies = true;
    bundleDependencies  = true;
  };

  # Peer Fields
  pFields = {
    peerDependencies     = true;
    peerDependenciesMeta = true;
  };

  # All Dep Fields
  allDepFields = pinFields // bFields // pFields;


# ---------------------------------------------------------------------------- #

  joinAttrs = x: builtins.foldl' ( a: b: a // b ) {} ( builtins.attrValues x );

  getRt  = builtins.intersectAttrs rtFields;
  joinRt = fs: joinAttrs ( getRt fs );

  getPins  = builtins.intersectAttrs pinFields;
  joinPins = fs: joinAttrs ( getPins fs );

  getPeer = builtins.intersectAttrs pFields;

  # The fields for bundled deps are allowed to be a boolean or a list.
  # There should only ever be a single field here.
  # We fix the mispelled form of the field here to simplify logic elsewhere.
  # NOTE: For whatever reason NPM allows people to
  getBund = fs: let
    vals = builtins.attrValues ( builtins.intersectAttrs bFields fs );
    len = builtins.length vals;
  in assert len <= 1;
     if len == 0 then {} else { bundledDependencies = builtins.head vals; };

  # If it's a bool and set to `true' then we bundle all runtime deps.
  # For a list we bundle the named deps.
  joinBund = fs: let
    bs  = getBund fs;
    val = bs.bundledDependencies;
    fromList = lib.filterAttrs ( k: _: builtins.elem k val ) ( joinPins fs );
    msg = "Invalid bundledDependencies type: ${builtins.typeOf val}";
  in if ! ( bs ? bundledDependencies ) then {} else
     if builtins.isList val then fromList else
     if builtins.isBool val then joinRt fs else
     throw "joinBund: ${msg}";

  getAll = fs: let
    real = builtins.intersectAttrs allDepFields fs;
  # Fix mispelled `bundle(d)Dependencies' field name.
  in ( removeAttrs real ["bundleDependencies"] ) // ( getBund real );

  # NOTE: There is no `joinAll' because of `peerDependenciesMeta'.


# ---------------------------------------------------------------------------- #

  # Takes a `package-lock.json(v2/3)' entry as its second argument.
  # Returns "normalized" dependency information which merged various dependency
  # fields from `package-lock.json' into a single entry.
  #
  # NOTE: `depInfo' shares field names with the lockfile's package entry but
  # these have different meanings.
  # The booleans `dev', `peer', and `optional' in the lockfile refer to their
  # relationship to their relationship to the top level entry in the lock,
  # or their associated workspace member's root.
  # In the base `depInfo' recond we use these fields to indicate things like
  # `foo.dev = true;' -> "`foo' was listed in `devDependencies'".
  #
  # Currently we do not use the `path' argument, but it may be used in the
  # future to indentify whether an entry was the root of a lock.
  # This can help us indicate that the given entry is "complete" which is not
  # necessarily true for entries associated with registry-tarballs or paths
  # ( NPM recognizes paths as globally installed modules that do not need to
  # be built; this is different from how it treats symlink entries and `git'
  # entries which may need to be built with the help of `dev' deps ).
  depInfoEntFromPlockV3 = path: plent: let
    markField = field: attrs:
      builtins.mapAttrs ( _: _: { ${field} = true; } ) attrs;
    cds = builtins.mapAttrs ( _: v: { descriptor = v; } ) ( joinPins plent );
    # Some dependencies may be `peer' and `runtime' but have different
    # descriptors, so we record these with distinct names.
    # This matters if we expect to produce overlays which mix locks.
    # NOTE: A lot of packages have conflicting descriptors this matters.
    pds = builtins.mapAttrs ( _: v: { peerDescriptor = v; } )
                            ( plent.peerDependencies or {} );
    markRt   = markField "runtime" ( joinRt plent );
    markDev  = markField "dev"     ( plent.devDependencies or {} );
    markPeer = markField "peer"    ( plent.peerDependencies or {} );
    markOpt  = let
      od = markField "optional"    ( plent.optionalDependencies or {} );
      # Collect `optional' fields from peer meta; and assert that this is the
      # only field present in those attrs.
      pm = let
        as    = plent.peerDependenciesMeta or {};
        names = builtins.attrNames ( joinAttrs as );
      in assert ( names == [] ) || ( names == ["optional"] );
         as;
    in pm // od;
    merged = builtins.foldl' lib.recursiveUpdate {} [
      cds pds markRt markDev markPeer markOpt
    ];
  in if ( plent.link or false ) then {} else merged;


# ---------------------------------------------------------------------------- #

    #pinned  = lib.libplock.pinVersionsFromPlockV3 plock;

  # Given a `package-lock.json(V2/3)', produce `depInfo' entries for each
  # member of the tree.
  # Symlinked entries are skipped during the first pass and filled in a second
  # pass using info from the "real" entry.
  #
  # NOTE: This returns an attrset representing the package locks'
  # `node_modules/' similar to routines in `lib.libtree'; NOT a `metaSet'.
  # This is important because dependency pins may differ when multiple instances
  # of a package appear in a tree.
  #
  # While this routine does not pin packages; it is used as a base for others
  # which extend the tree with pins.
  #
  # XXX: Users almost certainly want to call `depInfoSetFromPlockV3' or
  # `fullDepInfoTreeFromPlockV3' rather than this helper.
  depInfoTreeFromPlockV3 = plock: let
    pass1 = builtins.mapAttrs depInfoEntFromPlockV3 plock.packages;
    # This resolves entries in exactly the same way as `lib.libplock.realEntry'.
    fixLink = path: plent:
      if plent.link or false then pass1.${plent.resolved}
                             else pass1.${path};
  in assert lib.libplock.supportsPlV3 plock;
     builtins.mapAttrs fixLink plock.packages;


# ---------------------------------------------------------------------------- #

  # Produces a keyed set of `depInfo' records.
  # No "pinning" is performed.
  # XXX: Records with multiple instances are presumed to be equal.
  # With this in mind we're able to skip handling symlinks.
  depInfoSetFromPlockV3 = plock: let
    keyDepInfo = path: let
      key   = lib.libplock.getKeyPlV3 plock path;
      plent = plock.packages.${path};
    in lib.optionalAttrs ( ! ( plent.link or false ) ) {
      ${key} = depInfoEntFromPlockV3 path plent;
    };
    paths = builtins.attrNames plock.packages;
  in builtins.foldl' ( acc: path: acc // ( keyDepInfo path ) ) {} paths;


# ---------------------------------------------------------------------------- #

  pinDepInfoTreeFromPlockV3 = {
    plock       ? lib.importJSON "${lockDir}/package-lock.json"
  , lockDir     ? null
  , pinnedLock  ? lib.libplock.pinVersionsFromPlockV3 plock
  , depInfoTree ? depInfoTreeFromPlockV3 plock
  }: let
    pinEnt = path: di: let
      ps     = joinPins pinnedLock.packages.${path};
      pinDep = ident: d:
        if ps ? ${ident} then d // { pin = ps.${ident}; } else d;
    in builtins.mapAttrs pinDep di;
  in builtins.mapAttrs pinEnt depInfoTree;


# ---------------------------------------------------------------------------- #

  # Produces a keyed set with pinned depinfo.
  # NOTE: Unlike `pinDepInfoTreeFromPlockV3' we may encounter conflicting pins
  # when multiple instances of a package appear in a tree.
  # This happens when permissive version constraints cause resolution in parent
  # directories to provide different versions in one subtree vs another.
  # This is unlikely to occur in small projects but you are almost guaranteed to
  # encounter this in a project with a large dependency graph.
  # For large projects you really need to be using `pinDepInfoTreeFromPlockV3'
  # instead of this routine.
  # The argument `conflictIsError' allows you to downgrade conflicts to be
  # warnings printed to stderr instead of a `throw'; but you'd better know what
  # you're doing.
  pinDepInfoSetFromPlockV3 = {
    plock           ? lib.importJSON "${lockDir}/package-lock.json"
  , lockDir         ? null
  , pinnedLock      ? lib.libplock.pinVersionsFromPlockV3 plock
  , conflictIsError ? true  # `false' prints a warning instead. See note above.
  }: let
    keyDepInfo = path: let
      key   = lib.libplock.getKeyPlV3 plock path;
      plent = plock.packages.${path};
      pinnedEnt = let
        ps     = joinPins pinnedLock.packages.${path};
        pinDep = ident: d:
          if ps ? ${ident} then d // { pin = ps.${ident}; } else d;
      in builtins.mapAttrs pinDep ( depInfoEntFromPlockV3 path plent );
    in if ( plent.link or false ) then {} else { ${key} = pinnedEnt; };
    merge = acc: path: let
      instance = keyDepInfo path;
      existing = builtins.intersectAttrs instance acc;
      key = builtins.head ( builtins.attrNames instance );
      rsl = instance // acc;
      msg = "pinDepInfoSetFromPlockV3: Conflicting instance for ${key}";
      hasConflict = ! ( builtins.elem existing [{} instance] );
      handleConflict =
        if conflictIsError then throw msg else builtins.trace msg rsl;
    in if hasConflict then handleConflict else rsl;
  in builtins.foldl' merge {} ( builtins.attrNames plock.packages );

in {
  inherit
    depInfoEntFromPlockV3
    depInfoTreeFromPlockV3
    depInfoSetFromPlockV3
    pinDepInfoTreeFromPlockV3
    pinDepInfoSetFromPlockV3
  ;
  inherit
    allDepFields
  ;
  runtimeFields  = rtFields;
  pinnableFields = pinFields;
  getBundledDeps = joinBund;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
