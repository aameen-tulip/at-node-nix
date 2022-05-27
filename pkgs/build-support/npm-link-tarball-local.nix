# Given a Node.js package tarball, link it to a prefix using local style.
#
# This form does NOT vendor dependencies, or attempt to "build".
#
# This is a naive form of `npm link' or `yarn link', which may be used later
# with `linkFarm*' to create a `node_modules/' tree.

{ system, gnutar, coreutils, bash
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
}:
assert pname   == global.pname;
assert version == global.version;
assert tarball == global.tarball;
let
  spre  = if global.scope == null then "" else global.scope + "-";

  buildScript = builtins.toFile "builder.sh" ''
    ${coreutils}/bin/mkdir -p $out/node_modules/${global.scopeDir}
    ${coreutils}/bin/ln -s -- ${global}/bin $out/node_modules/.bin
    ${coreutils}/bin/ln -s --                           \
      ${global}/lib/modules/${global.scopeDir}${pname}  \
      $out/node_modules/${global.scopeDir}${pname}
  '';

  npmLinkTarballLocal' =
    derivation {
      name = "${spre}${pname}-${version}-local-no-vendor";
      inherit (global) scope scopeDir moduleSubdir pname version tarball;
      inherit (global) unpacked pkgInfo;
      inherit global;
      builder = "${bash}/bin/bash";
      args = ["-e" buildScript];
    };
in npmLinkTarballLocal'
