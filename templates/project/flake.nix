# ============================================================================ #
#
# FIXME: change "PROJECT" to your project name.
#
# ---------------------------------------------------------------------------- #
{

  description = "a `package-lock.json(v3)' project with Floco";

  inputs.nixpkgs.follows = "/at-node-nix/nixpkgs";
  inputs.at-node-nix.url   = "github:aameen-tulip/at-node-nix";
  inputs.flocoPackages.url = "github:aakropotkin/flocoPackages";

# ---------------------------------------------------------------------------- #

  outputs = { nixpkgs, at-node-nix, flocoPackages, ... } @ inputs: let

    inherit (at-node-nix) lib;
    pjs = lib.importJSON ./package.json;

# ---------------------------------------------------------------------------- #

    # Adds packages from `package-lock.json' to `flocoPackages' as "raw"
    # sources - no builds are executed, tarballs are consumed "as is".
    # We only ADD missing packages, we do not override existing ones.
    # With that in mind, if you have dependencies that needs builds you can
    # safely add them in other overlays without worrying about this lockfile's
    # "raw sources" clobbering an explicitly defined builder.
    overlays.lockPackages = final: prev: {
      flocoPackages = prev.flocoPackages.extend ( fpFinal: fpPrev: let
        metaSet = final.lib.metaSetFromPlockV3 { lockDir = toString ./.; };
        keeps   = removeAttrs metaSet.__entries ( builtins.attrNames fpPrev );
        # `mkPkgEntSource' fetches and unpacks for us.
      in builtins.mapAttrs ( _: final.mkPkgEntSource ) keeps );
    };

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
        if builtins.pathExists ./meta.json then metaJSON else
        {};
    in if metaRaw == {} then {} else {
        flocoPackages = prev.flocoPackages.extend ( fpFinal: fpPrev: let
          metaSet = final.lib.metaSetFromSerial metaRaw;
          # Only add new definitions, don't clobber existing ones.
          keeps = removeAttrs metaSet.__entries ( builtins.attrNames fpPrev );
        in builtins.mapAttrs ( _: final.mkPkgEntSource ) keeps );
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
    # When reading the example above read "essentially" I'm glossing over the
    # details about "self-reference" and just focusing on the merge operation.
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

    # A stanalone overlay with your project and any "high priority" overrides.
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
          ident   = pjs.name;
          version = pjs.version;
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
          # Please refer to `at-node-nix' upstream docs under:
          #   `<at-node-nix>/pkgs/mkNmDir' and `<at-node-nix>/lib/libtree' for
          # more information.
          #
          # `nmDirs' returned by `mkNmDirPlockV3' is an attrset with a few
          # pre-generated trees that should cover the majority of use cases.
          # if you define additional derivations ( for example `test' or
          # `global' for an executable ) you can choose from:
          #   nmDir = {
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
          #       devCopy = ...;
          #       devLink = ...;
          #       procCopy = ...;
          #       procLink = ...;
          #     };
          #   };
          nmDirs = final.mkNmDirPlockV3 {
            lockDir = toString ./client;
            pkgSet  = final.flocoPackages;
          };
        };  # End module definition
      } );  #  End flocoPackages
    };  # End PROJECT Overlay

    # Our project + dependencies prepared for consumption as a Nixpkgs extension.
    overlays.default = nixpkgs.lib.composeExtensions overlays.deps
                                                     overlays.PROJECT;

# ---------------------------------------------------------------------------- #

  in {

# ---------------------------------------------------------------------------- #

    inherit overlays pjs;

# ---------------------------------------------------------------------------- #

    # Exposes our project to the Nix CLI
    packages = lib.eachDefaultSystemMap ( system: let
      pkgsFor = at-node-nix.legacyPackages.${system}.extend
                  self.overlays.default;
      package = pkgsFor.flocoPackages."${pjs.name}/${pjs.version}";
    in {
      ${baseNameOf pjs.name} = package;
      default                = package;
    } );


# ---------------------------------------------------------------------------- #

  };  # End Outputs

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
