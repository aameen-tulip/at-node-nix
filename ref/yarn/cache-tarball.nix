{ yarnHash  ? import ../../../lib/yarn/hash.nix
, yarnParse ? import ../../../lib/yarn/parse.nix
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
    , tarball
    , checksum
    , system
    , gnutar
    , gzip
    , coreutils
    , findutils
    , bash
    , zip
    , unpackNodeSource
  }:
    let
      unpacked = unpackNodeSource {
        inherit system gnutar gzip coreutils bash tarball;
      };

      inherit (yarnHash) yarnCacheTarballName;
      name = yarnCacheTarballName { inherit scope pname reference checksum; };
    in derivation {
      inherit name system tarball scope pname ident reference checksum;
      builder = "${bash}/bin/bash";
      PATH = "${coreutils}/bin:${zip}/bin:${findutils}/bin";

      # The fucking Zip from Yarn is sorted in what appears to be
      # ABSOLUTELY RANDOM ORDER!
      # I am completely convinced at this point that that project is
      # a complete clown show.
      #
      # WHO THE ACTUAL FUCK USES ZIP FILES WHEN YOU KNOW YOU HAVE TO
      # GENERATE CHECKSUMS?!
      # WHO THE FUCK FORGOTS TO SORT THEIR FUCKING CONTENTS!?
      # WHO THE FUCK INCLUDES DIRECTORIES IN THIER ARCHIVES?!
      #
      # Empty directories get perms of 0111.
      # Directories with files get 0755.
      #
      # XXX:
      # The file ordering exactly matches the registry tarball's file order.
      # It's still idiotic, but at least it's not random.
      buildPhase = ''
        mkdir -p node_modules/${dirOf ident}
        cp -pr --reflink=auto -- ${unpacked} node_modules/${ident}

        find node_modules -exec chmod u+w {} \;
        find node_modules -perm /0111 -exec chmod a+x {} \;
        find node_modules -exec touch -cam -t 198406222150.00 {} \;

        find node_modules -print|zip -b archive.zip -oX - -@ > $out
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
