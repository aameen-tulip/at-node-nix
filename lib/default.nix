{ nixpkgs-lib ? ( builtins.getFlake "github:NixOS/nixpkgs?dir=lib" ).lib }:
let
  lib = nixpkgs-lib.extend ( final: prev:
    let callLibs = file: import file { lib = final; };
    in {
      libparse   = callLibs ./parse.nix;
      librange   = callLibs ./ranges.nix;
      libpkginfo = callLibs ./pkginfo.nix;
      libstr     = callLibs ./strings.nix;
      libattrs   = callLibs ./attrsets.nix;
      libplock   = callLibs ./pkg-lock.nix;
      libreg     = callLibs ./registry.nix;

      inherit (final.libparse)
        tryParseIdent parseIdent tryParseDescriptor parseDescriptor
        tryParseLocator parseLocator nameInfo isGitRev;

      inherit (final.libpkginfo) importJSON';

      inherit (final.libstr) lines readLines test charN trim;

      inherit (final.libattrs) pkgsAsAttrsets;

      inherit (final.libplock)
        partitionResolved toposortDeps resolvedFetchersFromLock;

      inherit (final.libreg)
        importFetchPackument getFetchurlTarballArgs packumenter
        packumentClosure;
    } );
in lib
