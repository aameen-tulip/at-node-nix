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
, name    ? metaEnt.names.prepared or "${baseNameOf ident}-eval-${version}"
, ident   ? args.metaEnt.ident
, version ? args.metaEnt.version or ( lib.last ( lib.splitString "-" name ) )
, src
, metaEnt ? lib.libmeta.mkMetaEntCore { inherit ident version; }
, meta    ? {}  # TODO

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
, dontRemoveNmDir ? false
, globalNmDirCmd  ? nmDirCmd

# If you ACTUALLY want to avoid this you can explicitly set to `null' but
# honestly I never seen a `postInstall' that didn't call `node'.
, nodejs
, jq
, stdenv
, pjsUtil
, patchNodePackageHook
, installGlobalNodeModuleHook
, globalInstall ? false
, moduleInstall ? true
, globalOutput  ? if moduleInstall then "global" else "out"
, moduleOutput  ? if moduleInstall then "out" else null
, disablePassAsFile ? false
, ...
} @ args:

assert ( globalInstall && moduleInstall ) -> ( globalOutput != moduleOutput );

let

  mkDrvArgs = let
    dropped = removeAttrs args [
      "nmDirCmd" "globalNmDirCmd" "nodejs" "jq" "stdenv" "lib" "pjsUtil"
      "patchNodePackageHook" "installGlobalNodeModuleHook"
      "globalOutput" "moduleOutput"
      "doStrip"
      "override" "overrideDerivation" "__functionArgs" "__functor"
      "metaEnt"
      "nativeBuildInputs"  # We extend this
      "passthru"           # We extend this
    ];
    meta' = if ( meta._type or null ) == "metaEnt" then {} else {
      inherit meta;
    };
  in dropped // meta';

  nmDirCmd =
    if ! ( args ? nmDirCmd ) then ":" else
    if builtins.isString args.nmDirCmd then args.nmDirCmd else
    if args.nmDirCmd ? __toString then toString args.nmDirCmd else
    throw "No idea how to treat this as a `node_modules/' directory builder.";

  globalNmDirCmd =
    if ! ( args ? globalNmDirCmd ) then nmDirCmd else
    if builtins.isString args.globalNmDirCmd then args.globalNmDirCmd else
    if args.globalNmDirCmd ? __toString then toString args.globalNmDirCmd else
    throw "No idea how to treat this as a `node_modules/' directory builder.";

    # There's no reason to put these giant routines in the drv if they won't
    # be used.
    nmDirScripts = 
      ( if globalInstall then { inherit globalNmDirCmd; } else {} ) //
      ( if moduleInstall then { inherit nmDirCmd; } else {} );

in stdenv.mkDerivation ( {

  inherit name;

  inherit
    skipMissing dontRemoveNmDir
    globalInstall moduleInstall
  ;

  outputs = let
    prev   = args.outputs or [];
    global = if globalInstall then [globalOutput] else [];
    module = if moduleInstall then [moduleOutput] else [];
  in prev ++ module ++ global;

nativeBuildInputs = let
    given    = args.nativeBuildInputs or [];
    gi       = if globalInstall then [installGlobalNodeModuleHook] else [];
    defaults = [pjsUtil patchNodePackageHook nodejs jq] ++ gi;
  in lib.unique ( given ++ ( lib.filter ( x: x != null ) defaults ) );

  passAsFile = let
    condLen  = s: ( 1024 * 1024 ) <= ( builtins.stringLength s );
    fromNmd  = if ( condLen nmDirCmd ) && ( ! disablePassAsFile )
               then ["nmDirCmd"] else [];
    fromGNmd = if ( condLen globalNmDirCmd ) && ( ! disablePassAsFile )
               then ["globalNmDirCmd"] else [];
    fromArgs = let
      msg = "evalScripts: disablePassAsFile is true, but args explicitly" +
            "contain a 'passAsFile' value.";
    in if ! ( disablePassAsFile && ( ( args.passAsFile or [] ) != [] ) )
       then args.passAsFile or []
       else throw msg;
  in fromNmd ++ fromGNmd ++ fromArgs;

  postUnpack = ''
    export node_modules_path="$PWD/$sourceRoot/node_modules";
    if test -n "''${nmDirCmdPath:-}"; then
      if test r "$nmDirCmdPath"; then
        source "$nmDirCmdPath";
      else
        {
          echo "Node Modules dir command not readable at: $nmDirCmdPath";
          echo "If you are using 'nix develop' you must pass your";
          echo "'node_modules/' creation command as a non-temporary file.";
          echo "This is a bug in Nix versions ~10-11.";
          echo "You can correct the issue by removing 'passAsFile' from";
          echo "your derivation, ( recommended ) use 'mkNmDirSetupHook',";
          echo "or simply add 'disablePassAsFile = true;' to your call to";
          echo "'evalScript' ( or related wrapper function ).";
        } >&2;
        exit 1;
      fi
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
    elif test -d "./node_modules"; then
      export PATH="$PATH:$PWD/node_modules/.bin";
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
    if test "''${dontRemoveNmDir:-0}" = 0; then
      if test -n "''${node_modules_path:-}"; then
        if test -e "$node_modules_path"; then
          chmod -R +w "$node_modules_path";
          rm -rf -- "$node_modules_path";
        fi
        unset node_modules_path;
      fi
    else
      echo "Builder's 'node_modules' was not deleted and will be installed" >&2;
      if test "''${moduleInstall:-0}" != 0; then
        if test -n "''${node_modules_path:-}"; then
          if test -e "$node_modules_path"; then
            mkdir -p "$out";
            mv "$node_modules_path" "$out/node_modules";
          fi
          unset node_modules_path;
        fi
      fi
    fi
  '';

  installPhase = lib.withHooks "install" ''
    if test "''${moduleInstall:-0}" != 0; then
      pjsAddModCopy . "${"$" + moduleOutput}"
    fi
    if test "''${globalInstall:-0}" != 0; then
      installGlobalNodeModule "${"$" + globalOutput}";
    fi
  '';

  passthru = let
    nmsExplicit = builtins.intersectAttrs {
      nmDirCmd       = true;
      globalNmDirCmd = true;
    } args;
    nms = nmDirScripts // nmsExplicit;
  in ( args.passthru or {} ) // { inherit src nodejs; } // nms;

  dontStrip = true;

} // mkDrvArgs // nmDirScripts )

# XXX: Certain `postInstall' scripts might actually need to be
# `setupHook's because they sometimes try to poke around the top level
# package's `node_modules/' directory to sanity check API compatibility
# when version conflicts exist in a node environment.
# PERSONALLY - I don't think that they should do this, and I'll point out
# that every single package that I have seen do this was accompanied by
# a security audit alert by NPM... but I'm calling this "good enough"
# until I actually find a package that breaks.
