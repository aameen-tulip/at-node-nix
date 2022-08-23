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

{ lib }: let

# ---------------------------------------------------------------------------- #

  idealTreeMetaSetPlockV2 = {
    subdir     ? throw "You gotta let me know which lock to use"
  , metaSet    ? if args ? __meta.setFromType then args else
                 throw "I need a metaSet to construct a tree"
  , plock      ? args.__meta.plock or metaSet.__meta.plock
  , dev        ? true
  # FIXME: don't accept `pkgSet' here. This belongs in `mkNmDir'
  , pkgSet     ? null  # If `pkgSet' is not given, keys are returned.
  , outputKeys ? true
  # Filter out usupported systems. Use "target" platform.
  # XXX: You must supply `pkgSet' or `targetPlatform'!
  , skipUnsupported ? true
  # FIXME: don't accept `pkgSet' here. This belongs in `mkNmDir'
  , targetPlatform  ? pkgSet.__pscope.stdenv.targetPlatform
  , cpu             ? getNpmCpuForPlatform targetPlatform
  # For whatever reason NPM interprets like 4 different strings as x86_64.
  , cpuCond         ? supportedCpus: builtins.elem cpu supportedCpus
  , os              ? targetPlatform.parsed.kernel.name
  , osCond          ? supportedOss: builtins.elem os supportedOss
  # Keys to ignore.
  # By default we ignore the "root" key to break cycles; but projects shouldn't
  # depend on this feature because they're not going to be able to break
  # "build cycles" this way; only runtime cycles.
  , ignoredKeys     ? [metaSet.__meta.rootKey]
  # FIXME: handle `engines'?
  , ...
  } @ args: let
    inherit (metaSet) __meta;
    warnCycle = x: let
      msg = "WARNING: A cycle exists such that ${metaSet.__meta.rootKey} " +
            "depends on itself.\n" +
            "         Only the source tree is available for resolution.";
    in builtins.trace warnCycle x;
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
         assert ( args ? targetPlatform ) || ( args ? pkgSet );
         suppCpu && suppOs;
      # Handle `ignoredKeys'.
      isKeep = k: v: ! ( builtins.elem ( getKey k v ) ignoredKeys );
      # All together now.
      cond = k: v: ( isDevProd k v ) && ( isSupported k v ) && ( isKeep k v );
    in lib.filterAttrs cond full;
    asKeys = builtins.mapAttrs getKey nml;
    # This is NOT the `prepared' ents, you still have access to all pkgEnt
    # fields with this output.
    # This is done so that different tree builders may be used.
    asPkgEnts = builtins.mapAttrs ( d: e: pkgSet.${getKey d e} ) nml;
    # Allow keys to be output ( useful for `metaSet' ) or set attr values to
    # `prepared' for the associated key in `pkgSet'.
  in if outputKeys then asKeys else asPkgEnts;


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
