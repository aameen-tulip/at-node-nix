# Evaluate the named script fields in a project's `package.json' file.
# This is analogous to `npm run SCRIPT' or `yarn run SCRIPT'.
#
# Assumes that `src' is an unpacked Node.js package with `package.json' at
# the root level.
# `nodeModules' should most likely be a derivation produced by `linkModules',
# which will be made available when scripts are evaluated; additionally,
# `node_modules/.bin/' will be added to `PATH'.
# This folder is removed after scripts have been evaluated, and the working
# directory is moved to `$out'.
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
, name    ? meta.names.installed or "${baseNameOf ident}-inst-${version}"
, ident   ? meta.ident
, version ? meta.version
, src
, meta

# Scripts to be run during `builPhase'.
# These are executed in the order they appear, and may appear multiple times.
, runScripts  ? ["preinstall" "install" "postinstall"]
# If a script is not found, is will be skipped unless `skipMissing' is false.
, skipMissing ? true

# A scipt that should install modules to `$node_modules_path/'
, nmDirCmd    ? ":"

# If you ACTUALLY want to avoid this you can explicitly set to `null' but
# honestly I never seen a `postInstall' that didn't call `node'.
, nodejs
, jq
, stdenv
, ...
} @ args:
let
  mkDrvArgs = removeAttrs args [
    "ident"
    "runScripts" "skipMissing"
    "nmDirCmd" "nodejs" "jq" "stdenv" "lib"
    "override" "overrideDerivation"
    "nativeBuildInputs"  # We extend this
    "passthru"           # We extend this
  ];
in stdenv.mkDerivation ( {

  inherit name;
  nmDirCmd = if builtins.isString nmDirCmd then nmDirCmd else
    nmDirCmd.cmd + "\ninstallNodeModules;\n";

  nativeBuildInputs = ( args.nativeBuildInputs or [] ) ++ [jq] ++
                      ( lib.optional ( nodejs != null ) nodejs );

  passAsFile = ["nmDirCmd"];

  postUnpack = ''
    export absSourceRoot="$PWD/$sourceRoot";
    export node_modules_path="$absSourceRoot/node_modules";

    source "$nmDirCmdPath";

    if test -d "$node_modules_path"; then
      export PATH="$PATH:$node_modules_path/.bin";
      export NODE_PATH="$node_modules_path''${NODE_PATH:+:$NODE_PATH}";
    fi
  '';

  buildPhase = let
    runOne = sn: let
      fallback = lib.optionalString skipMissing "// \":\"";
    in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
    runAll = builtins.concatStringsSep "\n" ( map runOne runScripts );
  in lib.withHooks "build" runAll;

  # You can override this
  preInstall = ''
    if test -n "''${node_modules_path:-}"; then
      rm -rf -- "$node_modules_path";
    fi
  '';

  installPhase = lib.withHooks "install" ''
    cd "$NIX_BUILD_TOP";
    mv -- "$sourceRoot" "$out";
  '';

  # FIXME: bin perms hook
  #postInstall = ''
  #
  #'';

  passthru = ( args.passthru or {} ) // { inherit src nodejs nmDirCmd; };
} // mkDrvArgs )

# XXX: Certain `postInstall' scripts might actually need to be
# `setupHook's because they sometimes try to poke around the top level
# package's `node_modules/' directory to sanity check API compatibility
# when version conflicts exist in a node environment.
# PERSONALLY - I don't think that they should do this, and I'll point out
# that every single package that I have seen do this was accompanied by
# a security audit alert by NPM... but I'm calling this "good enough"
# until I actually find a package that breaks.
