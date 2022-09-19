# ============================================================================ #
#
# Returns `pkgEnt' or `(pkg|meta)Set' keys assigned as `node_modules/' paths
# reflecting the structure of the given lock file.
#
# This should be used for creating the `nodeModulesDir[-dev]' derivations
# for packages which are the "root" of a package lock.
#
# ---------------------------------------------------------------------------- #
#
# TERMS:
#   - plock:  package-lock.json
#   - v3/pl3: package-lock.json shema version 3 used by NPM.
#             NOTE: A v2 lock is compatible with v3 and be used.
#   - key:    a `(meta|pkg)Set' attribute key ( pkgSet.${key} ==> pkgEnt )
#             These are used to uniquely identify packages.
#             They are simply "<IDENT>/<VERSION>" strings.
#   - ident:  package identifier or "name" ( name field from package.json ).
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  # Given a `package-lock.json(v2/3)' produce an attrset representing a
  # `node_modules/' directory.
  # Outputs `{ "node_modules/<IDENT>" = "<IDENT>/<VERSION>" (pkey); ... }'
  # mappings which reflect the `packages' field in the lock.
  # This funcion is intended for use with `node_modules/' builders such as
  # `mkNmDir', which can easily replace keys with store-paths built by Nix.
  #
  # This function also provides the opportunity to filter out entries such as
  # `dev(Dependencies)', `optionalDependencies', and arbitrary keys or idents
  # that the caller may specify.
  # These can be used mimic the behavior of various NPM and Yarn install flags.
  #
  # NOTE: This function does not require that `metaSet' be passed.
  # If it is omitted we'll detect `__rootKey' from `plock'.
  idealTreePlockV3 = {
    plock  ? args.__meta.plock or
             ( if metaSet != null then metaSet.__meta.plock
               else lib.importJSON' "${lockDir}/package-lock.json" )
  , lockDir ? throw "You must provide an arg for me to find your package lock"
  # XXX: `metaSet' is optional when you provide `plock'.
  , metaSet ? if ( args ? _type ) && ( args._type == "metaSet" ) then args
                                                                 else null
  # Used to avoid dependency cycles with the root package.
  # NOTE: If you REALLY don't want `rootKey' to be omitted set this to `null'.
  # In theory we could leave this entry but in practice you'll almost never find
  # a use case for this function that doesn't fall into infinite recursion when
  # the the root key is preserved.
  # This could be handled more gracefully by a more robust `mkNmDir'
  # implementation that created symlinks to the source directory; but frankly
  # dependency cycles like this are fucking evil.
  , rootKey ? if metaSet != null then metaSet.__meta.rootKey else
              "${plock.name}/${plock.version}"
  # Whether to include `dev' dependencies in tree.
  # Setting this to `false' will produce the equivalent of `--omit-dev'.
  , dev ? true
  # Keys to ignore.
  # By default we ignore the "root" key to break cycles; but projects shouldn't
  # depend on this feature because they're not going to be able to break
  # "build cycles" this way; only runtime cycles.
  # NOTE: `rootKey' set to `null' implies that it should be preserved.
  , ignoredKeys ? lib.optionals ( rootKey != null ) [rootKey]
  , ignoredIdents ? []  # Ignored regardless of version.

  # The remaining args relate to `optionalDependencies' and deciding if/when to
  # drop them from a tree.
  # This boolean toggles filtering ( "skipping" ) on/off entirely.
  # If we aren't provided with enough info to guess the OS/CPU then we won't
  # filter out any pacakges.
  # It is recommended that you pass `npmSys', `hostPlatform', or `system' for us
  # to try and derive.
  , skipUnsupported ? npmSys != null
  # FIXME: handle `engines'?
  , npmSys ? lib.getNpmSys' args
  # Filter out usupported systems. Use "host" platform.
  # The user is also free to pass arbitrary conditionals in here if they like.
  # These have the highest priority and will clobber earlier args.
  # The default is almost certainly what you want to use though.
  # If CPU or OS could not be determined, these conditionals filter nothing.
  , sysCond ? pjs: lib.pkgSysCond pjs npmSys
  # These are used by the `getNpmSys' fallback and must be declared for
  # `callPackage' and `functionArgs' to work - see `lib/system.nix' for more
  # more details. PREFER: `system' and `hostPlatform'.
  , system ? null, hostPlatform ? null, buildPlatform ? null
  , cpu ? null, os ? null, enableImpureMeta ? null, stdenv ? null
  , flocoConfig ? null
  , ...
  } @ args: let

    # Get a package identifier from a `package-lock.json(v3)' entry.
    getIdent = dir: {
      #ident ? plent.name or ( lib.libplock.pathId dir )
      ident ? plent.name or ( lib.lookupRelPathIdentV3 plock dir )
    , ...
    } @ plent: ident;
    # Get a `(pkg|meta)Set' key from a `package-lock.json(v3)' entry.
    getKey = dir: {
      version ? ( lib.libplock.realEntry plock dir ).version
    , ident   ? getIdent dir plent
    , ...
    } @ plent:
      "${ident}/${version}";
    # Collect a list of paths that need to be dropped as a result of
    # `optionalDependencies' filtering ( using `sysCond' ) as well as any
    # `ignoed(Keys|Idents)' matches.
    # We need this list so that we can perform a second pass which also drops
    # any `node_modules/' subdirs associated with these packages.
    # Dev/Prod filtering doesn't need to be handled here, since the plock
    # contains `dev' fields for all paths already, which accounts for subdirs.
    drops = let
      pjsPkgs = removeAttrs plock.packages [""];
      isUnsupported = _: { optional ? false, ... } @ e:
        optional && ( ! ( sysCond e ) );
      unsupported = lib.filterAttrs isUnsupported pjsPkgs;
      isIgnored = k: v: let
        ik = builtins.elem ( getKey k v )   ignoredKeys;
        ii = builtins.elem ( getIdent k v ) ignoredIdents;
      in ii || ik;
      ignored = lib.filterAttrs isIgnored pjsPkgs;
      ients = if skipUnsupported then ignored // unsupported else ignored;
      # We're only interested in the keys.
      ipaths = builtins.attrNames ients;
      wois   = removeAttrs pjsPkgs ipaths;
      isISub = p: builtins.any ( i: lib.hasPrefix i p ) ipaths;
      subs   = builtins.filter isISub ( builtins.attrNames wois );
    in [""] ++ ipaths ++ subs;
    # Filter `package-lock.json(v3)' entries to deps we want to install.
    nml = let
      # Drop root entry.
      # This is unrelated to avoiding cycles with `ignore*'.
      # The `package-lock.json(v3)' includes an entry representing the `lockDir'
      # which we aren't interested in preserving.
      wois = removeAttrs plock.packages drops;
      # Drop dev dependencies if `dev = false'.
      isDevProd = _: v: ! ( v.dev or false );
    in if dev then wois else lib.filterAttrs isDevProd wois;
    treeKeyed = builtins.mapAttrs getKey nml;
  in assert lib.libplock.supportsPlV3 plock;
     treeKeyed;


# ---------------------------------------------------------------------------- #

in {
  inherit
    idealTreePlockV3
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
