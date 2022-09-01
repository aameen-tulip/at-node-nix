# ============================================================================ #
#
# Routines related to scraping `package-lock.json' data.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  # Because `package-lock.json(V2)' supports schemas v1 and v3, these helpers
  # shorten schema checks.

  supportsPlV1 = { lockfileVersion, ... }:
    ( lockfileVersion == 1 ) || ( lockfileVersion == 2 );

  supportsPlV3 = { lockfileVersion, ... }:
    ( lockfileVersion == 2 ) || ( lockfileVersion == 3 );


# ---------------------------------------------------------------------------- #

  # Some V3 Helpers

  # (V3) Helper that follows linked entries.
  # If you look in the `package.*' attrs you'll see symlink entries use the
  # `resolved' field to point to out of tree directories, and do not contain
  # any other package information.
  # This helps us fetch the "real" entry so we can look up metadata.
  realEntry = plock: path: let
    e = plock.packages.${path};
    entry = if e.link or false then plock.packages.${e.resolved} else e;
  in assert supportsPlV3 plock;
     entry;


  subdirsOfPathPlockV3' = { plock, path }:
    builtins.filter ( lib.hasPrefix path )
                    ( builtins.attrNames plock.packages );
  subdirsOfPathPlockV3 = x:
    if ( x ? plock ) && ( x ? path ) then subdirsOfPathPlockV3' x else
    path: subdirsOfPathPlockV3 { plock = x; inherit path; };


# ---------------------------------------------------------------------------- #

  # Schema Indepent Helpers

  # From a "node_modules/foo/node_modules/@bar/quux" path, get "@bar/quux".
  pathId = lib.yank ".*node_modules/(.*)";

  # Drop one trailing nmDir layer as:
  #   "node_modules/foo/node_modules/@bar/quux" -> "node_modules/foo".
  # Used to find "the parent dir of a subdir".
  # Return `null' if path is the root.
  # Returns "" for a child of the root. 
  parentPath = p: let
    m = lib.yank "(.*)/node_modules/(@[^/]+/)?[^/]+" p;
  in if p == "" then null else if m == null then "" else m;

  # Given a `node_modules/foo/node_modules/@bar/quux/...' path ( string ), split
  # to a list of identifiers with the same hierarcy.
  # In the example above we expect `["foo" "@bar/quux"]'.
  splitNmToIdentPath = nmpath: let
    sp = builtins.tail ( lib.splitString "node_modules/" nmpath );
    stripTrailingSlash = s: let
      m = lib.yank "(.*[^/])/" s;
    in if m == null then s else m;
  in map stripTrailingSlash sp;

  # Fields that `pinVersionsFromPlockV(1|3)' functions should rewrite.
  # NOTE: We do not want to rewrite `peerDependencies' since we do not support
  # `--legacy-peer-deps' in these routines.
  # Legacy peer deps should be handled before invoking the pin routines by
  # adding missing peers to a lock in the appropriate dependency fields using
  # `peerDependenciesMeta' ( see `lib/pkginfo.nix' for these routines ).
  pinFields = {
    dependencies         = true;
    devDependencies      = true;
    optionalDependencies = true;
    requires             = true;
    # XXX: Do not pin peer deps.
  };


# ---------------------------------------------------------------------------- #

  # (V3)
  # Starting at `from' directory/package in the `node_modules/' tree, resolve
  # `ident' and return the associated entry.
  # Node resolution searches for modules first in `<FROM>/node_modules/' if one
  # exists ( top level only, not recursively ) and if a module is not found it
  # begins searching "up" in parent dirs until the filesystem root is reached.
  # In Nix builds we use isolated builds under `/tmp/' at build time or
  # `/nix/store/' at runtime so in theory we should only care about the entries
  # in our lock when searching "up".
  # In any case the builders in this framework actually enforce sandboxing so
  # we actually can rely on this.
  # Returns `null' if resolution fails.
  resolveDepForPlockV3 = plock: from: ident: let
    asSub = let
      # We can't do "${from}/..." because `from' may be "".
      fs = if from == "" then "" else "${from}/";
    in "${fs}node_modules/${ident}";
    # Traverse towards parents to resolve. ( Only if `ident' isn't a subdir )
    fromParent = let
      pf = parentPath from;
    in if from != "" then resolveDepForPlockV3 plock pf ident else
       # Handle attempts to resolve "`from' from `from'" ( love it )
       if ident != plock.name then null else {
         inherit ident;
         resolved = "";
         value    = plock.packages."";
       };
  in assert supportsPlV3 plock;
     if from == null then null else
     if ( ! ( plock.packages ? ${asSub} ) ) then fromParent else {
       inherit ident;
       resolved = asSub;
       value    = realEntry plock asSub;
     };


# ---------------------------------------------------------------------------- #

  # (V1)
  # Same deal as the V3 form, except we use args `parentPath' and
  # `fromPath' and traverse `dependencies' fields instead of `packages' field.
  # Because this form is a hierarchy of attrs is a little bit of a pain; but
  # it's more of less the same process.
  # The only real "gotcha" is that V1 schema uses `dependencies' field for
  # subdirs ( with nested entries ), and `requires' fields ( descriptors only )
  # for resolutions in parent dirs.
  # This function accepts `from' as a V3 style path optionally and will convert
  # it for you, but the `fromPath' argument is faster, if you are performing
  # several calls it may be more efficient to pre-process your args this way.
  resolveDepForPlockV1 = {
    plock
  , from       ? ""
  , parentPath ? lib.take ( ( builtins.length fromPath ) - 1 ) fromPath
  , fromIdent  ? if from == "" then plock.name else pathId from
  , fromPath   ?
      if ctx ? parentPath then ( parentPath ++ [fromIdent] ) else
      ( splitNmToIdentPath from )
  , ent ? if fromPath == [] then plock else
    lib.getAttrFromPath ( lib.intersperse "dependencies" fromPath )
                        plock.dependencies
  } @ ctx: ident: let
    # NOTE: because we want the real entry we only look at `dependencies' and
    # not `requires'; instead we let recursion get the real entry for us.
    isSub = ent ? dependencies.${ident};
    depEnt = {
      inherit ident;
      resolved = let
        # NOTE: "" case is handled below don't sweat it here.
        isp = lib.intersperse "/node_modules/" ( fromPath ++ [ident] );
      in "node_modules/${builtins.concatStringsSep "" isp}";
      value = ent.dependencies.${ident};
    };
    fromParent = if ( fromPath == [] ) && ( ident == plock.name ) then {
      inherit ident;
      resolved = "";
      value = plock;
    } else resolveDepForPlockV1 { inherit plock; fromPath = parentPath; } ident;
  in assert supportsPlV1 plock;
     if isSub then depEnt else
     # Failure case
     if ( fromPath == [] ) && ( ident != plock.name ) then null else
     fromParent;


# ---------------------------------------------------------------------------- #

  # (V1)
  # Rewrite all `requires' fields with resolved versions using lock entries.
  pinVersionsFromPlockV1 = plock: let
    pinEnt = scope: e: let
      depAttrs = removeAttrs ( builtins.intersectAttrs pinFields e )
                             ["requires"];
      # Extend parent scope with our subdirs to pass to children.
      newScope = let
        depVers = builtins.mapAttrs ( _: { version, ... }: version );
      in builtins.foldl' ( a: b: a // ( depVers b ) ) scope
                         ( builtins.attrValues depAttrs );
      # Pin our requires with actual versions.
      pinned = let
        deps = builtins.mapAttrs ( _: builtins.mapAttrs ( _: pinEnt newScope ) )
                                 depAttrs;
        req  = lib.optionalAttrs ( e ? requires ) {
          requires = builtins.intersectAttrs e.requires scope;
        };
      in e // deps req;
    in pinned;
    rootEnt = lib.optionalAttrs ( plock ? name ) {
      ${plock.name} = plock.version or
                      ( throw "No version specified for ${plock.name}" );
    };
    # The root entry has a bogus `requires' field in V2 locks which needs to
    # be hidden while running `pinEnt'.
    # This stashes the value to be restored later.
    rootReq = lib.optionalAttrs ( plock ? requires ) {
      inherit (plock) requires;
    };
    pinnedLock = pinEnt rootEnt ( removeAttrs plock ["requires"] );
  in assert supportsPlV1 plock;
     pinnedLock // rootReq;


# ---------------------------------------------------------------------------- #

  # (V3)
  # Convert version descriptors to version numbers based on a lock's contents.
  # This is used to isolate builds with a reduced scope to avoid
  # spurious rebuilds.
  # Without pins and isolated builds, any change to the lock would require all
  # packages with install scripts, builds, or prepare routines to be rerun.
  # By minimizing the derivation environments we avoid rebuilds that should have
  # no effect on a package.
  pinVersionsFromPlockV3 = plock: let
    pinPath = { scopes, ents } @ acc: path: let
      e = plock.packages.${path};
      # Get versions of subdirs and add to current scope.
      # This wipes out packages with the same ident in the same way that the
      # Node resolution algorithm does.
      depIds = builtins.attrNames ( ( e.dependencies or {} )    //
                                    ( e.devDependencies or {} ) //
                                    ( e.optionalDependencies or {} ) );
      getVS = scope': ident: let
        fs = if path == "" then "" else "${path}/";
      in scope' // {
        ${ident} = ( realEntry plock "${fs}node_modules/${ident}" ).version;
      };
      # Fetch parent scope and extend it with our subdirs.
      parentScope = if path == "" then {} else scopes.${parentPath path};
      newScope    = builtins.foldl' getVS parentScope depIds;
      # Pin our dependency fields with actual versions.
      pinned = let
        fields     = builtins.intersectAttrs pinFields e;
        rewriteOne = _: ef: builtins.intersectAttrs ef newScope;
      in e // ( builtins.mapAttrs rewriteOne fields );
      # Skip link entries, we will pin the "real" entry which users will locate
      # using `realEntry'.
      optNotLink = lib.optionalAttrs ( ! ( e.link or false ) );
    in {
      # I believe still need to record the scope of link entries.
      # XXX: This might not really be necessary, but I haven't tested and would
      # like to err on the safe side until I do.
      scopes = scopes // { ${path} = newScope; };
      ents   = ents // ( optNotLink { ${path} = pinned; } );
    };
  in assert supportsPlV3 plock;
     plock // {
       # Replace `packages' field with updated entries.
       # We update rather than replace because we skipped creating `link'
       # entries and want to preserve the old values.
       packages = let
         paths  = builtins.attrNames plock.packages;
         pinned = builtins.foldl' pinPath { scopes = {}; ents = {}; } paths;
       in plock.packages // pinned.ents;
     };


# ---------------------------------------------------------------------------- #

in {
  inherit
    supportsPlV1
    supportsPlV3
    realEntry
    pathId
    parentPath
    resolveDepForPlockV1
    resolveDepForPlockV3
    splitNmToIdentPath
    pinVersionsFromPlockV1
    pinVersionsFromPlockV3
    subdirsOfPathPlockV3
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
