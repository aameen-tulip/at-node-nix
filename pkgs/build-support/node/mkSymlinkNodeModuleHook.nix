/**
 * A `setup-hook' which symlinks a built Node.js module into a builder's
 * `node_modules' folder.
 * This is used for all `mkNodeModule` derivations.
 *
 * This hook is sensitive to the following environment variables:
 *   NODE_MODULES_DIR     path to builder's `node_modules/' directory.
 *   dontLinkNodeModules  symlinking is skipped if this variable is non-zero.
 *   sourceRoot           when `NODE_MODULES_DIR' is unset,
 *                        `sourceRoot/node_modules' is used as a fallback.
 *
 * The routine `setNodeModulesDir' is used to select a target directory if
 * `NODE_MODULES_DIR' is unset.
 *
 * A set of hooks `symlinkNodeModulesHooks' holds individual package hooks.
 * This may be run as `runHook symlinkNodeModules' if you wish to do so
 * directly however, this set of hooks is already set to trigger during
 * `postUnpackHooks'.
 * See `injectSymlinkNodeModulesHooks' for details.
 *
 * If you want to change the phase that symlinking occurs in, you may run
 * `runHook symlinkNodeModules' directly - but I recommend setting
 * `dontLinkNodeModules = true' in either your derivation or some early
 * setup phase, and then change the variable to some non-zero value before
 * attempting to run `runHook symlinkNodeModules'.
 */
{ scope ? null, pname }:

# FIXME: Knowing the `bin/' targets upfront is a slight optimization.
# FIXME: Using `symlinkFarm' is a big optimization.
let
  mname = if scope != null then "@${scope}/${pname}" else pname;
  canonicalizeModuleName =
    builtins.replaceStrings ["-" "@" "/"] ["_" "_at_" "_slash_"];
  fnName = "linkNodeModule" + ( canonicalizeModuleName mname );
  scopeDir = if scope != null then "/@${scope}" else "";
in ''
  setNodeModulesDir() {
    test -n "$NODE_MODULES_DIR" && return
    if test -z "$sourceRoot"; then
      NODE_MODULES_DIR="$PWD/node_modules"
    else
      NODE_MODULES_DIR="$TMP/$sourceRoot/node_modules"
    fi
    export NODE_MODULES_DIR
  }

  injectSymlinkNodeModulesHooks() {
    test "''${dontLinkNodeModules:-0}" != 0 && return
    runHook symlinkNodeModules
  }

  postUnpackHooks+=( injectSymlinkNodeModulesHooks )

  if test -z "''${symlinkNodeModulesHooks+y}"; then
    declare -A symlinkNodeModulesHooks;
  fi

  ${fnName}() {
    test "''${dontLinkNodeModules:-0}" != 0 && return
    : "''${NODE_MODULES_DIR=$( setNodeModulesDir; )}"

    if test ! -e "$NODE_MODULES_DIR/${mname}"; then
      mkdir -p "$NODE_MODULES_DIR${scopeDir}"
      ln -s "@out@/lib/node_modules/${mname}" "$NODE_MODULES_DIR/${mname}"
      if test -d @out@/lib/node_modules/.bin; then
        mkdir -p "$NODE_MODULES_DIR/.bin"
        find @out@/lib/node_modules/.bin -type f -o -type l  \
             -exec ln -sf {} "$NODE_MODULES_DIR/.bin/" \;
      fi
    fi
  }

  symlinkNodeModulesHooks+=( ${fnName} )
''
