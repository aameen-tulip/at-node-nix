# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib
, stdenv
, ...
} @ globalArgs: let

# ---------------------------------------------------------------------------- #

  mkFlocoShell = {
  # Name of `app' targets withouth "-nm-install" suffixes
    installerBasenames ?
      if ! ( args ? flake ) then throw "You must provide installer basenames"
      else map ( n: lib.yank "(.*)-nm-install" )
               ( builtins.attrNames flake.apps.${system} )
  # Flake to invoke installers from
  , flakeRef ? if ( args ? flake ) then "path://${flake.outPath}" else "."
  , stdenv
  # Core packages which must always be made available
  , initialPath       ? stdenv.initialPath
  , buildInputs       ? stdenv.defaultBuildInputs
  , nativeBuildInputs ? stdenv.defaultNativeBuildInputs
  , dontFixup         ? true
  , preShellHook      ? ""
  , postShellHook     ? ""
  , helpExtra         ? ""
  , nodeEnableNpm     ? ! withLatestNpm
  , withLatestNpm     ? true   # Uses latest from `nodejs.pkgs.npm'
  , nodejs            ? globalArgs.nodejs
  , latestNpmPkg      ? nodejs.pkgs.npm
  , node-gyp          ? nodejs.pkgs.node-gyp
  , node-gyp-build    ? nodejs.pkgs.node-gyp-build
  , python            ? nodejs.python
  , lndir             ? globalArgs.lndir
  , pkg-config        ? globalArgs.pkg-config
  , jq                ? globalArgs.jq
  , nix               ? globalArgs.nix
  , ...
  } @ args:
    assert ( args ? pkgSet ) || ( args ? nmDirScripts );
    assert withLatestNpm -> ! nodeEnableNpm; let

    nodejsCli = if nodeEnableNpm then nodejs else
                nodejs.override { enableNpm = nodeEnableNpm; };

    nativeBuildInputs = initialPath ++ nativeBuildInputs ++ [
      nix
      lndir
      python
      pkg-config
      jq
      nodejsCli
    ] ++ ( lib.optional ( withNpm && ( ! nodeEnableNpm ) ) latestNpmPkg );

  in stdenv.mkDerivation {
      name = "floco-install-shell";
      unpackPhase   = ":";   # Skip
      dontPatch     = true;
      dontConfigure = true;
      dontBuild     = true;
      dontInstall   = true;
      dontFixup     = true;
      BNAMES        = builtins.concatStripsSep " " installerBasenames;
      FLAKE         = flakeRef;
      shellHook = ''
        ${preShellHook}
        export MANPATH="$out/share/man:$MANPATH";
        # Fix bash completion
        XDG_DATA_DIRS+="$out/share";
        floco-install() {
          local subdir pargs;
          case " $* " in
            *\ -h\ *|*\ --help\ *) {
            echo "Installs 'node_modules/' used by Nix for build/tests.";
            echo "USAGE: floco-install [BNAME] [-- [NM-DIR]] [OPTS...]";
            echo "";
            echo "  ex: 'npm install' equivalent for working directory";
            echo "      floco-install --copy";
            echo "  ex: symlink runtime deps of 'bar' into './foo/bar/' instead of './node_modules/' using 'bar-nm-install'";
            echo "      floco-install bar ./foo/bar --prod";
            echo "";
            echo "OPTIONS";
            echo "  -l,--link     symlink files from Nix Store  (default)";
            echo "  -c,--copy     copy files from Nix Store";
            echo "  -d,--dev      include dev dependencies      (default)";
            echo "  -p,--prod     exclude dev dependencies";
            echo "  -L,--list     list available installers";
            echo "";
            echo "ARGUMENTS";
            echo "  --            separates wrapper args from '*-nm-install' flags";
            echo "  BNAME         the package installer basename ( the flake target \"(.*)-nm-install\" ) to use";
            echo "                defaults to the basename of current working directory. *** read that again ***";
            echo "  NM-DIR        path to treat as 'node_modules/', as: '<NM-DIR>/@foo/bar'.";
            echo "";
            echo "This is just a wrapper over '<BNAME>-nm-install' scripts exposed by this flake.";
            echo "The wrapper is for interactive development, not scripts or CI.";
            ${helpExtra}
           } >&2;
           return 0;
           ;;
           *\ -L\ *|*\ --list\ *) printf '%s\n' $BNAMES >&2; return 0; ;;
          esac

          while test "$#" -gt 0; do
            case "$1" in
              --) shift; break; ;;
              -*) pargs="''${pargs:+$pargs }$1"; ;;
              .) bname="''${PWD##*/}"; shift; break;;
              *) case " ${BNAMES} " in
                   *\ ''${1##*/}\ *) bname="''${1##*/}"; shift; break;;
                   *)                pargs="''${pargs:+$pargs }$1"; ;;
                 esac
              ;;
            esac
            shift;
          done
          : "''${bname:=''${PWD##*/}}";
          case " $BNAMES " in
            *\ $bname\ *) :; ;;
            *) echo "Installer for '$bname' not found. Try:" >&2;
               printf "  %s\n" $BNAMES >&2;
               return 1;
            ;;
          esac
          echo "Running:  nix run $FLAKE#''${bname}-nm-install -- $pargs $*" >&2;
          nix run "$FLAKE#''${bname}-nm-install" -- $pargs "$@";
        }
        ${postShellHook}
      '';
    };


# ---------------------------------------------------------------------------- #

in {
  inherit
    mkFlocoInstall
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
