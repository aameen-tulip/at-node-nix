{ pkgs           ? import ../.. {}
, runCommandNoCC ? pkgs.runCommandNoCC
, untar          ? pkgs.untar
}: let

  inherit (pkgs)
    packNodeTarballAsIs
    unpackNodeTarball
    linkAsNodeModule'
    linkAsNodeModule
    linkBins
    linkAsGlobal
    mkNodeTarball
  ;

  pacote-tree = builtins.fetchTree {
    url = "https://registry.npmjs.org/pacote/-/pacote-13.0.0.tgz";
    type = "tarball";
    narHash = "sha256-pYxkRZueIX49tyFOsixnTb+MB7qmcTSS4ZGNIVCDmOc=";
  };
  pacote-tarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/pacote/-/pacote-13.0.0.tgz";
    hash = "sha256-7Cho+MT2bgj2/65kr8Iok2Go0+yFahtP9LwZd1jzUM0=";
  };

  treeTarball   = packNodeTarballAsIs { src = pacote-tree; };
  treeUnpacked  = unpackNodeTarball { tarball = treeTarball; };
  treeModStrict = linkAsNodeModule' { unpacked = treeUnpacked; };
  treeMod       = linkAsNodeModule { unpacked = treeUnpacked; };
  treeBins      = linkBins { src = treeUnpacked; };

  tbTarball   = pacote-tarball;
  tbUnpacked  = unpackNodeTarball { tarball = pacote-tarball; };
  tbModStrict = linkAsNodeModule' { unpacked = tbUnpacked; };
  tbMod       = linkAsNodeModule { unpacked = tbUnpacked; };
  tbBins      = linkBins { src = tbUnpacked; };

in {
  inherit
    treeTarball
    treeUnpacked
    treeModStrict
    treeMod
    treeBins
    tbTarball
    tbUnpacked
    tbModStrict
    tbMod
    tbBins
  ;
}
