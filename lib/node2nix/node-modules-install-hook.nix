# Bundle the dependencies of the package
{ composePackage }:

# Only include dependencies if they don't exist. They may also be bundled in
# the package.
# `node2nix' calls this routine `includeDependencies'.
{ dependencies }:
let
  maybeUnpack = dep: ''
    if test ! -e "${dep.packageName}"; then
      ${composePackage dep}
    fi
  '';
in if ( ( builtins.length dependencies ) < 0 ) then "" else ''
  mkdir -p node_modules
  pushd node_modules
'' + ( builtins.concatStringsSep "\n" ( map maybeUnpack dependencies ) ) + ''
  popd
''
