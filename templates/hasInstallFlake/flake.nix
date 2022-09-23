{
  inputs.at-node-nix.url = "github:aameen-tulip/at-node-nix";
  inputs.at-node-nix.inputs.nixpkgs.follows = "/nixpkgs";

# ---------------------------------------------------------------------------- #

  outputs = {
    self
  , nixpkgs
  , utils
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
    
    metaSet = let
      inherit (self) lib;
      serial =
        if inputs ? metaSet then lib.importJSON inputs.metaSet.outPath else
        if builtins.pathExists "${toString ./meta.nix}" then
          import ./meta.nix
        else if builtins.pathExists "${toString ./meta.json}" then
          lib.importJSON ./meta.json
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

    inherit (metaSet.__meta) rootKey;


# ---------------------------------------------------------------------------- #

    # Danker `flake-utils.eachSystemMap' which will try to pass extra system
    # specific args such as `pkgsFor', `lib' ( configured for sys ), and
    # `flocoConfig' if they can be accepted.
    # This accepts either:
    #   fn :: string -> any
    #   fn :: attrs -> any
    #   fn :: string -> attrs -> any  ( curried )
    # For both attrs types above `system' does not necessarily need to be an
    # argument; but it may be.
    eachSupportedSystemMap = fn: let
      supportedSystems = [
        "x86_64-linux"  "x86_64-darwin"
        "aarch64-linux" "aarch64-darwin"
      ];
      sysAutoArgs = system: let
        flocoConfig = self.flocoConfig // {
          npmSys = self.lib.getNpmSys' { inherit system; };
        };
        lib = self.lib.exend ( final: prev: { inherit flocoConfig; } );
      in {
        inherit system flocoConfig lib;
        pkgsFor = at-node-nix.legacyPackages.${system}.extend ( final: prev: {
          inherit flocoConfig lib;
        } );
      };
      forSys = system: {
        name = system;
        value = let
          baseFnArgs = lib.functionArgs fn;
          autoFn     = if baseFnArgs != {} then fn else fn system;
          canAuto    = ( builtins.isFunction autoFn ) || ( autoFn ? __functor );
          fnArgs     = lib.functionArgs autoFn;
          autoArgs   = builtins.intersectAttrs fnArgs ( sysAutoArgs system );
        in if canAuto then autoFn autoArgs else fn system;
      };
    in builtins.listToAttrs ( map forSys supportedSystems );


# ---------------------------------------------------------------------------- #

    pkgsForSys = system: (eachSupportedSystemMap system).${system}.pkgsFor;
    pkgEntFor = system: let
      pkgsFor = pkgsForSys system;
      pkgEntSrc = pkgsFor.mkPkgEntSource metaSet.${rootKey};
      installed = pkgsFor.installPkgEnt ( pkgEntSrc // {
        nmDirCmd = let
          nan-key = metaSet.__meta.trees.prod."node_modules/nan";
          nan     = pkgsFor.mkPkgEntSource metaSet.${nan-key};
        in ''
          mkdir -p "$node_modules_path";
          ln -s ${nan.source} "$node_modules_path/nan";
        '';
      } );
    in pkgEntSrc // {
      inherit installed;
      inherit (installed) outPath;
      prepared = installed;
    };


# ---------------------------------------------------------------------------- #

  in {  # Begin Outputs

# ---------------------------------------------------------------------------- #

    lib = at-node-nix.lib.extend ( final: prev: {
      inherit (self) flocoConfig;
      flocoFetch = final.libfetch.mkFlocoFetcher {
        inherit (final) flocoConfig;
      };
    } );

# ---------------------------------------------------------------------------- #

    # Read from inputs if given, otherwise use default.
    # A partial config may be provided and it will be merged with the defualt.
    flocoConfig = let
      fromInput = lib.importJSON inputs.flocoConfig.outPath;
      raw = if inputs ? flocoConfig then fromInput else
            at-node-nix.lib.libcfg.defaultFlocoConfig;
      merged =
        if inputs ? flocoConfig
        then lib.recursiveUpdate at-node-nix.lib.libcfg.defaultFlocoConfig raw
        else raw;
    in at-node-nix.lib.mkFlocoConfig merged;


# ---------------------------------------------------------------------------- #

    # When exposing a metaSet for overlays, we push the tree info into the
    # root entry, and drop our top level `__meta' and other extensible attrs.
    # Otherwise we'll clobber those fields in a `metaSet' which tries to
    # consumer our info.
    flocoOverlays.metaSet = final: prev: let
      rootEnt = metaSet.${rootKey}.__add { inherit (metaSet.__meta) trees; };
    in metaSet.__entries // { ${rootKey} = rootEnt; };
    flocoOverlays.pkgSet = eachSupportedSystemMap ( {
      system
    , pkgsFor
    , flocoConfig
    , lib
    }: final: prev: let
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
      };
    };


# ---------------------------------------------------------------------------- #

    # FIXME: define `metaSet' as you've done for `flocoPackages'?
    inherit metaSet;

    flocoPackages = eachSupportedSystemMap { system }:
      lib.fix self.flocoOverlays.pkgSet.${system} {};

    packages = eachSupportedSystemMap ( {
      system
    , pkgsFor
    , lib
    , flocoConfig
    }: {
      ${rootKey} = self.flocoPackages.${rootKey};
      default    = self.packages.${system}.${rootKey};
    } );


# ---------------------------------------------------------------------------- #

  };

# ---------------------------------------------------------------------------- #
}
