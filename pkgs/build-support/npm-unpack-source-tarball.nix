# Unzips a Node.js tarball without botching the SHA expected by
# `yarn' and `yarn'.
#
# Adds some additional derivation metadata referenced by consuming derivations;
# the intention here is to avoid phony inputs between sibling derivations
# cause by string contexts.
# The tarball should be a checkpoint that kills any past contexts, and roots a
# new generation.

{ system, gnutar, coreutils, bash
, lib
, libstr     ? import ../../lib/strings.nix { inherit lib; }
, libpkginfo ? import ../../lib/pkginfo.nix { inherit lib libstr; }

, tarball
# We can technically scrape this information from the `package.json', but
# it creates an intermediate derivation which likely isn't necessary because
# the caller probably knows this info already.
, pname
, scope   ? null
, version
}:
let
  scrubStr = builtins.unsafeDiscarStringContext;
  # XXX: These shadow the arguments above, overriding them.
  pname   = scrubStr pname;
  version = scrubStr version;

  sinfo = libpkginfo.normalizePkgScope ( scrubStr scope );
  spre  = if sinfo.scope == null then "" else sinfo.scope + "-";

  tarFlags = [
    "--warning=no-unknown-keyword"
    "--delay-directory-restore"
    "--no-same-owner"
    "--no-same-permissions"
  ];
  buildScript = builtins.toFile "builder.sh" ''
    ${gnutar}/bin/tar ${toString tarFlags} -xf ${tarball}
    ${coreutils}/bin/mv ./package.out $out
  '';

  unpackNodeSource' = derivation {
    name = "${spre}${pname}-${version}-source";
    inherit tarball pname version system;
    inherit (sinfo) scope scopeDir;
    builder = "${bash}/bin/bash";
    args = ["-e" buildScript];
  };
in unpackNodeSource'
