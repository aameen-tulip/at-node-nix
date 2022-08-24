# ============================================================================ #
#
# Returns `pkgEnt' or `(pkg|meta)Set' keys assigned as `node_modules/' paths
# reflecting the structure of the given lock file.
#
# This should be used for creating the `nodeModulesDir[-dev]' derivations
# for packages which are the "root" of a package lock.
#
#
# FIXME: The CPU/OS detection routines amount to half of the code here.
#        They should be moved to a lib because it would be obnoxious to try and
#        keep the fallback pattern/methods used here aligned with other parts of
#        the codebase if they're all done ad-hoc.
#
# ---------------------------------------------------------------------------- #
#
# TERMS:
#   - plock:  package-lock.json
#   - v2/pl2: package-lock.json shema version 2 used by NPM.
#             This version is a hybrid that is the union of a v1 and v3 lock.
#   - key:    a `(meta|pkg)Set' attribute key ( pkgSet.${key} ==> pkgEnt )
#             These are used to uniquely identify packages.
#             They are simply "<IDENT>/<VERSION>" strings.
#   - ident:  package identifier or "name" ( name field from package.json ).
#
# ---------------------------------------------------------------------------- #

{ lib, config ? {}, ... } @ globalAttrs: let

# ---------------------------------------------------------------------------- #

  # Given a `package-lock.json(v2)' tproduce an attrset representing a
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
  idealTreeMetaSetPlockV2 = {
    plock ? args.__meta.plock or metaSet.__meta.plock
  # XXX: `metaSet' is optional when you provide `plock'.
  , metaSet ? if args ? __meta.setFromType then args else null
  # Used to avoid dependency cycles with the root package.
  # NOTE: If you REALLY don't want `rootKey' to be omitted set this to `null'.
  # In theory we could leave this entry but in practice you'll almost never find
  # a use case for this function that doesn't fall into infinite recursion when
  # the the root key is preserved.
  # This could be handled more gracefully by a more robust `mkNmDir'
  # implementation that created symlinks to the source directory; but frankly
  # dependency cycles like this are fucking evil.
  # Projects that have dependency cycles are incredibly fragile and it is
  # incredibly rare that the bootstrap process they demand is warranted
  # ( compilers and core build utilities are almost exclusively the exception ).
  # Don't file a bug report complaining about them, I'm just going to tell you
  # to refactor your codebase or make snide remarks about how your org has a
  # "staffing issue".
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

  # You can comb through the conditionals to see the fallback behavior, but
  # the priority is:
  #   (os|cpu)Cond
  #   os|cpu
  #   system
  #   targetPlaform  ( from `stdenv'. `(host|build)Platform' are fallbacks )
  #   config.system or builtins.currentSystem if config.enableImpureMeta = true.
  #
  # Personally, I would pass `system' here unless you're cross-compiling, in
  # which case you'll want to pass `targetPlatform'.

  # Filter out usupported systems. Use "target" platform.
  , skipUnsupported ? ( cpu != null ) || ( os != null )

  , system ? config.system or
             ( if enableImpureMeta then builtins.currentSystem else null )
  # Priority for platforms aligns with Nixpkgs' fallbacks
  , buildPlatform  ? null
  , hostPlatform   ? buildPlatform
  , targetPlatform ? hostPlatform

  , cpu ?
      if args ? system then lib.getNpmCpuForSystem system else
      if targetPlatform != null then lib.getNpmCpuForPlatform targetPlatform
      else system  # `system' bottoms out to `null' in pure mode.
  , os ?
      if args ? system then lib.getNpmOSForSystem system else
      if targetPlatform != null then lib.getNpmOSForPlatform targetPlatform else
      system  # `system' bottoms out to `null' in pure mode.
  # The user is also free to pass arbitrary conditionals in here if they like.
  # These have the highest priority and will clobber earlier args.
  # The default is almost certainly what you want to use though.
  # If CPU or OS could not be determined, these conditionals filter nothing.
  , cpuCond ? supportedCpus:
      if cpu == null then true else builtins.elem cpu supportedCpus
  , osCond ? supportedOss:
      if os == null then true else builtins.elem os supportedOss
  # FIXME: handle `engines'?

  # More junk used to derive `system'.
  , config           ? globalAttrs.config or {}
  , enableImpureMeta ? config.enableImpureMeta or false
  , ...
  } @ args: let
    # Get a package identifier from a `package-lock.json(v2)' entry.
    getIdent = dir: {
      ident ? pl2ent.name or lib.yank ".*node_modules/((@[^/]+/)?[^/]+)" dir
    , ...
    } @ pl2ent: ident;
    # Get a `(pkg|meta)Set' key from a `package-lock.json(v2)' entry.
    getKey = dir: { version, ident ? getIdent dir pl2ent, ... } @ pl2ent:
      "${ident}/${version}";
    # Filter `package-lock.json(v2)' entries to deps we want to install.
    nml = let
      # Drop root entry.
      # This is unrelated to avoiding cycles with `ignore*'.
      # The `package-lock.json(v2)' includes an entry representing the `lockDir'
      # which we aren't interested in preserving.
      full = removeAttrs plock.packages [""];
      # Drop dev dependencies if `dev = false'.
      isDevProd = _: v: if dev then true else ! ( v.dev or false );
      # Drop deps intended for unsupported systems.
      isSupported = _: v: let
        opt     = v.optional or false;
        suppCpu = if v ? cpu then cpuCond v.cpu else true;
        suppOs  = if v ? os  then osCond  v.os  else true;
        # FIXME: Handle engines?
      in if ( ! skipUnsupported ) || ( ! opt ) then true else
         suppCpu && suppOs;
      # Handle `ignoredKeys'.
      isKeep = k: v:
        ( ! ( builtins.elem ( getKey k v )   ignoredKeys ) ) &&
        ( ! ( builtins.elem ( getIdent k v ) ignoredIdents ) );
      # All together now.
      cond = k: v: ( isDevProd k v ) && ( isSupported k v ) && ( isKeep k v );
    in lib.filterAttrs cond full;
  in builtins.mapAttrs getKey nml;


# ---------------------------------------------------------------------------- #

in {
  inherit
    idealTreeMetaSetPlockV2
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
