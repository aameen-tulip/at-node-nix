{ lib
, buildGyp
, evalScripts
, stdenv
, xcbuild
# Impure mode allows IFD to be used to determine if a `binding.gyp' file exists
# in a source tree.
# Disable this if you care about purity.
# The resulting `meta.gypfile' filed will be stashed in the resulting attrset.
# If you are interested in serializing it you should collect the info in a
# higher level overlay and merge it into the extensible `meta' object.
, impure ? ( builtins ? currentTime )
# NOTE: You aren't required to pass these, but they serve as fallbacks.
# I have commented them out to prevent accidental variable shadowing; but it is
# recommended that you pass them.
## , nodejs
## , jq
, ...
} @ globalAttrs:
let

  ga-impure = impure;

  genericInstall = {
    name        ? meta.names.installed
  , version     ? meta.version
  , src
  , nodeModules # Expected to be `nodeModulesDir'
  , meta        ? {}
  # gypfile     # Recommended that you pass this if it is known: true|false.
                # If unset, we use the `maybeGyp' builder to avoid IFD, or in
                # impure mode we will perform IFD to detect `binding.gyp'.
  , impure      ? ga-impure  # See note at top
  # If you ACTUALLY want to avoid this you can explicitly set to `null' but
  # honestly I never seen a `postInstall' that didn't call `node'.
  , nodejs ? globalAttrs.nodejs or ( throw "You must pass nodejs explicitly" )
  , jq     ? globalAttrs.jq  or ( throw "You must pass jq explicitly" )
  , stdenv   ? globalAttrs.stdenv
  , xcbuild  ? globalAttrs.xcbuild
  , node-gyp ? nodejs.pkgs.node-gyp
  , python   ? nodejs.python
  # XXX: Any flags accepted by either `evalScripts' or `buildGyp' are permitted
  # here and will be passed through to the underlying builders.
  , ...
  } @ args: let
    # Runs `gyp' and may run `[pre|post]install' if they're defined.
    # You may need to add meta hints to hooks to account for neanderthals that
    # hide the `binding.gyp' file in a subdirectory - because `npmjs.org'
    # does not detect these and will not contain correct `gypfile' fields in
    # registry manifests.
    gyp =
      buildGyp ( { inherit name version nodejs jq xcbuild stdenv ; } // args );
    # Plain old install scripts.
    std =
      evalScripts ( { inherit name version nodejs jq nodeModules; } // args );
    # Add node-gyp "just in case" and check dynamically.
    # This is just to avoid IFD but you should add an overlay with hints
    # to avoid using this builder.
    maybeGyp = let
      runOne = sn: let
        fallback = "// \":\"";
      in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
    in evalScripts ( {
      inherit name src version nodejs jq nodeModules;
      # `nodejs' and `jq' are added by `evalScripts'
      nativeBuildInputs = [
        nodejs.pkgs.node-gyp
        nodejs.python
      ] ++ ( lib.optional stdenv.isDarwin xcbuild );
      buildType = "Release";
      configurePhase = let
        hasInstJqCmd = "'.scripts.install // false'";
      in lib.withHooks "configure" ''
        node-gyp() { command node-gyp --ensure --nodedir="$nodejs" "$@"; }
        if test -z "''${isGyp+y}" && test -r ./binding.gyp; then
          isGyp=:
          if test "$( jq -r ${hasInstJqCmd} ./package.json; )" != false; then
            export BUILDTYPE="$buildType"
            node-gyp configure
          fi
        else
          isGyp=
        fi
      '';
      buildPhase = lib.withHooks "build" ''
        ${runOne "preinstall"}
        if test -n "$isGyp"; then
          eval "$( jq -r '.scripts.install // \"node-gyp\"' ./package.json; )"
        else
          ${runOne "install"}
        fi
        ${runOne "preinstall"}
      '';
    } // args );

    detectGypfile = builtins.pathExists "${src}/binding.gyp";
    gypfileKnownPure = args ? meta.gypfile || args ? gypfile;
    gypfileKnown = gypfileKnownPure || impure;
    hasGypfilePure = args.meta.gypfile or args.gypfile;
    hasGypfile =
      args.meta.gypfile or args.gypfile or ( impure && detectGypfile );
    forGypfileKnown = let
      base = if hasGypfile then gyp else std;
      pmeta = base.meta or meta;
      meta' = if gypfileKnownPure || ( ! impure ) then pmeta else {
        meta = lib.updateAttrsE pmeta {
          gypfile = detectGypfile;
          __impureFields = ( pmeta._impureFields or [] ) ++ ["gypfile"];
        };
      };
    in base // meta';
    installed = if gypfileKnown then forGypfileKnown else maybeGyp;

  in installed;

in lib.makeOverridable genericInstall
