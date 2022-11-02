{ lib
, ident
, version
, src
, evalScripts
, flocoPackages
, keysTree ? lib.importJSON ./tree.json
}: evalScripts {
  name = "${baseNameOf ident}-${version}";
  inherit version;
  inherit src;
  nmDirCmd = let
    addMod = to: from: "pjsAddMod ${flocoPackages.${from}} ${to};";
    lines  = builtins.attrValues ( builtins.mapAttrs addMod keysTree );
  in "\n" + ( builtins.concatStringsSep "\n" lines ) + "\n";
  runScripts    = [];
  globalInstall = true;
  postUnpack    = ":";
  dontBuild     = true;
  dontConfigure = true;
  installPhase  = lib.withHooks "install" ''
    pjsAddMod . "$out";
  '';
}

