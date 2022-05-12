{ pkgs           ? import <nixpkgs> {}
, stdenv         ? pkgs.stdenvNoCC
, yarn           ? pkgs.yarn
, jq             ? pkgs.jq
, runCommandNoCC ? pkgs.runCommandNoCC
, nix-gitignore  ? pkgs.nix-gitignore
}:
let

# ---------------------------------------------------------------------------- #

# writeYarnWorkspacesList ::= DIR -> JSON File
# -----------------------
# Produce a JSON list of Yarn workspaces named in `DIR/package.json'.

writeYarnWorkspacesList = src: stdenv.mkDerivation {
  pname = "workspaces-json";
  version = "0.0.1";
  src = nix-gitignore.gitignoreSourcePure [
    ".yarn/cache/"
    "node_modules/"
    "*.swp"
    "*~"
  ] src;
  nativeBuildInputs = [yarn jq];
  #dontPatch     = true;
  dontConfigure = true;
  dontCheck     = true;
  dontInstall   = true;
  #dontFixup     = true;
  buildPhase = ''
    export HOME="$TMP/yarn-home"
    mkdir -p "$HOME"
    yarn workspaces list --json|jq -sc 'del( .[0] )' > "$out"
  '';
  preferLocalBuild = true;
  allowSubstitutes = false;
};


# ---------------------------------------------------------------------------- #

in {

  inherit writeYarnWorkspacesList;

  readYarnWorkspaces = src:
    builtins.fromJSON ( builtins.readFile ( writeYarnWorkspacesList src ) );


# ---------------------------------------------------------------------------- #
}

