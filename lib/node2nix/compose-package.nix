# NOTE: This has a recursive definition with `includeDependencies'.
{ includeDependencies }:
# Recursively composes the dependencies of a package
# `node2nix' calls this `composePackage'
{ name
, packageName
, src
, dependencies ? []
, ...
}@args:
builtins.addErrorContext "while evaluating node package '${packageName}'" ''
  installPackage "${packageName}" "${src}"
'' + ( includeDependencies { inherit dependencies; } ) +
# FIXME: Use `popd', this is hideous.
#        This requires a change to `installPackage' as well.
( if ( builtins.substring 0 1 packageName == "@" )
  then "cd ../.." else "cd .." )
