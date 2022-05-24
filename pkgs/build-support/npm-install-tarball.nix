# FIXME: This needs to be implemented.

# Given a Node.js package tarball, install it to a prefix using global style.

{ system, gnutar, coreutils, bash
, lib
, libstr     ? import ../../lib/strings.nix { inherit lib; }
, libpkginfo ? import ../../lib/pkginfo.nix { inherit lib libstr; }

, tarball
# We can technically scrape this information from the `package.json', but
# it creates an intermediate derivation which likely isn't necessary because
# the caller probably knows this info already.
, pname
, scope    ? null
, version
, unpacked ? import ./npm-unpack-source-tarball.nix {
    inherit system gnutar coreutils bash tarball lib libstr libpkginfo;
    inherit pname scope version;
  }
}:
assert pname   == unpacked.pname;
assert version == unpacked.version;
assert tarball == unpacked.tarball;
let
  spre  = if unpacked.scope == null then "" else unpacked.scope + "-";
  pkgInfo = libpkginfo.readPkgInfo "${unpacked}/package.json";
  moduleSubdir = "lib/node_modules/${unpacked.scopeDir}${pname}";

  buildScript = builtins.toFile "builder.sh" ''
    ${coreutils}/bin/mkdir -p $out/${moduleSubdir}
  '';

  npmInstallTarball' =
    assert pname             == pkgInfo.pname;
    assert version           == pkgInfo.version;
    assert unpacked.scope    == pkgInfo.scope;
    assert unpacked.scopeDir == pkgInfo.scopeDir;

    derivation {
      name = "${spre}${pname}-${version}-global";
      inherit (unpacked) scope scopeDir moduleSubdir pname version tarball;
      inherit unpacked;
      builder = "${bash}/bin/bash";
      args = ["-e" buildScript];
    };
in npmInstallTarball'
