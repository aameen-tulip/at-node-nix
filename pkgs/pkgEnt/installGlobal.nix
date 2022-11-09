# ============================================================================ #
#
# FIXME: this doesn't actually mesh with `pkgEnt' default fields but w/e.
#
# Installs a package "globally" `$out'.
# This differs from the "module install" that we perform inside of builders.
# The differences are:
#   - We install `$src' to `$out/lib/node_modules/<IDENT>'.
#   - We install bins to `$out/bin'.
#   - We install RUNTIME deps `$out/lib/node_modules/<IDENT>/node_modules/'.
#
# This builder uses the setup-hook/script
# [[file:../build-support/setup-hooks/installGlobal.sh][installGlobalNodeModuleHook]]
# and can adapt a "module install" routine ( such as `installNodeModules' ) to
# perform a global installation.
# This requires that the shell function `installNodeModules' uses the
# environment variable `node_modules_path'.
#
# NOTE: We are using `evalScripts' here, but by default we expect to receive
# fully prepared `src' ready for install - with that in mind we intentionally
# skip local installation of `nmDirCmd' as well as `configurePhase'
# and `buildPhase'.
# If you want to perform a global install as a part of an existing build you
# should just add `globalInstall = true' to the existing builder.
#
# The use case here is either for registry tarballs that are ready to run after
# unpacking, or for splitting the "build/prepare" phase of a local project from
# its global install in order to avoid dependency cycles and optimize CI.
# For example if you're building a local project you likely want to build, test,
# and perform global installs in separate derivations to create cache
# checkpoints in case a later stage fails.
#
# ---------------------------------------------------------------------------- #

{ lib
, name        ? meta.names.global or "${baseNameOf ident}-${version}"
, ident       ? args.meta.ident or ( dirOf args.key )
, version     ? args.meta.version or ( baseNameOf args.key )
, key         ? args.meta.key or "${ident}/${version}"
, src
, globalNmDirCmd ? ":"
, meta           ? lib.mkMetaEntCore { inherit ident version; }
, evalScripts
, ...
} @ args: let
  mkDrvArgs = removeAttrs args ["evalScripts"];
in evalScripts ( {
  inherit name ident version src globalNmDirCmd meta;
  runScripts    = [];
  globalInstall = true;
  moduleInstall = false;
  postUnpack    = ":";
  dontBuild     = true;
  dontConfigure = true;
} // args )

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
