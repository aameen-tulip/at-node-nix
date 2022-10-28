{ lib

, flocoFileFetcher ? {
    url       ? fetchInfo.resolved
  , resolved  ? null
  , hash      ? integrity
  , integrity ? fetchInfo.shasum
  , shasum    ? null
  , ...
  } @ fetchInfo:
  lib.libfetch.fetchurlDrvW {
    inherit url hash;
    unpack = false;
    allowSubstitutes = ( system != ( builtins.currentSystem or null ) );
    preferLocalBuild = true;
  }

, flocoUnpack ? { outPath, ... } @ fetched:
  if fetched.unpack or true then fetched else unpackSafe {
    source           = outPath;
    passthru.tarball = fetched;
    allowSubstitutes = ( system != ( builtins.currentSystem or null ) );
    preferLocalBuild = true;
  }

, metaSet    ? lib.metaSetFromSerial ( import ./meta.nix )
, pacote-src ? flocoFileFetcher metaSet.${metaSet.__meta.rootKey}.sourceInfo
, mkNmDir    ? mkNmDirLinkCmd

, system
, evalScripts
, mkNmDirLinkCmd
, unpackSafe
, ...
} @ args: let

  tree    = args.tree or metaSet.__meta.trees.prod;
  version = args.version or metaSet.${metaSet.__meta.rootKey}.version;

  prepPkg = {
    fetchInfo   ? ent.sourceInfo
  , sourceInfo  ? null  # TODO: deprecate
  , ...
  } @ ent: let
    meta = ent.__serial or ent;  # Needed by `mkNmDirCmd'
    src = let
      fetched = flocoFileFetcher fetchInfo;
      args    = fetched // { inherit meta; setBinPerms = ent.hasBin; };
      preferLocalBuild = true;
    in flocoUnpack args;
  in assert ! ( ent.hasInstallScript or false );
  src;

  pkgSet = builtins.mapAttrs ( _: prepPkg ) ( metaSet.__entries or metaSet );

  pkgTree = let
    treeDone = builtins.all ( x: x ? outPath ) ( builtins.attrValues tree );
    fallback = builtins.mapAttrs ( nmPath: key: pkgSet.${key} ) tree;
  in if treeDone then tree else fallback;

in evalScripts {
  name = "pacote-${version}";
  inherit version;
  src = pacote-src;
  globalInstall = true;
  # Passing a string suppresses auto-installation.
  nmDirCmd = ( mkNmDir {
    tree         = pkgTree;
    assumeHasBin = false;
    handleBindir = false;
  } ).cmd;
  runScripts = [];
  dontConfigure = true;
  dontBuild     = true;
}
