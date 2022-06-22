# Unzips a Node.js tarball without botching the SHA expected by
# `yarn' and `yarn'.
#
{ system
, gnutar
, gzip
, coreutils
, bash
, tarball
/* Optional */
, outputHashAlgo ? null
, outputHashMode ? null
, outputHash     ? null
}:
let
  tarFlags = [
    "--warning=no-unknown-keyword"
    "--delay-directory-restore"
    "--no-same-owner"
    "--no-same-permissions"
  ];

  tname = ( tarball.name or tarball.drvAttrs.name or "node-package" );

  outputAttrs =
    let
      inherit (builtins) any all;
      values = [outputHashAlgo outputHashMode outputHash];
      nn = x: x != null;
      set = { inherit outputHashAlgo outputHashMode outputHash; };
    in assert ( any nn values ) -> ( all nn values );
      if ( outputHash != null ) then set else {};

  unpackNodeSource = derivation ( {

    name = with builtins;
      let
        m = match "(.*)\\.tgz" tname;
        base = if m == null then ( parseDrvName tname ).name else head m;
        uname = base + "-dist";
      in trace "tname: ${tname}" uname;

    inherit tarball system;
    PATH = "${gzip}/bin";
    builder = "${bash}/bin/bash";
    buildPhase = ''
      ${gnutar}/bin/tar ${toString tarFlags} -xf ${tarball}
      ${coreutils}/bin/mv ./package $out
    '';
    passAsFile = ["buildPhase"];
    args = ["-c" ". $buildPhasePath"];
  } // outputAttrs );

in unpackNodeSource
