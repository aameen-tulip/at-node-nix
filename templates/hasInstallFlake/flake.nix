{
  inputs.at-node-nix.url = "github:aameen-tulip/at-node-nix";
  inputs.at-node-nix.inputs.nixpkgs.follows = "/nixpkgs";

# ---------------------------------------------------------------------------- #

  outputs = {
    self
  , nixpkgs
  , at-node-nix
  # Optionals: Will fall back to reading files in flake's root dir.
  # ? flocoConfig
  # ? packument    "file+https://registry.npmjs.org/@foo/bar"
  # ? manifest     "file+https://registry.npmjs.org/@foo/bar/1.0.0"
  # ? source       Any source tree.
  #                ex: "https://registry.npmjs.org/@foo/bar/-/-bar-1.0.0.tgz"
  # ? metaSet      serialized JSON or Nix expression.
  # ? plock        path to file, or JSON, or expression of `package-lock.json'
  # ? pjs          path to file, or JSON, or expression of `package.json'
  , ...
  } @ inputs: let

# ---------------------------------------------------------------------------- #

    eachSupportedSystemMap = let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forSys = fn: system: { name = system; value = fn system; };
    in fn: builtins.listToAttrs ( map ( forSys fn ) supportedSystems );


# ---------------------------------------------------------------------------- #

  in {  # Begin Outputs

# ---------------------------------------------------------------------------- #

    # Read from inputs if given, otherwise use default.
    # A partial config may be provided and it will be merged with the defualt.
    flocoConfig = let
      inherit (at-node-nix) lib;
      fromInput = lib.importJSON inputs.flocoConfig.outPath;
      cfg = if inputs ? flocoConfig then fromInput else {};
    in lib.mkFlocoConfig cfg;


# ---------------------------------------------------------------------------- #

    # Specialize `lib' using our `flocoConfig' settings.
    # This only effects a small number of functions, notably fetchers,
    # registries, and trees.
    # Additional specialization is performed when `system' is known in `pkgSet'
    # contexts allowing trees to filter by system, and fetchers to be optimized.
    lib = at-node-nix.lib.extend ( final: prev: {
      inherit (self) flocoConfig;
      flocoFetch = final.mkFlocoFetcher { inherit (final) flocoConfig; };
    } );


# ---------------------------------------------------------------------------- #

    # Metadata used to create our package set.
    # These entries will also be exposed through `flocoOverlays.metaSet' for
    # other projects to consume.
    # This `metaSet' is formed within the context that the "root" entry for any
    # trees, and any other package specific metadata is within the scope of the
    # `root' ( e.g. the top level `__meta.(pjs|plock|lockDir|trees|...)' data ).
    metaSet = let
      inherit (self) lib;
      serial =
        if inputs ? metaSet then lib.importJSON inputs.metaSet.outPath else
        if builtins.pathExists "${toString ./meta.nix}" then
          import ./meta.nix
        else if builtins.pathExists "${toString ./meta.json}" then
          lib.importJSON "${toString ./meta.json}"
        else null;
      fromSerial = lib.metaSetFromSerial serial;
      fromPlock = let
        localArgs = { lockDir = "${input.source or self}"; };
        inputArgs = builtins.intersectAttrs {
          plock = true;
          pjs   = true;
        } inputs;
        args = if inputArgs == {} then localArgs else
              inputArgs // ( lib.optionalAttrs ( inputs ? source ) {
                lockDir = inputs.source.outPath;
              } );
      in lib.metaSetFromPlockV3 args;
    in if serial != null then fromSerial else fromPlock;

    # When exposing a metaSet for overlays, we push the tree info into the
    # root entry, and drop our top level `__meta' and other extensible attrs.
    # Otherwise we'll clobber those fields in a `metaSet' which tries to
    # consumer our info.
    flocoOverlays.metaSet = final: prev: let
      inherit (metaSet.__meta) rootKey;
      rootEnt = metaSet.${rootKey}.__add { inherit (metaSet.__meta) trees; };
    in metaSet.__entries // { ${rootKey} = rootEnt; };

    # Generate builders for our packages using our `metaSet' data.
    # FIXME: The template naively assumes that all dependencies are "simple",
    # and can be consumed from source.
    # If this is not suitable for your project, add additional build recipes to
    # the overlay below.
    flocoOverlays.pkgSet = eachSupportedSystemMap ( system: final: prev: let
      # Specialize our config using system info.
      flocoConfig = self.flocoConfig // {
        npmSys = self.lib.getNpmSys' { inherit system; };
      };
      # Regenerate lib with system info.
      lib = self.lib.extend ( lFinal: lPrev: { inherit flocoConfig; } );
      pkgsFor = at-node-nix.legacyPackages.${system}.extend ( pFinal: pPrev: {
        inherit flocoConfig lib;
      } );
      inherit (metaSet.__meta) rootKey;
      srcEnts = builtins.mapAttrs ( _: pkgsFor.mkPkgEntSourceEnt )
                                  metaSet.__entries;
    in srcEnts // prev // {
      ${rootKey} = srcEnts.${rootKey} // {
        installed = pkgsFor.installPkgEnt ( srcEnts.${rootKey} // {
          nmDirCmd = pkgsFor.mkNmDirPlockV3 {
            inherit metaSet;
            pkgSet = final;
          };
        } );
        prepared = final.${rootKey}.installed;
        outPath  = final.${rootKey}.prepared.outPath;
      };
    } );


# ---------------------------------------------------------------------------- #

    packages = eachSupportedSystemMap ( system: let
      inherit (metaSet.__meta) rootKey;
      pkgSet = self.lib.fix self.flocoOverlays.pkgSet.${system} {};
    in {
      ${rootKey} = pkgSet.${rootKey};
      default    = self.packages.${system}.${rootKey};
    } );


# ---------------------------------------------------------------------------- #

  };

# ---------------------------------------------------------------------------- #
}
