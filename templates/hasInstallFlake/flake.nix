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

    # Check for an optional input, using `fallback' if none exists.
    # If input is a file, import it from JSON to be used as an attrset.
    # This is most useful for passing in hints, configs, and other metadata.
    # `flocoConfig' for example may be imported from JSON and merged with the
    # `defaultFlocoConfig' defined below if `inputs.flocoConfig' is present.
    # Pay attention to the priority behavior since it can allow you to
    # use a file, or a flake where `outputs.${field}' or outputs is used as
    # an attrset.
    # If these don't exactly fit your use case use it as a reference.
    getInputAsAttrsOr = field: fallback: let
      x =
        inputs.${field}
        or inputs.${field}.outputs.${field}
        or inputs.${field}.outputs
        or fallback;
      xIsFile = ( builtins.isAttrs x ) && ( x ? outPath ) &&
                ( ( lib.categorizePath x.outPath ) != "directory" );
    in if xIsFile then lib.importJSON' ( toString x ) else x;


# ---------------------------------------------------------------------------- #

    mkLib = _flocoConfig: at-node-nix.lib.extend ( final: prev: {
      flocoConfig = _flocoConfig;
      flocoFetch  = final.libfetch.mkFlocoFetcher {
        inherit (final) flocoConfig;
      };
    } );

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
    eachSupportedSystemMap = let
      supportedSystems = [
        "x86_64-linux"  "x86_64-darwin"
        "aarch64-linux" "aarch64-darwin"
      ];
      sysAutoArgs = system: {
        inherit system;
        flocoConfig = self.flocoConfig // {
          npmSys = at-node-nix.lib.getNpmSys' { inherit system; };
        };
        lib     = mkLib selfSys.flocoConfig;
        pkgsFor = at-node-nix.legacyPackages.${system}.extend ( final: prev: {
          inherit (selfSys) flocoConfig lib;
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

    metaSet = let
      wants = {
        plock     = true;
        pjs       = true;
        lockDir   = true;
        lockPath  = true;
        pjsPath   = true;
        manifest  = true;
        packument = true;
      };
      knowns = { /* FIXME */ };
      fromPlock = lib.libmeta.metaSetFromPlockV3 ( {
        inherit (self) flocoConfig;
        inherit plock;
      } ( lib.optionalAttrs ( pjs != null ) { inherit pjs; } ) );
    in getInputsAsAttrsOr "metaSet" fallback;

    inherit (metaSet.__meta) rootKey;


# ---------------------------------------------------------------------------- #

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

    lib = mkLib self.flocoConfig;

# ---------------------------------------------------------------------------- #


    # Read from inputs if given, otherwise use default.
    # A partial config may be provided and it will be merged with the defualt.
    flocoConfig = let
      raw = getInputAsAttrsOr "flocoConfig"
                              at-node-nix.lib.libcfg.defaultFlocoConfig;
      merged = if inputs ? flocoConfig
               then lib.recursiveUpdate defaultFlocoConfig raw
               else raw;
    in at-node-nix.lib.mkFlocoConfig merged;


# ---------------------------------------------------------------------------- #


# ---------------------------------------------------------------------------- #

    # When exposing a metaSet for overlays, we push the tree info into the
    # root entry, and drop our top level `__meta' and other extensible attrs.
    # Otherwise we'll clobber those fields in a `metaSet' which tries to
    # consumer our info.
    flocoOverlays.metaSet = final: prev: let
      rootEnt = metaSet.${rootKey}.__add { inherit (metaSet.__meta) trees; };
    in metaSet.__entries // { ${rootKey} = rootEnt; };
    flocoOverlays.pkgSet = final: prev: {
      ${rootKey} = pkgEntFor prev.system;
    };


# ---------------------------------------------------------------------------- #

    packages = eachDefaultSystemMap ( system: {
      msgpack = ( pkgEntFor system ).prepared;
      default = self.packages.${system}.msgpack;
    } );


# ---------------------------------------------------------------------------- #

    apps = eachDefaultSystemMap ( system: let
      selfFor = self.packages.${system};
      pkgsFor = pkgsForSys system;
    in {
      msgpack2json = {
        type = "app";
        program = "${selfFor.msgpack}/bin/msgpack2json";
      };
      json2msgpack = {
        type = "app";
        program = "${selfFor.msgpack}/bin/json2msgpack";
      };
    } );

  };
}
