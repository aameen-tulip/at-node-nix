
# genericInstall
#
# Runs `[pre|post]install' scripts defined in `package.json'.
# If `install' is undefined, but a `binding.gyp' file is present; or the arg
# `gypfile = true' run the default `node-gyp' install routine using `buildGyp'.
# This aligns with NPM and Yarn behaviors.
#
# If `gypfile' is not explicitly defined there are two behaviors depending on
# whether `impure = true'.
#   If `impure = true' then use `builtins.pathExists' to detect if a
#   `binding.gyp' exists in `src' directory.
#   Otherwise, check at build time and use a wonky wrapper over `node-gyp' to
#   mimic the behavior of `buildGyp'.
#
# NOTE: There are some differences between the real `buildGyp' routine and the
# routine defined below that uses a `node-gyp' shell alias.
# I strongly recommend setting `gypfile' explicitly.
#
# FIXME: Align the fallback with `buildGyp' after rewriting `buildGyp' as an
# `evalScripts' wrapper.

{ lib
, name        ? meta.names.installed or "${ident}-inst-${version}"
, ident       ? meta.ident
, version     ? meta.version
, src
, nmDirCmd    ? ":"
, meta        ? {}
# gypfile     # Recommended that you pass this if it is known: true|false.
              # If unset, we use the `maybeGyp' builder to avoid IFD, or in
              # impure mode we will perform IFD to detect `binding.gyp'.

, impure      ? args.flocoConfig.enableImpureMeta or ( ! lib.inPureEvalMode )

, evalScripts
, buildGyp
# If you ACTUALLY want to avoid this you can explicitly set to `null' but
# honestly I never seen a `postInstall' that didn't call `node'.
, nodejs
, jq
, stdenv
, xcbuild
, node-gyp ? nodejs.pkgs.node-gyp
, python   ? nodejs.python  # XXX: strongly advise using python3
# XXX: Any flags accepted by either `evalScripts' or `buildGyp' are permitted
# here and will be passed through to the underlying builders.
, ...
} @ args: let

  args' = removeAttrs args [
    "override" "overrideDerivation" "__functionArgs" "__functor"
    "impure" "flocoConfig"
    "buildGyp" "evalScripts"
  ];

  # Runs `gyp' and may run `[pre|post]install' if they're defined.
  # You may need to add meta hints to hooks to account for neanderthals that
  # hide the `binding.gyp' file in a subdirectory - because `npmjs.org'
  # does not detect these and will not contain correct `gypfile' fields in
  # registry version info.
  # XXX: DO NOT USE THE FIELDS RECORDED IN THE NPM REGISTRY FOR `gypfile'!
  gyp =
    buildGyp ( { inherit name version nodejs jq xcbuild stdenv; } // args' );

  # Plain old install scripts.
  std =
    evalScripts ( { inherit name version nodejs jq; } // args' );

  # Add node-gyp "just in case" and check dynamically.
  # This is just to avoid IFD but you should add an overlay with hints
  # to avoid using this builder.
  # FIXME: Align with `buildGyp' precisely.
  maybeGyp = let
    runOne = sn: let
      fallback = "// \":\"";
    in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
  in evalScripts ( {
    inherit name src version nodejs jq;
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

  } // args' );

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
      meta = pmeta // {
        gypfile = detectGypfile;
        __impureFields = ( pmeta._impureFields or [] ) ++ ["gypfile"];
      };
    };
  in base // meta';

  installed = if gypfileKnown then forGypfileKnown else maybeGyp;

in assert installed ? override;
   assert installed ? overrideDerivation;
   assert installed ? drvAttrs;
   installed
