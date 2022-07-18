{ lib
, evalScripts
, stdenv
, nodejs
, jq
} @ globalAttrs: let

  runBuild = {
    name              ? meta.names.built
  , version           ? meta.version
  , src
  , nodeModules       # Expected to be `nodeModulesDir-dev'
  , meta              ? {}
  , nodejs            ? globalAttrs.nodejs
  , jq                ? globalAttrs.jq
  , stdenv            ? globalAttrs.stdenv
  , buildInputs       ? []
  , nativeBuildInputs ? []  # `nodejs' and `jq' are added unconditionally
  , runPrePublish     ? ( args ? entType ) && ( args.entType != "git" )
  , ...
  } @ args: let
    evalScriptArgs = removeAttrs args ["runScripts runPrePublish"];
  in evalScripts ( {
    inherit name src version nodejs jq nodeModules;
    inherit buildInputs nativeBuildInputs;
    # Both `dependencies' and `devDependencies' are available for this step.
    # NOTE: `devDependencies' are NOT available during the `install'/`prepare'
    # builder and you should consider how this effects both closures and
    # any "non-standard" fixups you do a package.
    runScripts = [
      # These aren't supported by NPM, but they are supported by Pacote.
      # Realistically, you want them because of Yarn.
      "prebuild" "build" "postbuild"
      # NOTE: I know, "prepublish" I know.
      # It is fucking evil, but you probably already knew that.
      # `prepublish' actually isn't run for publishing or `git' checkouts
      # which aim to mimick the creation of a published tarball.
      # It only exists for backwards compatibility to support a handful of
      # ancient registry tarballs.
    ] ++ ( lib.optional runPrePublish "prepublish" );
  } // evalScriptArgs );

in runBuild
