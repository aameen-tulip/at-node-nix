# Evaluate the named script fields in a project's `package.json' file.
# This is analogous to `npm run SCRIPT' or `yarn run SCRIPT'.
#
# Assumes that `src' is an unpacked Node.js package with `package.json' at
# the root level, or a tarball with the root at `package/'.
#
# Before building `node_modules/.bin/' will be added to `PATH', allowing
# any scripts that are normally available during `package.json:scripts.*'
# execution for other package managers "work" as the user expects.
# This folder is removed after scripts have been evaluated, and the working
# directory is copied to `$out'.
#
# Your scripts will run in a `stdenv' environment with `nodejs' and `jq'
# available ( in addition to the `node_modules/.bin' scripts ).
# Additional inputs may be passed in using `nativeBuildInputs', `buildInputs',
# etc - but note that `jq' and `nodejs' are appended to `nativeBuildInputs';
# so you don't have to worry about headaches there.
# ( AFAIK you can still wipe them out with an `overlay' ).
#
# The only other "special" attribute similar to `nativeBuildInputs' is
# `passthru', which is extended with `src', `nodejs', and `nodeModules'.
# Note that we do NOT extend `nodejs.pkgs' which are modules used within
# Nixpkgs to support various tools.
# If you do want to extend that package set you can do so with an overlay
# after calling `evalScripts', and presumably you'll need to perform
# additional steps to match the `node2nix' install structure before adding
# to that package set.

{ lib
, name    ? meta.names.installed or "${baseNameOf ident}-eval-${version}"
, ident   ? meta.ident
, version ? meta.version or ( lib.last ( lib.splitString "-" name ) )
, src
, meta    ? builtins.intersectAttrs { ident = true; version = true; } args

# Scripts to be run during `builPhase'.
# These are executed in the order they appear, and may appear multiple times.
# NOTE: the default list is the lifecycle run by `npm install ../foo', for
# installing one local project into another.
# This list is probably overkill for most projects and in all likelihood this
# list is NOT what you want to run for a registry tarball.
#
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL
, runScripts ? [
  "prebuild"   "build"   "postbuild"
  "preprepare" "prepare" "postprepare"
  "prepack"
  "preinstall" "install" "postinstall"
]
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL
# XXX: YOU WANT TO MODIFY THIS LIST IF YOU ARE BUILDING A REGISTRY TARBALL

# If a script is not found, is will be skipped unless `skipMissing' is false.
, skipMissing ? true

# A scipt that should install modules to `$node_modules_path/'
, nmDirCmd ? ":"

# If you ACTUALLY want to avoid this you can explicitly set to `null' but
# honestly I never seen a `postInstall' that didn't call `node'.
, nodejs
, jq
, stdenv
, pjsUtil
, patchNodePackageHook
, installGlobalNodeModuleHook
, globalInstall ? false
, ...
} @ args:
let
  mkDrvArgs = removeAttrs args [
    "ident"
    "nmDirCmd" "nodejs" "jq" "stdenv" "lib" "pjsUtil"
    "patchNodePackageHook" "installGlobalNodeModuleHook"
    "doStrip"
    "override" "overrideDerivation" "__functionArgs" "__functor"
    "nativeBuildInputs"  # We extend this
    "passthru"           # We extend this
  ];

  nmDirCmd =
    if ! ( args ? nmDirCmd ) then ":" else
    if builtins.isString args.nmDirCmd then args.nmDirCmd else
    if args.nmDirCmd ? cmd then ''
      ${args.nmDirCmd.cmd}
      installNodeModules;
    '' else
    if args.nmDirCmd ? __toString then toString args.nmDirCmd else
    throw "No idea how to treat this as a `node_modules/' directory builder.";

in stdenv.mkDerivation ( {

  inherit name;

  inherit skipMissing globalInstall nmDirCmd;

  outputs = let
    prev   = args.outputs or ["out"];
    global = if globalInstall then ["global"] else [];
  in prev ++ global;

  nativeBuildInputs = let
    given    = args.nativeBuildInputs or [];
    gi       = if globalInstall then [installGlobalNodeModuleHook] else [];
    defaults = [pjsUtil patchNodePackageHook nodejs jq] ++ gi;
  in lib.unique ( given ++ ( lib.filter ( x: x != null ) defaults ) );

  passAsFile =
    if 1024 <= ( builtins.stringLength nmDirCmd ) then ["nmDirCmd"] else [];

  postUnpack = ''
    export node_modules_path="$PWD/$sourceRoot/node_modules";
    if test -n "''${nmDirCmdPath:-}"; then
      source "$nmDirCmdPath";
    else
      eval "$nmDirCmd";
      if [[ "$?" -ne 0 ]]; then
        echo "Failed to execute nmDirCmd: \"$nmDirCmd\"" >&2;
        exit 1;
      fi
    fi
  '';

  configurePhase = lib.withHooks "configure" ''
    if test -d "$node_modules_path"; then
      export PATH="$PATH:$node_modules_path/.bin";
      export NODE_PATH="$node_modules_path''${NODE_PATH:+:$NODE_PATH}";
    fi
  '';

  buildPhase = lib.withHooks "build" ''
    {
      _RUN_SCRIPTS=( $runScripts );
      for sn in "''${_RUN_SCRIPTS[@]}"; do
        pjsRunScript "$sn";
      done
    }
  '';

  # You can override this
  preInstall = ''
    if test -n "''${node_modules_path:-}"; then
      if test -e "$node_modules_path"; then
        chmod -R +w "$node_modules_path";
        rm -rf -- "$node_modules_path";
      fi
      unset node_modules_path;
    fi
  '';

  installPhase = lib.withHooks "install" ''
    pjsAddMod . "$out";
  '';

  passthru = ( args.passthru or {} ) // { inherit src nodejs nmDirCmd; };

  dontStrip = true;

} // mkDrvArgs )

# XXX: Certain `postInstall' scripts might actually need to be
# `setupHook's because they sometimes try to poke around the top level
# package's `node_modules/' directory to sanity check API compatibility
# when version conflicts exist in a node environment.
# PERSONALLY - I don't think that they should do this, and I'll point out
# that every single package that I have seen do this was accompanied by
# a security audit alert by NPM... but I'm calling this "good enough"
# until I actually find a package that breaks.
