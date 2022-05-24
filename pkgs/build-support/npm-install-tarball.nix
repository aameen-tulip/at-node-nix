# Given a Node.js package tarball, install it to a prefix using global style.
# This form does NOT vendor dependencies, or attempt to "build".
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
, unpacked   ? import ./npm-unpack-source-tarball.nix {
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

  symlinkPackage = ''
    ${coreutils}/bin/mkdir -p $out/${moduleSubdir}
    ${coreutils}/bin/ln -s -- ${unpacked} $out/${moduleSubdir}
  '';

  # XXX: These have NOT been patched yet!
  # These are just symlinks to the `node_modules/' scripts, which are just
  # symlinks to the unpacked tarball.
  # None of these files are writeable.
  link1Bin = name: script:
    "${coreutils}/bin/ln -sr -- $out/${moduleSubdir}/${script} " +
                               "$out/bin/${name}";

  linkBins = if ( ! ( pkgInfo ? bin ) ) then "" else
    let linkCmds = lib.mapAttrsToList link1Bin pkgInfo.bin;
    in "${coreutils}/bin/mkdir -p -- $out/bin\n" +
       ( builtins.concatStringsSep "\n" linkCmds );

  buildScript = builtins.toFile "builder.sh" ( symlinkPackage + linkBins );

in assert pname             == pkgInfo.pname;
   assert version           == pkgInfo.version;
   assert unpacked.scope    == pkgInfo.scope;
   assert unpacked.scopeDir == pkgInfo.scopeDir;

   derivation {
     name = "${spre}${pname}-${version}-global-no-vendor";
     inherit (unpacked) scope scopeDir moduleSubdir pname version tarball;
     inherit unpacked;
     builder = "${bash}/bin/bash";
     args = ["-e" buildScript];
   }
