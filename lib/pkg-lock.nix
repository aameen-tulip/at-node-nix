# ============================================================================ #
#
# Routines related to scraping `package-lock.json' data.
# Note that there are 3 schema versions of locks, V1 and V3 are bridged by
# a V2 schema which is compatible with both.
# Comments below may refer to a routine as being for "V2", in retrospect this
# naming scheme was unhelpful - I ought to have said "V3".
# TODO: Rename these routines and patch asserts.
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
    e = plock.packages."${path}";
    entry = if e.link or false then plock.packages."${e.resolved}" else e;
  in assert supportsPlV3 plock;
     entry;


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
  # The values are unimportant here, and whether or not a lock has a field isn't
  # important either.
  # NOTE: We do not want to rewrite `peerDependencies' since we do not support
  # `--legacy-peer-deps' in these routines.
  # Legacy peer deps should be handled before invoking the pin routines by
  # adding missing peers to a lock in the appropriate dependency fields using
  # `peerDependenciesMeta' ( see `lib/pkginfo.nix' for these routines ).
  pinFields = {
    dependencies         = true;
    devDependencies      = true;
    optionalDependencies = true;
    requires             = true;  # V3
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

  # (V1) Same deal as the V3 form, except we use args `parentPath' and
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
  in if isSub then depEnt else
     # Failure case
     if ( fromPath == [] ) && ( ident != plock.name ) then null else
     fromParent;


# ---------------------------------------------------------------------------- #

  # (V3)
  # Convert version descriptors to version numbers based on a lock's contents.
  # This is used to isolate builds with a reduced scope to avoid
  # spurious rebuilds.
  # Without pins and isolated builds, any change to the lock would require all
  # packages with install scripts, builds, or prepare routines to be rerun;
  # by minimizing the derivation environments by packge we avoid rebuilds that
  # should have no effect on a package.
  pinVersionsFromPlockV3 = plock: let
    pinPath = { scope, ents } @ acc: path: let
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
      newScope = builtins.foldl' getVS scope depIds;
      pinned = let
        fields = builtins.intersectAttrs pinFields e;
        rewriteOne = _: ef: builtins.intersectAttrs ef newScope;
      in e // ( builtins.mapAttrs rewriteOne fields );
    in if ( e.link or false ) then acc else {
      scope = newScope;
      ents  = ents // { ${path} = pinned; };
    };
  in assert supportsPlV3 plock;
     plock // {
       packages = let
         paths = builtins.attrNames plock.packages;
         pinned = builtins.foldl' pinPath { scope = {}; ents = {}; } paths;
       in pinned.ents;
     };


# ---------------------------------------------------------------------------- #

  # FIXME: alter to handle V1 lock only.
  pinVersionsFromPlockV2 = plock: let
    pinEnt = from: {
      version
    , dependencies    ? {}
    , devDependencies ? {}
    , name            ? pathId from
    , ...
    } @ ent: let
      #pin = resolvePkgVersionFor { inherit from plock; };
      pin = ident: ( resolveDepForPlockV3 plock from ident ).version;
      pinDep = ident: descriptor:
        if builtins.isString descriptor then pin ident else descriptor.version;
      rt' = lib.optionalAttrs ( dependencies != {} ) {
        runtimeDepPins =
          builtins.mapAttrs pinDep
            ( lib.filterAttrs ( _: v: ! ( v.dev or false ) ) dependencies );
      };
      hasNormalizedDev =
        builtins.any ( v: v.dev or false ) ( builtins.attrValues dependencies );
      dev' =
        lib.optionalAttrs ( hasNormalizedDev || ( devDependencies != {} ) ) {
          devDepPins = let
            dd = builtins.mapAttrs pinDep devDependencies;
            d = builtins.mapAttrs pinDep
                  ( lib.filterAttrs ( _: v: ( v.dev or false ) ) dependencies );
          in dd // d;
        };
    in { key = "${name}/${version}"; inherit name version; } // rt' // dev';
    pinned = builtins.mapAttrs pinEnt plock.packages;
    renamed = let
      renameFromKey = { key, ... } @ value: {
        name  = key;
        value = removeAttrs value ["pkey" "key" "name" "version"];
      };
    in builtins.listToAttrs
      ( map renameFromKey ( builtins.attrValues pinned ) );
    # This routine identifies "conflicting instances" of packages with ambiguous
    # resolution in a lockfile.
    # These are a sibling of the "ABI Conflicts" from compiled languages
    # ( likely the most dangerous category of undefined behavior ).
    # NPM and Yarn produce no erros or warnings about these conflicts and only
    # concern themselves with Node's ABI ( using the `engines' field ); I have a
    # far more skeptical attitude and am temporarily emitting warnings which I
    # will later turn to errors.
    # Reliance on "conflicting instances" indicates that a project has sprawled
    # without sane regard for interface design; if you file a PR confused about
    # why the 8 conflicting versions of NaN aren't resolving against multiple
    # same version instances of `foo' the way they did with NPM, I'm just going
    # to say "cool I'm glad I could help you locate lurking UB in your codebase".
    instances = let
      pushDownPkey =
        builtins.mapAttrs ( pkey: v: v // { inherit pkey; } ) pinned;
      kg = builtins.groupBy ( x: x.key ) ( builtins.attrValues pushDownPkey );
      count = _: gents: let
        all = builtins.length gents;
        uniq = lib.unique ( map ( m: removeAttrs m ["pkey"] ) gents );
      in ( 1 < all ) && ( 1 < ( builtins.length uniq ) );
      need = lib.filterAttrs count kg;
      byPkey = _: builtins.listToAttrs ( { pkey, ... } @ value: {
        name = pkey;
        value.instances = removeAttrs value ["pkey" "key" "name" "version"];
      } );
      insts = builtins.mapAttrs byPkey need;
      warn =
        "WARNING: Conflicting instances of packages were detected in your lock"
        + "\nXXX: Seriously, I know you blow off warnings, this is actually "
        + "bad and you need to take immediate action.";
    in if ( insts != {} ) then builtins.trace warn insts else {};
  in renamed // instances; # this clobbers


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
    pinVersionsFromPlockV2
    pinVersionsFromPlockV3
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
