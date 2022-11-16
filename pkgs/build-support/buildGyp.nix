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
  # NOTE: `[pre|post]prepare' scripts are NOT necessary when building registry
  # tarballs, which is presumed to be the use case here.
  # If you are building a `path' or `git' project you may want to turn those on
  # here - but if you do so keep in mind that the `node_modules/' dir is
  # supposed to only contain `dependendencies' and `optionalDependencies' during
  # this phase, while `prepare' scripts need `devDependencies'.
  # Keep that in mind if you write your own wrapper.
  , runScripts ? ["preinstall" "postinstall"]
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
  } @ args: let

    gypFlagToEnvVar = arg: let
      noDash = lib.yank "--?(.*)" arg;
      lobars = builtins.replaceStrings ["-"] ["_"] noDash;
      sp     = lib.splitString "=" lobars;
      h      = lib.toLower ( builtins.head sp );
      t      = if ( builtins.length sp ) <= 1 then "1" else
               builtins.concatStringsSep "=" ( builtins.tail sp );
    in {
      "npm_config_${h}" = t;
    };

    npmCfgVars = let
      allFlags = gypFlags ++ configureFlags ++ buildFlags;
    in builtins.foldl' ( acc: s: acc // ( gypFlagToEnvVar s ) ) {} allFlags;

    args' = ( removeAttrs args ( builtins.attrNames gypArgs ) ) // npmCfgVars;

  in evalScripts ( args' // {
      nativeBuildInputs = let
        given    = args.nativeBuildInputs or [];
        defaults = [pjsUtil nodejs node-gyp python jq] ++
                   ( lib.optional stdenv.isDarwin xcbuild );
      in lib.unique ( given ++ ( lib.filter ( x: x != null ) defaults ) );

      buildPhase = lib.withHooks "build" ''
        case " $runScripts " in
          *\ preinstall\ *) pjsRunScript preinstall; ;;
          *) :; ;;
        esac

          export BUILDTYPE="$buildType"
          for v in "''${!npm_config_@}" "''${!NPM_CONFIG_@}"; do
            eval export "$v";
          done

          if pjsHasScript install; then
            pjsRunScript install;
          else
            if test -r ./binding.gyp; then
              node-gyp rebuild;
            fi
          fi

        case " $runScripts " in
          *\ postinstall\ *) pjsRunScript postinstall; ;;
          *) :; ;;
        esac
      '';

      dontStrip = args.dontStrip or false;

    } );  # End `__innerFunction'


# ---------------------------------------------------------------------------- #

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
