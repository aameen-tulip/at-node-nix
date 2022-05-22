{ pkgs      ? import <nixpkgs> {}
, lib       ? pkgs.lib
, libplock  ? import ../../../../../at-node-nix/lib/pkg-lock.nix {
                inherit lib;
              }
, stdenv    ? pkgs.stdenvNoCC
, fetchurl  ? pkgs.fetchurl
, nodejs    ? pkgs.nodejs-14_x
, writeText ? pkgs.writeTextFile
}:
let
  plock       = builtins.fromJSON ( builtins.readFile ./package-lock.json );
  sortedDeps  = libplock.toposortDeps plock;
  drvFetchers = libplock.deriveFetchersForResolvedLockEntries fetchurl plock;

  npmEnv = stdenv.mkDerivation {
    name = "npmEnv";
    phases = ["installPhase"];
    npmConfigContents = ''
      prefix           = "''${npm_prefix}"
      tmp              = "''${TMP}"
      globalconfig     = "@out@/etc/npmrc"
      globalignorefile = "@out@/etc/npmignore"
      userconfig       = "@out@/local/etc/npmrc"
      cache            = "''${npm_prefix}/var/npm/cache"
      init-module      = "''${npm_prefix}/var/npm/npm-init.js"
      offline          = true
      color            = false
      progress         = false
      registry         = null
      metrics-registry = null
      shell            = "${stdenv.shell}"
    '';
    setupHookContents = ''
      setupNpmEnv() {
        : "''${CI=1}"
        : "''${NPM_CONFIG_GLOBALCONFIG:=@out@/etc/npmrc}"
        : "''${npm_prefix:=''${NIX_BUILD_TOP:-''${prefix:-$TMP}}}"
        export CI NPM_CONFIG_GLOBALCONFIG npm_prefix
      }

      initNpmCache() {
        setupNpmEnv
        mkdir -p "$npm_prefix/var/npm/cache"
      }
      preUnpackHooks+=( initNpmCache )
    '';
    passAsFile = ["npmConfigContents" "setupHookContents"];
    installPhase = ''
      runHook preInstall

      mkdir -p "$out/etc" "$out/local/etc" "$out/nix-support"

      substitute "$npmConfigContentsPath" "$out/etc/npmrc" --subst-var out
      substitute "$setupHookContentsPath" "$out/nix-support/setup-hook"  \
                 --subst-var out
      touch "$out/etc/npmignore" "$out/local/etc/npmrc"

      runHook postInstall
    '';
  };

  npmCache = stdenv.mkDerivation {
    name = "npmCache";
    nativeBuildInputs = [nodejs];
    propagatedBuildInputs = [npmEnv];
    phases = ["installPhase"];
    setupHookContents = ''
      cloneNpmCache() {
        if test "$#" -gt 0; then
          local targetDir="$1"
          shift
        else
          local targetDir="''${npm_prefix:-$out}/var/npm/cache"
        fi
        mkdir -p "''${targetDir%/*}"
        if test -d "$targetDir"; then
          echo "WARNING: Replacing existing NPM cache with new clone"
          rm -rf "$targetDir";
        fi
        cp -pr --reflink=auto -- "@out@" "$targetDir"
        chmod -R +w "$targetDir"
        setupNpmEnv
      }
      if test "''${cloneNpmCache-0}" != 0; then
        preUnpackHooks=( cloneNpmCache "''${preUnpackHooks[@]}" )
      fi
    '';
    passAsFile = ["setupHookContents"];
    installPhase =
      let
        inherit (builtins) attrValues concatStringsSep;
        npmCmds = map ( tb: "npm cache add ${tb}" ) ( attrValues drvFetchers );
      in ''
        export npm_prefix="$out"
        initNpmCache
        runHook preInstall

        echo "Adding Node.js tarballs to NPM cache."

        ${concatStringsSep "\n" npmCmds}

        echo "Done adding Node.js tarballs to NPM cache."

        mkdir -p "$out/nix-support"
        substitute "$setupHookContentsPath" "$out/nix-support/setup-hook"  \
                  --subst-var out

        runHook postInstall
      '';
  };

  npmLinkedEnv = linkedInputs: stdenv.mkDerivation {
    name = "npmLinkedEnv";
    nativeBuildInputs = [npmCache nodejs];
    propagatedNativeBuildInputs = [npmEnv];
    phases = ["installPhase"];
    inherit (npmCache) setupHookContents;
    passAsFile = ["setupHookContents"];
    installPhase =
      let
        inherit (builtins) attrValues concatStringsSep;
        npmCmds = map ( tb: "( cd ${tb} && npm link )" ) linkedInputs;
      in ''
        export npm_prefix="$out"
        cloneNpmCache
        
        runHook preInstall

        echo "Linking local Node.js modules to global NPM prefix."

        ${concatStringsSep "\n" npmCmds}

        echo "Done linking local Node.js modules to global NPM prefix."

        mkdir -p "$out/nix-support"
        substitute "$setupHookContentsPath" "$out/nix-support/setup-hook"  \
                  --subst-var out

        runHook postInstall
      '';
  };
in {
  inherit npmCache;
  linkTestUtil = npmLinkedEnv [../test-utils];
}
