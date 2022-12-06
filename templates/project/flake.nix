# ============================================================================ #
#
# FIXME: change "PROJECT" to your project name.
#
# ---------------------------------------------------------------------------- #
{

  description = "a `package-lock.json(v3)' project with Floco";

  inputs.nixpkgs.follows   = "/at-node-nix/nixpkgs";
  inputs.at-node-nix.url   = "github:aameen-tulip/at-node-nix";
  inputs.flocoPackages.url = "github:aakropotkin/flocoPackages";
  inputs.flocoPackages.inputs.at-node-nix.follows = "/at-node-nix";
  inputs.flocoPackages.inputs.nixpkgs.follows     = "/nixpkgs";

# ---------------------------------------------------------------------------- #

  outputs = { nixpkgs, at-node-nix, flocoPackages, ... } @ inputs: let

    pjs = nixpkgs.lib.importJSON ./package.json;

# ---------------------------------------------------------------------------- #

    # These are provided for reference and will allow you to probe package
    # information with `nix repl' or `nix eval'.
    # These will be exposed as flake outputs for your convenienct but can be
    # removed if you don't plan to poke around.
    metaSetEvalSettings = {
      pure         = true;
      ifd          = false;
      allowedPaths = [( toString ./. )];
      typecheck    = true;
    };
    # Metadata scraped from the lockfile without any overrides by the cache.
    lockMeta = let
      inherit (at-node-nix) lib;
    in if ! ( builtins.pathExists ./package-lock.json ) then {} else
      lib.callWith metaSetEvalSettings lib.metaSetFromPlockV3 {
        lockDir = toString ./.;
      };
    # Metadata defined explicitly in `meta.nix' or `meta.json' ( if any )
    cacheMeta = let
      metaJSON = nixpkgs.lib.importJSON ./meta.json;
      metaRaw =
        if builtins.pathExists ./meta.nix  then import ./meta.nix else
        if builtins.pathExists ./meta.json then metaJSON else
        {};
    in if metaRaw != {}
       then at-node-nix.lib.metaSetFromSerial' metaSetEvalSettings metaRaw
       else {};
    # The "merged" metadata from the lockfile and `meta.{json,nix}'.
    # This approximates the `flocoPackages' used to build - but keep in mind
    # that this isn't showing any upstream or downstream overlays.
    # Nonetheless it's an incredibly useful hunk of data that you'll likely
    # reference often if you are analyzing/optimizing the build system.
    metaSet = if lockMeta == {} then cacheMeta else
              lockMeta.__extend ( _: _: cacheMeta.__entries or cacheMeta );


# ---------------------------------------------------------------------------- #

    # Adds packages from `meta.nix' or `meta.json' if they exist.
    #
    # This is an ideal place to place lockfile overrides or optimized fetchers.
    # This can also be used to cache pre-evaluated metadata to avoid processing
    # dynamically on every run.
    # The command `nix run at-node-nix#genMeta -- "$PWD" --dev > meta.nix;'
    # is a great jumping off point ( add `--json' to get `meta.json' ).
    #
    # If no such file exists this overlay is a no-op, and if you don't plan
    # to use `meta.{json,nix}' you can delete this overlay entirely.
    #
    # NOTE: With the fresh template, the order of overlays in `overlays.deps'
    # will cause `meta.{json,nix}' entries to be used in favor of metadata
    # pulled from `package-lock.json' - this behavior can be changed by
    # modifying the order of the composition in `overlays.deps', or by writing
    # an explicit merge in `overlays.deps'.
    # See upstream Nixpkgs "overlays" documentation for details ( they're
    # honestly just a fancy "update"/merge operator like `a // b' ).
    overlays.cachePackages = final: prev: let
      metaJSON = final.lib.importJSON ./meta.json;
      metaRaw =
        if builtins.pathExists ./meta.nix  then import ./meta.nix else
        if builtins.pathExists ./meta.json then metaJSON else {};
    in if metaRaw == {} then {} else {
       flocoEnv = prev.flocoEnv // {
         allowedPaths =
           prev.lib.unique ( ( prev.flocoEnv.allowedPaths or [] ) ++
                             [( toString ./. )] );
       };
       flocoPackages = prev.flocoPackages.extend ( fpFinal: fpPrev: let
         metaSet = final.lib.metaSetFromSerial' {
           inherit (final.flocoEnv) pure ifd allowedPaths typecheck;
         } metaRaw;
         proc = acc: k: if prev ? ${k} then acc else acc // {
           ${k} = ( prev.lib.apply final.mkSrcEnt' final.flocoEnv )
                                                   metaSet.${k};
         };
       in builtins.foldl' proc {} ( builtins.attrNames metaSet.__entries ) );
    };

    # Adds packages from `package-lock.json' to `flocoPackages' as "raw"
    # sources - no builds are executed, tarballs are consumed "as is".
    # We only ADD missing packages, we do not override existing ones.
    # With that in mind, if you have dependencies that needs builds you can
    # safely add them in other overlays without worrying about this lockfile's
    # "raw sources" clobbering an explicitly defined builder.
    overlays.lockPackages = final: prev: let
      metaSet = final.lib.metaSetFromPlockV3 {
        lockDir = toString ./.;
        inherit (final.flocoEnv) pure ifd allowedPaths typecheck;
      };
    in if ! ( builtins.pathExists ./package-lock.json ) then {} else {
      flocoEnv = prev.flocoEnv // {
        allowedPaths = prev.lib.unique ( ( prev.flocoEnv.allowedPaths or [] ) ++
                                         [( toString ./. )] );
      };
      flocoPackages = prev.flocoPackages.extend ( fpFinal: fpPrev: let
        proc = acc: k: if prev ? ${k} then acc else acc // {
          ${k} = ( prev.lib.apply final.mkSrcEnt' final.flocoEnv ) metaSet.${k};
        };
      in builtins.foldl' proc {} ( builtins.attrNames metaSet.__entries ) );
    };

    # Composes upstream `flocoPackages' modules with definitions defined in
    # our lock and meta.{json,nix} ( see note above ).
    # The default routine with this template is essentially the same as:
    #   let
    #     fp0 = flocoPackages;
    #     fp1 = fp0 // ( cachePackages - f0 );  # only add new defs
    #     fp2 = fp1 // ( lockPackages - f1 );   # only add new defs
    #     fp3 = fp2 // PACKAGE;  # add new defs, and overwrite existing defs.
    #   in fp3
    # Users are free to rearrange or write more complex merge operations
    # as desired.
    # This is your opportunity to get your package set in order before adding
    # the build/derivations for the project that this flake targets.
    # When reading the example above read "essentially".
    # I'm glossing over the details about "self-reference" and just focusing
    # on the merge operation.
    #
    # Projects which consume your flake as a dependency are expected to use
    # this overlay + your "standalone" package overlay ( defined below )
    # using the output `overlays.default'.
    # Keep in mind that because these overlays are all composed, the user is
    # free to modify/override packages you consume in "their instance".
    # Knowing this may help you organize these overlays as well as any other
    # overlays you consume.
    overlays.deps = nixpkgs.lib.composeManyExtensions [
      flocoPackages.overlays.default
      overlays.cachePackages
      overlays.lockPackages
    ];

    # A standalone overlay with your project and any "high priority" overrides.
    # This overlay will clobber any previously defined packages in
    # `overlays.deps' when consumed.
    # In general try to keep this overlay minimal, and defer to multiple
    # composable overlays ( "layers" of package defintions ) to give consumers
    # more flexibility in cherry picking which packages they want to use.
    overlays.PROJECT = final: prev: let
      callFlocoPackage = prev.lib.callPackageWith {
        inherit (final) lib evalScripts flocoPackages;
      };
    in {
      # Adds this project as a "module" to `flocoPackage' for consumption by
      # other projects.
      # If you're producting a CLI tool or executable that no other projects
      # consume as a `node_modules/' dependency then you won't /really/ need
      # to extend `flocoPackages' here, but doing so isn't harmful.
      flocoPackages = prev.flocoPackages.extend ( fpFinal: fpPrev: let
        # The "key" for your project is used to avoid collisions with other
        # versions of this module, and it also allows other projects to easily
        # grab the version they want from the larger collection of packages.
        #
        # Because this is a template, and because users likely expect for their
        # package's key to update if/when they modify `package.json:version',
        # we treat it as a variable here, but you could just as easily write
        # `"@foo/bar/1.0.0" = ...;' if you wanted to.
        # Keep this in mind when using `nix repl' or `nix eval' to inspect
        # `metaSet' or `flocoPackages', and while writing `meta.{nix,json}'
        # information - the key used across all of these structures is the same.
        key = "${pjs.name}/${pjs.version}";
      in {
        # XXX: see note above about `key'.
        ${key} = callFlocoPackage ./build.nix {
          ident = pjs.name;
          inherit (pjs) version;
          # We'll auto-generate a set of `node_modules/' directory builders
          # using our `package-lock.json'.
          # This will assign a "key" to each dependency in the lock, which is
          # substituted with the package defind in `flocoPackages'.
          # For example: a `packages.*' key in the lock for
          # `node_modules/@foo/bar/node_modules/@baz/quux' where `@baz/quux'
          # is recorded as `version = 4.2.0' will cause `mkNmDirPlockV3' to
          # install whatever is in `flocoPackages."@baz/quux/4.2.0".outPath'
          # into `<BUILD-AREA>/node_modules/@foo/bar/node_modules/@baz/quux/'.
          #
          # This "magic" auto-generation routine is built from a flexible set
          # of modular utilities that can be used more directly to get fine
          # grain control of the tree: you can override, delete, add, move,
          # copy, symlink, or whatever you want using basically any kind of
          # input you want ( they don't need to be `flocoPackages' you can
          # dump a raw tarball or install `nixpkgs#hello' if you cared to ).
          # Please refer to `at-node-nix' upstream docs under
          # `<at-node-nix>/pkgs/mkNmDir' and `<at-node-nix>/lib/libtree' for
          # more information.
          #
          # `nmDirs' returned by `mkNmDirPlockV3' is an attrset with a few
          # pre-generated trees that should cover the majority of use cases.
          # if you define additional derivations ( for example `test' or
          # `global' for an executable ) you might have a need for these.
          # Tests that use `jest' or builds that use `webpack' often need
          # copied modules rather than symlinks, and at runtime you'll want to
          # use the "prod" trees.
          # Below is a map of the `nmDirs' provided out of the box, but remember
          # that `at-node-nix' carries a wider collection of generators if you
          # have a need for them.
          #
          #   nmDirs = {
          #     # A sane default NM dir ( `devLink' symlinks dev tree )
          #     nmDirCmd = {
          #       cmd = <STRING>;  # Shell script which defines installers.
          #       # Records options used for this instance.
          #       meta = { dev = <BOOL>; copy = <BOOL>; ... };
          #       passthru = { tree = {...}; ... }; };  # stashed extras
          #       override = <FUNCTION>;  # can be used to recall with new args
          #     };
          #     cmd = <STRING>;  # Alias of `nmDirCmd.cmd' ( default script ).
          #     # Other common `node_modules/' builders.
          #     nmDirCmds = {
          #       devCopy  = ...;
          #       devLink  = ...;
          #       prodCopy = ...;
          #       prodLink = ...;
          #     };
          #     ...
          #   };
          nmDirs =
            if builtins.pathExists ./package-lock.json
            then final.mkNmDirPlockV3 {
              lockDir = toString ./.;
              inherit (final) flocoPackages;
            } else final.mkNmDirLinkCmd {
              tree = let
                metaRaw =
                  if builtins.pathExists ./meta.nix then import ./meta.nix else
                  at-node-nix.lib.importJSONOr {} ./meta.json;
              in metaRaw._meta.trees.dev or
                 ( throw "No tree definition found" );
              inherit (final) flocoPackages;
            };
        };  # End module definition
      } );  # End flocoPackages
    };  # End PROJECT Overlay

    # Our project + dependencies prepared for consumption as a Nixpkgs extension.
    overlays.default = nixpkgs.lib.composeExtensions overlays.deps
                                                     overlays.PROJECT;

# ---------------------------------------------------------------------------- #

  in {  # Begin Outputs

# ---------------------------------------------------------------------------- #

    # Metadata reference, useful for analysis and debugging.
    # This can be safely removed without effecting the build - see note up top
    # for more info.
    inherit pjs lockMeta cacheMeta metaSet;
    plock = at-node-nix.lib.importJSONOr "No Such File" ./package-lock.json;

# ---------------------------------------------------------------------------- #

    # Exposes our extension to Nixpkgs for other projects to use.
    inherit overlays;

# ---------------------------------------------------------------------------- #

    # Exposes our project to the Nix CLI
    packages = at-node-nix.lib.eachDefaultSystemMap ( system: let
      pkgsFor = at-node-nix.legacyPackages.${system}.extend overlays.default;
      package = pkgsFor.flocoPackages."${pjs.name}/${pjs.version}";
    in {
      # Expose our package as an "installable". ( uses package.json name ).
      ${baseNameOf pjs.name} = package;
      # Make the default install target our package.
      default = package;

      # We'll make a test-suite runner available from the CLI as well.
      # The default test prints "PASS" or "FAIL" to the file `test.log' and
      # we use `checkPhase' to convert that into an exit status.
      # An exit failure will not be cached by Nix, so if you want to keep the
      # tree you can add the flag `--keep-failed' on the CLI.
      #
      # To run your test suite with logging:  `nix run .#test -L;'
      test = pkgsFor.evalScripts {
        name = "${baseNameOf pjs.name}-tests-${pjs.version}";
        src  = package;  # Use our built project as the root of the test env.
        # For running the test suite we'll use symlinks of the production tree.
        # The `nmDirPlockV3' info we used previously can be referenced here so
        # we can avoid the boilerplate of generating `nmDirs' again.
        nmDirCmd = package.passthru.nmDirs.passthru.prodLink or
          ( pkgsFor.mkNmDirLinkCmd {
              tree = let
                metaRaw =
                  if builtins.pathExists ./meta.nix then import ./meta.nix else
                  at-node-nix.lib.importJSONOr {} ./meta.json;
              in metaRaw._meta.trees.prod or
                 ( throw "No tree definition found" );
              inherit (pkgsFor) flocoPackages;
            } );
        runScripts = ["test"];
        checkPhase = ''
          grep -q '^PASS$' ./test.log||exit 1;
        '';
      };

      tarball = pkgsFor.mkTarballFromLocal {
        name     = "${baseNameOf pjs.name}-${pjs.version}.tgz";
        source   = package.src;
        prepared = package;
      };
    } );


# ---------------------------------------------------------------------------- #
  
    # This can be used to generate the `meta.{nix,json}' files mentioned at the
    # top of this template.
    # This is just calling `at-node-nix#genMeta', but it adds `--dev' by
    # default ( unless other flags are given ), and it automatically targets
    # our project.
    #
    # You could generate a JSON cache ( effectively a lockfile ) using.
    #   nix run .#regen-cache -- --dev --json > meta.json && git add ./meta.json
    # Now Nix will be able to skip some runtime processing, only falling back
    # to the `package-lock.json' when the cache is missing new dependencies.
    apps = at-node-nix.lib.eachDefaultSystemMap ( system: let
      pkgsFor = at-node-nix.legacyPackages.${system}.extend overlays.default;
      flakeRef = toString inputs.at-node-nix;
    in {
      regen-cache.type    = "app";
      regen-cache.program = let
        script = pkgsFor.writeShellScript "regen-cache" ''
          _extra_args=""
          if test -r ./package-lock.json; then
            _extra_args="--lockfile $PWD/package-lock.json";
          elif test -r ./package.json; then
            _extra_args="$PWD";
          else
            echo "You must run this script in the root of the repo" >&2;
            exit 1;
          fi
          ${pkgsFor.nix}/bin/nix run ${flakeRef}#genMeta -- "''${@:---dev}"  \
                                                            $_extra_args;
        '';
      in script.outPath;

    } );


# ---------------------------------------------------------------------------- #

  };  # End Outputs

}


# ---------------------------------------------------------------------------- #
#
# SERIAL: 8
#
# ============================================================================ #
