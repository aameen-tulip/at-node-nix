{ pkgs           ? import <nixpkgs> {}
, runCommandNoCC ? pkgs.runCommandNoCC
, coreutils      ? pkgs.coreutils
, findutils      ? pkgs.findutils
, gnutar         ? pkgs.gnutar
}:
let
  # This is identical to the checksum of the `.zip' file produced by `nix hash'
  # You should most likely use `builtins.hashFile "sha512" tarball' instead.
  yarnChecksumFromTarball = tarball:
    runCommandNoCC "yarn-checksum" {
      inherit tarball;
      PATH = builtins.concatStringsSep ":"
             ( map ( p: "${p}/bin" ) [coreutils findutils gnutar] );
    } ''
      tar xz --warning=no-unknown-keyword  \
             --delay-directory-restore     \
             --no-same-owner               \
             --no-same-permissions         \
          -f $tarball
      sha512sum <(
        printf '%s' $( find package -type f -print  \
                        |sort                      \
                        |xargs sha512sum -b        \
                        |cut -d' ' -f1
                     )
      )|cut -d' ' -f1 > $out
  '';
in yarnChecksumFromTarball
