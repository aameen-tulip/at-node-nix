# Given a Node.js package tarball, link it to a prefix using global style.
#
# This form does NOT vendor dependencies, or attempt to "build".
#
# This is a naive form of `npm link' or `yarn link', which may be used later
# with `linkFarm*' to create a `node_modules/' tree.

{ system, gnutar, coreutils, bash, lndir
, lib
, libstr     ? import ../../lib/strings.nix { inherit lib; }
, libpkginfo ? import ../../lib/pkginfo.nix { inherit lib libstr; }

, tarball
# We can technically scrape this information from the `package.json', but
# it creates an intermediate derivation which likely isn't necessary because
# the caller probably knows this info already.
, pname
, scope      ? null
, version
, global     ? import ./npm-link-tarball.nix {
    inherit system gnutar coreutils bash tarball lib libstr libpkginfo;
    inherit pname scope version;
  }
, nodePackageLocalsVend ? {}
}:
assert pname   == global.pname;
assert version == global.version;
assert tarball == global.tarball;
let
  inherit (builtins) attrValues mapAttrs concatStringsSep toFile;
  inherit (global) pkgInfo;
  spre  = if global.scope == null then "" else global.scope + "-";
  moduleSubdir = "lib/node_modules/${global.scopeDir}${pname}";

  depDrvs =
    let fetch = n: v:
          let inherit ( libpkginfo.parsePkgJsonNameField n ) pname scope;
          in if scope == null then nodePackageLocalsVend."_".${pname}
                              else nodePackageLocalsVend.${scope}.${pname};
    in attrValues ( mapAttrs fetch ( pkgInfo.dependencies or {} ) );

  buildScript = toFile "builder.sh" ''
    ${coreutils}/bin/mkdir -p $out
    ${lndir}/bin/lndir -silent -ignorelinks ${global} $out
  '' + ( concatStringsSep "\n" ( map ( m:
             "${lndir}/bin/lndir -silent -ignorelinks ${m} $out/${moduleSubdir}"
           ) depDrvs ) );

  npmLinkTarballVendor' =
    derivation {
      name = "${spre}${pname}-${version}-global-vendor";
      inherit (global) scope scopeDir moduleSubdir pname version tarball;
      inherit (global) unpacked pkgInfo;
      inherit global depDrvs;
      builder = "${bash}/bin/bash";
      args = ["-e" buildScript];
    };
in npmLinkTarballVendor'
