# ============================================================================ #
#
# buildGyp { name, nmDirCmd, src, ... }
# 
# Takes the same fields as `evalScript', with a few extras aimed specifically at
# driving `node-gyp' builds.
#
# NOTE: This builder will ignore any `package.json:scripts.install' routine
# in favor of its own commands.
# In practice this is what we usually want because authors often use `install'
# scripts to try to pull prebuilt artifacts from the network - we prefer to just
# build from scratch instead for purity.
#
# Because this builder is a wrapper around `evalScripts', I've made it a functor
# so that `callPackage' can read the "full" argument list accepted.
#
#
# ---------------------------------------------------------------------------- #
let
  evalScriptsArgs = builtins.functionArgs ( import ./evalScripts.nix );
  gypArgs = {  # bool is `isOptional' arg
    pjsUtil        = false;
    evalScripts    = false;
    buildType      = true;
    configureFlags = true;
    buildFlags     = true;
    gypFlags       = true;
    node-gyp       = true;
    python         = true;
    xcbuild        = false;
  };

in {
  __functionArgs = evalScriptsArgs // gypArgs;
  # NOTE: `callPackage' and `makeOverridable' set `__functor', which would wrap
  # this field from the perspective of the user.
  # By indirectly calling `__innderFunction' we make the functor more opaque.
  __functor = self: self.__innerFunction;

# ---------------------------------------------------------------------------- #

  # The function to be called by our functor.
  __innerFunction = {
    buildType      ? "Release"
  , configureFlags ? []  # as: node-gyp ... configure <HERE>
  , buildFlags     ? []  # as: node-gyp ... build     <HERE>
  # NOTE: `install' script is overridden by `node-gyp' invocation
  , runScripts     ? ["preinstall" "postinstall"]
  # `--ensure' skips audit of Node.js system headers.
  # Rationale:
  # We aren't concerned with mismatching because we know our inputs were built
  # in sanitary environments; this is something other package managers botch so
  # frequently that the devs of `node-gyp' opted to perform this sanity check by
  # default for all builds.
  # In our case this check is potentially harmful because it attempts to
  # download Node.js system headers from their upstream source which ain't gonna
  # fly in our sandbox environments.
  # Also, we explicitly provide the path to the Node.js system headers using
  # `--nodedir=/nix/store/XXXXXX-...-nodejs-<MAJOR_VERSION>_x' for `node-gyp' to
  # locate them ( assuming `nodejs != null' in which case we should end up using
  # whatever headers `node-gyp' has in its runtime env ).
  , gypFlags ? ["--ensure"] ++
               ( lib.optional ( nodejs != null ) "--nodedir=${nodejs}" )

  , lib
  , evalScripts
  , pjsUtil
  # If you ACTUALLY want to avoid this you can explicitly set to `null' but
  # honestly I never seen a `postInstall' that didn't call `node'.
  # Setting this to `null' really expects that you're going to set `gypFlags',
  # and any other fallbacks which reference `nodejs.*' attributes manually.
  , stdenv
  , jq
  , nodejs
  , node-gyp ? nodejs.pkgs.node-gyp or null
  , python   ? nodejs.python or null  # XXX: strongly advise using python3
  , xcbuild
  , ...
  } @ args:
    evalScripts ( ( removeAttrs args ( builtins.attrNames gypArgs ) ) // {
      nativeBuildInputs = let
        given    = args.nativeBuildInputs or [];
        defaults = [pjsUtil nodejs node-gyp python jq] ++
                   ( lib.optional stdenv.isDarwin xcbuild );
      in lib.unique ( given ++ ( lib.filter ( x: x != null ) defaults ) );

      buildPhase = lib.withHooks "build" ''
        case " $runScripts " in
          preinstall) pjsRunScript preinstall; ;;
          *) :; ;;
        esac

        export BUILDTYPE="$buildType"
        GYP_FLAGS=( $gypFlags );
        GYP_CFG_FLAGS=( $configureFlags );
        GYP_BUILD_FLAGS=( $buildFlags );

        if pjsHasScript install; then
          _PKG_NAME="$( jq -r '.name' ./package.json )";
          cat >&2 <<EOF
        buildGyp: WARNING: $_PKG_NAME install script is being overridden.
          Original: $( jq -r '.scripts.install' ./package.json; )
          Override: |
            node-gyp $GYP_FLAGS configure $GYP_CFG_FLAGS;
            node-gyp $GYP_FLAGS build $GYP_BUILD_FLAGS;
        EOF
        fi

        node-gyp $GYP_FLAGS configure $GYP_CFG_FLAGS;
        node-gyp $GYP_FLAGS build $GYP_BUILD_FLAGS;

        case " $runScripts " in
          postinstall) pjsRunScript postinstall; ;;
          *) :; ;;
        esac
      '';
    } );  # End `__innerFunction'


# ---------------------------------------------------------------------------- #

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
