{ yarnHash  ? import ./hash.nix
, yarnParse ? import ./parse.nix
}:
let
  tarballForEntry = entry:
    yarnHash.yarnCacheTarballName ( yarnParse.parseLocator entry.resolution );
in {
  inherit tarballForEntry;

  yarnTarballFromNpmTarball = {
      scope     ? builtins.elemAt ( builtins.match "(@([^@/]+]/)).*" ident ) 1
    , pname     ? builtins.elemAt ( builtins.match "(@([^@/]+]/))(.*)" ident ) 2
    , ident     ? ( if ( toString scope ) != "" then "@${scope}/" else "" )
                  + pname
    , reference ? "unknown"
    , checksum
    , tarball
    , stdenv
    , zip
  }:
    let
      inherit (yarnHash) yarnCacheTarballName;
      name = yarnCacheTarballName { inherit scope pname reference checksum; };
      ipath =
        let
          getName = drv: drv.drvAttrs.pname or
                         ( builtins.parseDrvName drv.drvAttrs.name ).name;
          mkAttr = drv: { name = getName drv; value = drv; };
        in builtins.listToAttrs ( map mkAttr stdenv.initialPath );
    in derivation {
      inherit name tarball scope pname ident reference checksum;
      inherit (stdenv) system;
      builder = stdenv.shell;
      tarFlags = [
        "--warning=no-unknown-keyword"
        "--delay-directory-restore"
        "--no-same-owner"
        "--no-same-permissions"
      ];
      PATH = "${ipath.gzip}/bin";
      # Empty directories get perms of 0111.
      # Directories with files get 0755.
      buildPhase = ''
        ${ipath.coreutils}/bin/mkdir -p node_modules/${dirOf ident}
        ${ipath.gnutar}/bin/tar $tarFlags -xf $tarball
        #${ipath.coreutils}/bin/ls -la package/**
        ${ipath.coreutils}/bin/mv package node_modules/${ident}
        #${ipath.findutils}/bin/find node_modules -exec                \
        #  ${ipath.coreutils}/bin/touch -cam -t 198406222150.00 {} \;
        #${ipath.coreutils}/bin/ls -la node_modules/**
        ${zip}/bin/zip -9 -J -r -oX - node_modules > $out
      '';
      passAsFile = ["buildPhase"];
      args = ["-c" ". $buildPhasePath"];
      #outputHashMode = "flat";
      #outputHashAlgo = "sha512";
      #outputHash     = checksum;
      #__contentAddressed = true;
      preferLocalBuild = true;
    };

}
