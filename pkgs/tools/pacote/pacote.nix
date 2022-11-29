
# Install `pacote' using a barebones `floco' pipeline.
# Rather than using default fetchers or build pipelines we stick to lower level
# utilies/interfaces.
#
# This file is an excellent reference for packaging a registry module

{ lib

# This is more complex than it needs to be, but it shows how `floco' selects
# its preferred fetcher and is mostly provided as a learning tool.
# The only "real" requirement is that we provide `outPath' strings to `mkNmDir'.
#
# Our "fallback" fetcher is a modified `builtins.fetchurl' that doesn't use
# the tarball TTL.
# This allows "any hash" as input, but keep in mind different hashes yield
# different `outPath's; with that in mind we do prefer sha256 when possible.
#
# In impure mode we can use `builtins.fetchTree' which is backed by sha256, or
# we can use it if `narHash' is given.
# In impure mode we will use `fetchTree'.
, flocoFileFetcher ? {
    url       ? fetchInfo.resolved
  , resolved  ? null
  , hash      ? integrity
  , integrity ? fetchInfo.shasum
  , shasum    ? null
  , type      ? "file"
  , narHash   ? null
  , ...
  } @ fetchInfo: let
    ftLocked = ( fetchInfo ? narHash ) || ( ! lib.inPureEvalMode );
    preferFt = ( fetchInfo ? type ) && ftLocked;
    nh' = if fetchInfo ? narHash then { inherit narHash; } else {};
    # Works in impure mode, or given a `narHash'. Uses tarball TTL. Faster.
    ft = ( builtins.fetchTree { inherit url type; } ) // nh';
    # Works in pure mode and avoids tarball TTL.
    drv = lib.libfetch.fetchurlDrvW {
      inherit url hash;
      unpack = false;
    };
    sourceInfo = if preferFt then ft else drv;
  in ( if preferFt && ( type == "tarball" ) then {
    passthru.unpacked = true;
  } else {
    tarball = sourceInfo;
    passthru.unpacked = false;
  } ) // {
    inherit sourceInfo;
    inherit (sourceInfo) outPath;
  }

  # Unpacks and sets executable bits. For most packages this is "ready to use".
  # 99% of tarballs can use `builtins.fetch(Tree|Tarball)', but in rare cases
  # tarballs with improperly set executable bits on directories will require us
  # to use this unpacker.
  # For this reason we don't use `fetchTarball' by default, and instead prefer
  # to fetch files.
  # If you know that a tarball can be safely unpacked it's a nice optimization
  # to skip this.
  # Routines in `mkNmDirCmd' should still take care of setting bin perms.
, flocoUnpack ? { name, tarball, ... } @ fetched:
  if ! ( fetched.passthru.unpacked or false ) then fetched else unpackSafe {
    inherit name;
    source           = tarball;
    allowSubstitutes = ( system != ( builtins.currentSystem or null ) );
    preferLocalBuild = true;
  }

, metaSet ? lib.metaSetFromSerial' {
    inherit pure ifd allowedPaths typecheck;
  } ( import ./meta.nix )
, pacote-src ? flocoFileFetcher metaSet.${metaSet.__meta.rootKey}.fetchInfo
, mkNmDir    ? mkNmDirCopyCmd

, system
, evalScripts
, mkNmDirCopyCmd
, unpackSafe

, ifd
, pure
, allowedPaths
, typecheck

, ...
} @ args: let

  tree    = args.tree or metaSet.__meta.trees.prod;
  version = args.version or metaSet.${metaSet.__meta.rootKey}.version;

  prepPkg = { fetchInfo, ... } @ ent: let
    src = let
      fetched = flocoFileFetcher fetchInfo;
      args = fetched // {
        name        = ent.names.src;
        setBinPerms = ent.hasBin;
        # Needed by `mkNmDirCmd' for `bin' entries.
        passthru.metaEnt = ent.__entries or ent;
      };
      preferLocalBuild = true;
    in lib.apply flocoUnpack args;
  # We can avoid running `evalScripts' or `buildGyp' because we have all
  # registry tarballs ( no builds ), and none of them have installs.
  in assert ! ( ent.hasInstallScript or false );
  src;

  # Prepare all packages for consumption.
  pkgSet = builtins.mapAttrs ( _: prepPkg ) ( metaSet.__entries or metaSet );

  # Assign `node_modules/' paths to `outPath' of associated package.
  pkgTree = let
    treeDone = builtins.all ( x: x ? outPath ) ( builtins.attrValues tree );
    fallback = builtins.mapAttrs ( nmPath: key: pkgSet.${key} ) tree;
  in if treeDone then tree else fallback;

# We use `evalScripts' to leverage its default `setup-hooks', specifically for
# patching shebangs and running installs.
# We skip any usual "build" steps though.
in evalScripts {
  name = "pacote-${version}";
  inherit version;
  src = pacote-src;
  # Our last ditch unpack command.
  # Included inline here for reference, and in case `pacote-src' was returned
  # by `fetchTree { type = "file"; ... }'.
  # This is the exact implementation of `unpackSafe', except we don't patch
  # shebangs or set executable perms ( handled during patch/installation ).
  # NOTE: this is the last best effort routine, not built for speed.
  preUnpack = ''
    nodeUnpack() {
      tar tf "$1"|xargs -i dirname '{}'|sort -u|xargs -i mkdir -p '{}';
      tar                          \
        --no-same-owner            \
        --no-same-permissions      \
        --delay-directory-restore  \
        --no-overwrite-dir         \
        -xf "$1"                   \
      ;
    };
    unpackCmdHooks+=( nodeUnpack );
  '';
  globalInstall = true;  # Activates additional `global' output for install.
  globalNmDirCmd = mkNmDir {
    tree         = pkgTree;
    assumeHasBin = false;
    handleBindir = false;
  };
  # Don't run any scripts.
  runScripts = [];
  # Skip configure which just sets env vars we don't end up using.
  dontConfigure = true;
  # Skip running scripts and attempts to patch new files.
  dontBuild = true;
}
