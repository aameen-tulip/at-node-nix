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

  # TODO: paths like `../foo' explode which makes sense, but we need a good
  # error message.
  parentNmDir = nmdir: let
    loc     = "at-node-nix#lib.libtree.parentNmDir";
    nmpatt  = "node_modules|\\$node_modules_path";
    parent  = lib.yank "(.*${nmpatt})/(@[^@/]+/)?[^@/]+" nmdir;
    noNest  = lib.test ".*/(${nmpatt})/(${nmpatt})/.*" ( "/" + nmdir + "/" );
    msgNest = "(${loc}): Illegal nesting of NM dirs: '${nmdir}'";
    above   = lib.hasPrefix "../" nmdir;
    msgCeil = "(${loc}): Illegal out of tree path: '${nmdir}'";
  in if above then throw msgCeil else if noNest then throw msgNest else parent;

  asDollarNmDir = nmdir: let
    loc        = "at-node-nix#lib.libtree.asDollarNmDir";
    above      = lib.hasPrefix "../" nmdir;
    msgCeil    = "(${loc}): Illegal out of tree path: '${nmdir}'";
    was        = lib.hasPrefix "$node_modules_path" nmdir;
    m          = builtins.match "(node_modules)?/([^/].*)" nmdir;
    stripFirst = builtins.elemAt m 1;
    result     = if was then nmdir else "$node_modules_path/" + stripFirst;
  in if above then throw msgCeil else
     if m == null then "$node_modules_path" else result;


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
  idealTreePlockV3 = let
    ldmsg = "(idealTreePlockV3): You must provide an arg for me to find " +
            "your package lock. Recommended: `lockDir = <PATH>;'.";
  in {
    plock  ? args.__meta.plock or
             ( if metaSet != null then metaSet.__meta.plock
               else lib.importJSON' "${lockDir}/package-lock.json" )
  , lockDir ? throw ldmsg
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

  # XXX: You don't want to turn this on if you plan to use the tree in
  # Nix builders.
  # "Out of tree paths" are any which use `../', which can't exist in a
  # sandboxed build environment.
  # If you try to reference `../' you'll get killed by about a dozen other
  # assertions across this framework, and even if you did manage to dodge them
  # Nix will strike down your build user with righteous fury.
  # "BuT I wAnT tO dO WoRkSpAcEs", you still can, you just have to regen your
  # lock with `--install-links', or you need to drive your build from the root
  # of your workspace ( you want to do the second option if you're unsure ).
  # This isn't a `floco' restriction, NPM and Yarn use the same "focus" routine
  # as we do for tree reformation - you're welcome to use it, but you aren't
  # welcome to file issues about it, I'm just going to direct you to the NPM
  # and Yarn issue lists where hundreds of webshits collectively learned what
  # an "ABI Conflict" was over the span of several years.
  # The ABI conflicts "grafting" causes in `node-gyp' builds and similarly
  # "(trans|com)piled" code is a closely monitored and meticulously managed
  # issue in compiled languages, and was one of the original use cases for Nix.
  # Grafting is only safe under explicit supervision, and should not be
  # performed as a part of any fully automated CI/CD process.
  # ^^^ Don't turn this on without reading the warning.
  , preserveOutOfTreePaths ? false  # TODO: enforce it

  # The remaining args relate to `optionalDependencies' and deciding if/when to
  # drop them from a tree.
  # This boolean toggles filtering ( "skipping" ) on/off entirely.
  # If we aren't provided with enough info to guess the OS/CPU then we won't
  # filter out any pacakges.
  # It is recommended that you pass `npmSys', `hostPlatform', or `system' for us
  # to try and derive.
  , skipUnsupported ? npmSys != null

  # TODO: handle `engines'?
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
    # Takes tree like `path: ent:' args, falling back to lockfile lookups.
    getIdent = lib.libplock.getIdentPlV3' plock;
    # Get a `(pkg|meta)Set' key from a `package-lock.json(v3)' entry.
    getKey   = lib.libplock.getKeyPlV3' plock;

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
      # Handles "no out of tree paths"
      above = lib.filterAttrs ( k: v: lib.hasPrefix "../" k ) wois;
      oot   = if preserveOutOfTreePaths then [] else builtins.attrNames above;
    in [""] ++ ipaths ++ subs ++ oot;
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

  # Returns the prod and dev tree from a `package-lock.json'.
  # The output format is convenient for merging with a `metaSet'.
  treesFromPlockV3 = { plock , flocoConfig ? lib.flocoConfig }: let
    ident   = plock.name or plock.packages."".name;
    version = plock.version or plock.packages."".version;
  in {
    rootKey = "${ident}/${version}";
    trees.prod = lib.libtree.idealTreePlockV3 {
      inherit plock flocoConfig;
      dev = false;
    };
    trees.dev = lib.libtree.idealTreePlockV3 { inherit plock flocoConfig; };
  };


# ---------------------------------------------------------------------------- #

  # Doesn't handle any conditionals, just package identifiers.
  # If a package appears multiple times at different versions we throw an error.
  genMkNmDirArgsSimple' = { keyTree }: let
    keys    = builtins.attrValues keyTree;
    byId    = builtins.groupBy dirOf keys;
    isUniq  = vs: builtins.all ( v: v == ( builtins.head vs ) ) vs;
    allUniq = builtins.all isUniq ( builtins.attrValues byId );
    proc    = acc: key: acc // { ${dirOf key} = false; };
    fargs   = builtins.foldl' proc {} keys;
    loc     = "at-node-nix#lib.libtree.genMkNmDirArgsSimple";
  in if allUniq then fargs else
     # If you need multiple versions of a package in a tree don't use "simple".
     throw "(${loc}): Multiple versions of a package appeared in tree";

  genMkNmDirArgsSimple = {
    __functionArgs.keyTree = false;
    __innerFunction = genMkNmDirArgsSimple';
    # TODO: run typecheck or something
    __processArgs = self: x: if x ? keyTree then x else { keyTree = x; };
    __functor     = self: x: self.__innerFunction ( self.__processArgs self x );
  };


# ---------------------------------------------------------------------------- #

  # TODO: `mkAbstractTree'
  #
  # Form an abstract `node_modules/' tree which may use conditionals
  # describe outpaths.
  # For example:
  #   {
  #     "node_modules/@foo/bar" = {
  #       ident   = i:   i == "@foo/bar";
  #       version = v:   lib.libsemver.semverSatExact "4.2.0" v;  # `=='
  #       os      = os:  builtins.elem os ["darwin"];
  #       cpu     = cpu: builtins.elem cpu ["aarch64" "x86_64"];
  #       node    = v:   lib.libsemver.semverSatGe "14" v;  # `>=14'
  #       mode    = m:   m == "prod";  # `! dev'
  #     };
  #   }
  #
  # As input we can accept `package.json' ( normalized ) fields which align with
  # those used by the NPM package registry.
  # This means we expect fields to be normalized and semver strings to be
  # "cleaned" BEFORE they are passed to us.
  # These fields align precisely with those found in a `package-lock.json(v3)'.
  # The `packages.*' field is ideal since it already "pins" version numbers,
  # but you could also pass in ( cleaned ) descriptors.
  # This input should yield the results given above:
  #  {
  #    "node_modules/@foo/bar" = {
  #      version = "4.2.0";
  #      os      = ["darwin"];
  #      cpu     = ["arm64" "x64"];
  #      node    = ">=14";
  #    };
  #  }


# ---------------------------------------------------------------------------- #

in {
  inherit
    parentNmDir
    asDollarNmDir
    idealTreePlockV3
    treesFromPlockV3
    genMkNmDirArgsSimple
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
