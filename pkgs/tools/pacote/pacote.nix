
# Install `pacote' using a barebones `floco' pipeline.
# Rather than using default fetchers or build pipelines we stick to lower level
# utilies/interfaces.
#
# This file is an excellent reference for packaging a registry module

{ lib
  # Minimal implementation of `mkSrcEnt' for tarballs.
, mkSrcEnt' ? { ... } @ fenv: { fetchInfo, ... } @ metaEnt: let
    sourceInfo = builtins.fetchTree fetchInfo;
    source = {
      _type   = "fetched";
      ltype   = "file";
      ffamily = "file";
      inherit (sourceInfo) outPath;
      inherit fetchInfo sourceInfo;
      passthru.unpacked = true;
    };
  in {
    _type = "pkgEnt:source";
    inherit (metaEnt) key ident version;
    inherit source;
    inherit (source) outPath ltype;
    passthru = {
      metaEnt = metaEnt.__serial or metaEnt;
      names   =
        metaEnt.names or ( ( lib.libmeta.metaEntNames {
          inherit (metaEnt) ident version;
        } ) ).names;
    };
  }
, mkSrcEnt ? mkSrcEnt' { inherit ifd pure allowedPaths typecheck; }

  # Normally we might use `metaSetFromSerial', but here we already have
  # "complete" metadata and don't have any need to extend it.
, metaSet ? import ./meta.nix

, mkNmDirCopyCmd

, system
, evalScripts  # We would normally use `installGlobal', but since this is used
               # for reference we inline the definition.

, ifd
, pure
, allowedPaths
, typecheck

, ...
} @ args: let

  # Prepare all packages for consumption.
  pkgSet =
    builtins.mapAttrs ( _: mkSrcEnt ) ( metaSet.__entries or
                                        ( removeAttrs metaSet ["_meta"] ) );

  # Assign `node_modules/' paths to `outPath' of associated package.
  # If the arg `tree' is given, the caller may have provided `pkgEnt' values
  # already, or they might be a mix of keys and `pkgEnt' - so this routine
  # ensures all keys are converted to packages.
  pkgTree = let
    tree     = args.tree or metaSet.${metaSet._meta.rootKey}.trees.prod;
    treeDone = builtins.all ( x: x ? outPath ) ( builtins.attrValues tree );
    fallback = builtins.mapAttrs ( nmPath: key: pkgSet.${key} ) tree;
  in if treeDone then tree else fallback;

  pacoteEnt = pkgSet.${metaSet._meta.rootKey};

  # TODO: define `pkgEnt' as a `metaExt' record?

  # We create a recursively defined package definition.
in lib.makeExtensibleWithCustomName "__extend" ( self:
  pacoteEnt // {
    # We use `evalScripts' to leverage its default `setup-hooks', specifically
    # for patching shebangs and running installs.
    # We skip any usual "build" steps though.
    prepared = ( evalScripts {
      name  = pacoteEnt.passthru.names.global;
      pname = pacoteEnt.passthru.names.bname;
      inherit (pacoteEnt) version;
      src            = self.source;
      moduleInstall  = true;
      globalInstall  = true;  # Activates additional `global' output for install
      globalNmDirCmd = self.nmDirCmds.prod;
      # Don't run any scripts.
      runScripts = [];
      # Skip configure which just sets env vars we don't end up using.
      dontConfigure = true;
      # Skip running scripts and attempts to patch new files.
      dontBuild = true;
      meta = {
        mainProgram      = "pacote";
        description      = "JavaScript package downloader";
        homepage         = "https://github.com/npm/pacote#readme";
        licenses         = [lib.licenses.isc];
        outputsToInstall = ["global"];
      };
    } );
    inherit (self.prepared) outPath global meta;
    bin = self.global;
    # TODO: move `pkgTree' creation here.
    nmDirCmds = let
      mkTrees = { mkNmDir ? mkNmDirCopyCmd, flocoPackages ? null, tree }: {
        prod = mkNmDir {
          tree         = pkgTree;
          assumeHasBin = false;
          handleBindir = false;
          inherit ifd pure allowedPaths typecheck system;
        };
      };
    in lib.makeOverridable mkTrees { tree = pkgTree; };
    passthru = pacoteEnt.passthru // { inherit pkgSet; };
  } )
