# ============================================================================ #
#
# Returns `pkgEnt' or `(pkg|meta)Set' keys assigned as `node_modules/' paths
# reflecting the structure of the given lock file.
#
# This should be used for creating the `nodeModulesDir[-dev]' derivations
# for packages which are the "root" of a package lock.
#
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
  # NOTE: This function does not require that `metaSet' be passed, don't let the
  # `throw' spook you.
  # FIXME: If `metaSet' isn't passed I haven't written a snippet to yank
  # the root key from the lock yet.
  # This isn't hard I just haven't dont it.
  idealTreeMetaSetPlockV2 = {
    plock   ? args.__meta.plock or metaSet.__meta.plock
  # `metaSet' is optional if you provide `plock'.
  , metaSet ? if args ? __meta.setFromType then args else
                 throw "I need a metaSet to detect rootKey"

  # Whether to include `dev' dependencies in tree.
  # Setting this to `false' will produce the equivalent of `--omit-dev'.
  , dev ? true

  # Keys to ignore.
  # By default we ignore the "root" key to break cycles; but projects shouldn't
  # depend on this feature because they're not going to be able to break
  # "build cycles" this way; only runtime cycles.
  # FIXME: derive `rootKey' from lock.
  , ignoredKeys ?
      lib.optionals ( ( args ? metaSet ) || ( args ? __meta.setFromType ) ) [
        metaSet.__meta.rootKey
      ]
  # Ignored regardless of version.
  , ignoredIdents ? []

  # The remaining args relate to `optionalDependencies' and deciding if/when to
  # drop them from a tree.
  # This boolean toggles filtering ( "skipping" ) on/off entirely.
  # If we aren't provided with enough info to guess the OS/CPU then we won't
  # filter out any pacakges.
  #
  # You can comb through the conditionals to see the fallback behavior, but
  # the priority is:
  #   (os|cpu)Cond
  #   os|cpu
  #   system
  #   targetPlaform  ( generally yanked from `stdenv' )
  #   hostPlaform    ( generally yanked from `stdenv' )
  #   buildPlaform   ( generally yanked from `stdenv' )
  #
  # Personally, I would pass `system' here unless you're cross-compiling, in
  # which case you'll want to pass `targetPlatform'.

  # Filter out usupported systems. Use "target" platform.
  , skipUnsupported ? ( cpu != null ) || ( os != null )

  # FIXME: You could refer to `config' here to check if impure is allowed.
  , system          ? null
  # Priority for platforms aligns with Nixpkgs' fallbacks
  , buildPlatform   ? null
  , hostPlatform    ? buildPlatform
  , targetPlatform  ? hostPlatform

  , cpu ?
      if args ? system then getNpmCpuForSystem system else
      if targetPlatform != null then getNpmCpuForPlatform targetPlatform else
      null
  , os ?
      if args ? system then getNpmOSForSystem system else
      if targetPlatform != null then getNpmOSForPlatform targetPlatform else
      null
  # The user is also free to pass arbitrary conditionals in here if they like.
  # The default is almost certainly what you want to use though.
  # If CPU or OS could not be determined, these conditionals filter nothing.
  , cpuCond ? supportedCpus:
      if cpu == null then true else builtins.elem cpu supportedCpus
  , osCond ? supportedOss:
      if os == null then true else builtins.elem os supportedOss
  # FIXME: handle `engines'?
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
      full = removeAttrs plock.packages [""];
      # Drop dev dependencies if `dev = false'.
      isDevProd = _: v: if dev then true else ! ( v.dev or false );
      # Drop deps intended for unsupported systems.
      isSupported = _: v: let
        opt     = v.optional or false;
        suppCpu = if v ? cpu then cpuCond v.cpu else true;
        suppOs  = if v ? os  then osCond  v.os  else true;
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
