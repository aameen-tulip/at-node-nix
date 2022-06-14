{ pkgs   ? import <nixpkgs> { inherit system; }
, system ? builtins.currentSystem
, nodejs ? pkgs."nodejs-14_x"
, src    ? pkgs.fetchgit {
             url    = "https://github.com/npm/pacote.git";
             rev    = "8f94b28f3c21bc6a59c4537a4ee9fdb93385dc78";
             sha256 = "sha256-97nFOX7qGmxtbvht+yrq6K7qcL7ooLLGF5ga5zJAwpw=";
           }
}:
let
  nodeEnv = import ./node-env.nix {
    inherit (pkgs) stdenv lib python2 runCommand writeTextFile writeShellScript;
    inherit pkgs nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };
in import ./node-packages.nix {
  inherit (pkgs) fetchurl nix-gitignore stdenv lib fetchgit;
  inherit nodeEnv src;
}
