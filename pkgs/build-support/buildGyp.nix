# ============================================================================ #
# 
# buildGyp { name, nmDirCmd, src, ... }
#
# Outputs two targets.
#   - `out' is the unpacked source tree, where `node-gyp build' has been run.
#     The `node_modules/' directory is not output - because this may not
#     be suitable for the `idealTree' expected by `npm' or `yarn'.
#     XXX: This is placed in a subdirectory `package/' which mimics the layout
#     of a registry tarball.
#     The rationale is that if someone adds `propagatedBuildInputs' we don't
#     want `nix-support' to accidentally appear in the package.
#     Keep this in mind when converting this tree into a module/global dir.
#
#   - `build' is a copy of the `build/' directory after `node-gyp build' has
#     been run.
#     You could, in most cases simply symlink this into an unpacked registry
#     tarball to create an equivalent of `out'.
#     FIXME: for now I am leaving `out' because I'm not 100% sure that the
#     "theory" stated here is bullet-proof.
#     Once this thing gets some more field testing `out' can likely be
#     removed, and `build' can be symlinked based on platform/arch.
#
#   - NOTE: No fixup is performed. This may be a useful addition later.
#
#
# FIXME: Call `evalScripts' and override the `buildPhase' and `installPhase'.
# This routine currently has a lot of common code that was copied from
# `evalScripts' and really needs to be aligned for it to behave properly.
#
#
# ---------------------------------------------------------------------------- #
{
  lib
, name    ? meta.names.installed or "${baseNameOf ident}-inst-${version}"
, ident   ? meta.ident   # Just used for the name fallback
, version ? meta.version # Just used for the name fallback
, src
, meta

# A scipt that should install modules to `$node_modules_path/'
, nmDirCmd ? ":"

, buildType            ? "Release"
, configureFlags       ? []
, buildFlags           ? []
, skipMissing          ? true
# NOTE: `install' script is overridden by `node-gyp' invocation
, runScripts           ? ["preinstall" "postinstall"]
# `--ensure' skips audit of Node.js system headers.
# Rationale:
# We aren't concerned with mismatching because we know our inputs were built
# in sanitary environments; this is something other package managers botch so
# frequently that the devs of `node-gyp' opted to perform this sanity check by
# default for all builds.
# In our case this check is potentially harmful because it attempts to download
# Node.js system headers from their upstream source which ain't gonna fly in our
# sandbox environments.
# Also, we explicitly provide the path to the Node.js system headers using
# `--nodedir=/nix/store/XXXXXX-...-nodejs-<MAJOR_VERSION>_x' for `node-gyp' to
# locate them ( assuming `nodejs != null' in which case we should end up using
# whatever headers `node-gyp' has in its runtime env ).
, gypFlags ? ["--ensure"] ++
             ( lib.optional ( nodejs != null ) "--nodedir=${nodejs}" )

# If you ACTUALLY want to avoid this you can explicitly set to `null' but
# honestly I never seen a `postInstall' that didn't call `node'.
# Setting this to `null' really expects that you're going to set `gypFlags',
# and any other fallbacks which reference `nodejs.*' attributes manually. 
, nodejs
, jq
, node-gyp ? nodejs.pkgs.node-gyp       or null
#, node-gyp-build ? nodejs.pkgs.node-gyp-build or null
, python   ? nodejs.python or null  # XXX: strongly advise using python3
, stdenv
, xcbuild
, ...
} @ args: let

  mkDrvArgs = removeAttrs args [
    "runScripts" "skipMissing"
    "nmDirCmd" "nodejs" "jq" "stdenv" "lib" "node-gyp" "node-gyp-build" "python"
    "xcbuild"
    "buildType" "gypFlags" "configureFlags" "buildFlags"
    "override" "overrideDerivation" "__functionArgs" "__functor"
    "nativeBuildInputs"  # We extend this
    "passthru"           # We extend this
    # `metaEnt' fields that we might be passed.
    "sourceInfo"
    "scoped"
    "key"
    "names"
    "ident"
    "hasInstallScript"
    "hasBin"
    "gypfile"
    "entries"
    "entFromtype"
    "depInfo"
    "bin"
  ];

  # "stringize flags"
  sf = builtins.concatStringsSep " ";

  runOne = sn: let
    fallback = lib.optionalString skipMissing "// \":\"";
  in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';

in stdenv.mkDerivation ( {
  inherit name;
  outputs = ["out" "build"];

  nativeBuildInputs = let
    given    = args.nativeBuildInputs or [];
    defaults = [
      nodejs
      node-gyp
      #node-gyp-build
      python
      jq
    ] ++ ( lib.optional stdenv.isDarwin xcbuild );
  in given ++ ( lib.filter ( x: x != null ) defaults );

  nmDirCmd =
    if builtins.isString nmDirCmd then nmDirCmd else
    if nmDirCmd ? cmd then nmDirCmd.cmd + "\ninstallNodeModules;\n" else
    if nmDirCmd ? __toString then nmDirCmd.__toString nmDirCmd else
    throw "No idea how to treat this as a `node_modules/' directory builder.";

  passAsFile =
    if ( builtins.isString nmDirCmd ) &&
       ( 1024 <= ( builtins.stringLength nmDirCmd ) )
    then ["nmDirCmd"] else [];

  postUnpack = ''
    export absSourceRoot="$PWD/$sourceRoot";
    export node_modules_path="$absSourceRoot/node_modules";

    if test -n "''${nmDirCmdPath:-}"; then
      source "$nmDirCmdPath";
    else
      eval "$nmDirCmd";
    fi

    if test -d "$node_modules_path"; then
      export PATH="$PATH:$node_modules_path/.bin";
      export NODE_PATH="$node_modules_path''${NODE_PATH:+:$NODE_PATH}";
    fi
  '';

  configurePhase = let
    runPreInst = lib.optionalString ( builtins.elem "preinstall" runScripts )
                                    ( runOne "preinstall" );
  in lib.withHooks "configure" ''
    ${runPreInst}
    export BUILDTYPE="${buildType}"
    node-gyp ${sf gypFlags} configure ${sf configureFlags}
  '';

  buildPhase = let
    defaultGypInst = "node-gyp ${sf gypFlags} build ${sf buildFlags}";
    runPostInst = lib.optionalString ( builtins.elem "postinstall" runScripts )
                                     ( runOne "postinstall" );
    hasInstJqCmd = "'.scripts.install // false'";
    warnInstallDefined = let
      readName = args.ident or "$( jq '.name' ./package.json; )";
    in ''
      if test "$( jq -r ${hasInstJqCmd} ./package.json; )" != false; then
        cat >&2 <<EOF
      buildGyp: WARNING: ${readName} install script is being overridden.
        Original: $( jq -r '.scripts.install' ./package.json; )
        Override: ${defaultGypInst}
      EOF
      fi
    '';
  in lib.withHooks "build" ''
    ${warnInstallDefined}
    ${defaultGypInst}
    ${runPostInst}
  '';

  # You can override this
  preInstall = ''
    if test -n "''${node_modules_path:-}"; then
      rm -rf -- "$node_modules_path";
    fi
  '';

  installPhase = lib.withHooks "install" ''
    mkdir -p "$build"
    cp -pr --reflink=auto -- ./build "$build"
    cd "$NIX_BUILD_TOP"
    mv -- "$sourceRoot" "$out"
  '';

  passthru = ( args.passthru or {} ) // { inherit src nodejs nmDirCmd; };

} // mkDrvArgs )


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
