{ nixpkgs   ? builtins.getFlake "nixpkgs"
, system    ? builtins.currentSystem
, pkgs      ? nixpkgs.legacyPackages.${system}
, lib       ? pkgs.lib
, stdenv    ? pkgs.stdenvNoCC
, fetchurl  ? pkgs.fetchurl
, nodejs    ? pkgs.nodejs-14_x
}:
let

/* -------------------------------------------------------------------------- */

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
      link             = true
      @tulip:registry  = "https://tulip-855647127938.d.codeartifact.us-east-1.amazonaws.com/npm/tulip-npm/"
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


/* -------------------------------------------------------------------------- */

  npmCache = tarballs: stdenv.mkDerivation {
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
        export NPM_CONFIG_CACHE="$targetDir"
        setupNpmEnv
      }

      # You MUST clone the cache for any operation that may modify
      # `node_modules/' directories.
      # So basically "only disable the cache if for operating on the cache
      # without NPM".
      if test "''${dontCloneNpmCache-0}" != 0; then
        preUnpackHooks=( cloneNpmCache "''${preUnpackHooks[@]}" )
      else
        export NPM_CONFIG_CACHE="@out@/var/npm/cache"
      fi
    '';
    passAsFile = ["setupHookContents"];
    installPhase =
      let npmCmds = map ( tb: "npm cache add ${tb}" ) tarballs;
      in ''
        export npm_prefix="$out"
        initNpmCache
        runHook preInstall

        echo "Adding Node.js tarballs to NPM cache."

        ${builtins.concatStringsSep "\n" npmCmds}

        echo "Done adding Node.js tarballs to NPM cache."

        mkdir -p "$out/nix-support"
        substitute "$setupHookContentsPath" "$out/nix-support/setup-hook"  \
                  --subst-var out

        runHook postInstall
      '';
  };


/* -------------------------------------------------------------------------- */

  # This "works", but if you have `package-lock.json' files laying around
  # you'll still crash because `npm CMD --offline' demands that you have cache
  # entries for everything.
  npmLinkedEnv = npmTarballCache: linkedInputs: stdenv.mkDerivation {
    name = "npmLinkedEnv";
    nativeBuildInputs = [npmTarballCache nodejs];
    propagatedNativeBuildInputs = [npmEnv];
    phases = ["installPhase"];
    inherit (npmTarballCache) setupHookContents;
    passAsFile = ["setupHookContents"];
    installPhase =
      let npmCmds = map ( tb: "( cd ${tb} && npm link )" ) linkedInputs;
      in ''
        export npm_prefix="$out"
        cloneNpmCache

        runHook preInstall

        echo "Linking local Node.js modules to global NPM prefix."

        ${builtins.concatStringsSep "\n" npmCmds}

        echo "Done linking local Node.js modules to global NPM prefix."

        mkdir -p "$out/nix-support"
        substitute "$setupHookContentsPath" "$out/nix-support/setup-hook"  \
                  --subst-var out

        runHook postInstall
      '';
  };


/* -------------------------------------------------------------------------- */

in {
  inherit npmEnv npmCache npmLinkedEnv;
}
