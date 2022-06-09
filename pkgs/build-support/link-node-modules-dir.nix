{ pkgs ? ( builtins.getFlake "nixpkgs" ).legacyPackages.${builtins.currentSystem}
, lndir          ? pkgs.xorg.lndir
, runCommandNoCC ? pkgs.runCommandNoCC
}:
let
  linkedModules = { modules ? [] }: runCommandNoCC "node_modules" {
      inherit modules;
      preferLocalBuild = true;
      allowSubstitutes = false;
  } ( "mkdir -p $out\n" + (  builtins.concatStringsSep "\n" ( map ( m:
    "${lndir}/bin/lndir -silent -ignorelinks ${m} $out" ) modules ) ) );
in linkedModules
