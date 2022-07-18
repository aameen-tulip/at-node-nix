{ lib
, buildGyp
, evalScripts
, stdenv
, xcbuild
, nodejs
, jq
} @ globalAttrs:
let

  genericInstall = {
    name
  , version
  , src
  , nodeModules
  , meta        ? {}
  # gypfile     # Recommended that you pass this if it is known: true|false.
                # If unset, we use the `maybeGyp' builder to avoid IFD.
  , nodejs      ? globalAttrs.nodejs
  , jq          ? globalAttrs.jq
  , stdenv      ? globalAttrs.stdenv
  , xcbuild     ? globalAttrs.xcbuild
  , ...
  } @ args: let
    # Runs `gyp' and may run `[pre|post]install' if they're defined.
    # You may need to add meta hints to hooks to account for neanderthals that
    # hide the `binding.gyp' file in a subdirectory - because `npmjs.org'
    # does not detect these and will not contain correct `gypfile' fields in
    # registry manifests.
    gyp = buildGyp {
      inherit name src version nodejs jq xcbuild stdenv nodeModules;
    };
    # Plain old install scripts.
    std = evalScripts { inherit name src version nodejs jq nodeModules; };
    # Add node-gyp "just in case" and check dynamically.
    # This is just to avoid IFD but you should add an overlay with hints
    # to avoid using this builder.
    maybeGyp = let
      runOne = sn: let
        fallback = "// \":\"";
      in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
    in evalScripts {
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
    };
    gypfileKnown = if args.meta.gypfile or args.gypfile then gyp else std;
  in if args ? meta.gypfile || args ? gypfile then gypfileKnown else maybeGyp;

in genericInstall
