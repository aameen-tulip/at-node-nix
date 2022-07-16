{ lib
, stdenv

# NOTE: You aren't required to pass these, but they serve as fallbacks.
# I have commented them out to prevent accidental variable shadowing; but it is
# recommended that you pass them.
## , nodejs ? null
## , jq     ? null
, ...
} @ globalAttrs: let

  # Evaluate the named script fields in a project's `package.json' file.
  # This is analogous to `npm run SCRIPT' or `yarn run SCRIPT'.
  #
  # Assumes that `src' is an unpacked Node.js package with `package.json' at
  # the root level.
  # `nodeModules' should most likely be a derivation produced by `linkModules',
  # which will be made available when scripts are evaluated; additionally,
  # `node_modules/.bin/' will be added to `PATH'.
  # This folder is removed after scripts have been evaluated, and the working
  # directory is moved to `$out'.
  #
  # Your scripts will run in a `stdenv' environment with `nodejs' and `jq'
  # available ( in addition to the `node_modules/.bin' scripts ).
  # Additional inputs may be passed in using `nativeBuildInputs', `buildInputs',
  # etc - but note that `jq' and `nodejs' are appended to `nativeBuildInputs';
  # so you don't have to worry about headaches there.
  # ( AFAIK you can still wipe them out with an `overlay' ).
  #
  # The only other "special" attribute similar to `nativeBuildInputs' is
  # `passthru', which is extended with `src', `nodejs', and `nodeModules'.
  # Note that we do NOT extend `nodejs.pkgs' which are modules used within
  # Nixpkgs to support various tools.
  # If you do want to extend that package set you can do so with an overlay
  # after calling `evalScripts', and presumably you'll need to perform
  # additional steps to match the `node2nix' install structure before adding
  # to that package set.
  evalScripts = {
    name ? let
      bn = if ( ident != null ) then ( baseNameOf ident ) else "node-pkg";
      v  = if ( version != null ) then "-" + v else "";
    in bn + "-inst-" + v
  , ident   ? src.meta.ident or null    # Just used for the name fallback
  , version ? src.meta.version or null  # Just used for the name fallback
  , src
  , nodeModules
  # If you ACTUALLY want to avoid this you can explicitly set to `null' but
  # honestly I never seen a `postInstall' that didn't call `node'.
  , nodejs ? globalAttrs.nodejs or ( throw "You must pass nodejs explicitly" )
  , jq     ? globalAttrs.jq  or ( throw "You must pass jq explicitly" )
  # Scripts to be run during `builPhase'.
  # These are executed in the order they appear, and may appear multiple times.
  , runScripts ? [
      "preinstall"
      "install"
      "postinstall"
    ]
  # If a script is not found, is will be skipped unless `skipMissing' is false.
  , skipMissing     ? true
  # Skip linking the `node_modules' directory.
  , dontLinkModules ? false
  } @ attrs: let
    mkDrvArgs = removeAttrs attrs [
      "ident"
      "nodejs"
      "jq"
      "nodeModules"
      "skipMissing"
      "dontLinkModules"
      "runScripts"
      "nativeBuildInputs"  # We extend this
      "passthru"           # We extend this
    ];

  in stdenv.mkDerivation ( {
    nativeBuildInputs = ( attrs.nativeBuildInputs or [] ) ++ [jq] ++
                        ( lib.optional ( nodejs != null ) nodejs );
    postUnpack = lib.optionalString ( ! dontLinkModules ) ''
      ln -s -- ${nodeModules} "$sourceRoot/node_modules"
      export PATH="$PATH:$sourceRoot/node_modules/.bin"
    '';
    buildPhase = let
      runOne = sn: let
        fallback = lib.optionalString skipMissing "// \":\"";
      in ''eval "$( jq -r '.scripts.${sn} ${fallback}' ./package.json; )"'';
      runAll = builtins.concatStringsSep "\n" ( map runOne runScripts );
    in lib.withHooks "build" runAll;
    installPhase = lib.withHooks "install" ''
      rm -f -- ./node_modules
      cd "$NIX_BUILD_TOP"
      mv -- "$sourceRoot" "$out"
    '';
    passthru = ( attrs.passthru or {} ) // { inherit src nodejs nodeModules; };
  } // mkDrvArgs );

    # XXX: Certain `postInstall' scripts might actually need to be
    # `setupHook's because they sometimes try to poke around the top level
    # package's `node_modules/' directory to sanity check API compatibility
    # when version conflicts exist in a node environment.
    # PERSONALLY - I don't think that they should do this, and I'll point out
    # that every single package that I have seen do this was accompanied by
    # a security audit alert by NPM... but I'm calling this "good enough"
    # until I actually find a package that breaks.

in evalScripts
