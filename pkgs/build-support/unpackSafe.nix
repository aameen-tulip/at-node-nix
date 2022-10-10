# `unpackSafe { tarball, name ? ,  meta ? }'
#
# Note: this is really meant for unpacking tarballs in pure mode.
# It doesn't patch or set bin bin permissions.
#
# All it does differently that regular `tar' is create directories before
# unpacking to prevent them from being clobbered.
#
{ name        ? meta.name.src or throw "Let untarSanPerms set the name"
, tarball     ? args.outPath or args.src
, meta        ? {}
, setBinPerms ? true
#, patchShebangs ? false  # FIXME
, untarSanPerms
, jq
, system
, allowSubstitutes ? ( builtins.currentSystem or null ) != system
, ...
} @ args: let
  addBinPerms =
    if ! ( ( args.meta.hasBin or true ) || setBinPerms ) then {} else {
      postTar = ''
        PATH="$PATH:${jq}/bin";
        for f in $( jq -r '( .bin // {} )[]' "$out/package.json"; ); do
          test -z "$f" && break;
          chmod -R +rw "$out/''${f%/*}";
          chmod +wxr "$out/$f";
        done
        for d in $( jq -r '.directories.bin // ""' "$out/package.json"; ); do
          test -z "$f" && break;
          chmod -R +wrx "$out/$d"
        done
      '';
    };
in untarSanPerms ( {
  inherit tarball;
  tarFlags = [
    "--no-same-owner"
    "--no-same-permissions"
    "--delay-directory-restore"
    "--no-overwrite-dir"
  ];
  extraDrvAttrs.allowSubstitutes = allowSubstitutes;
  extraAttrs.meta = args.meta or {};
} // ( if (
  ( args.name or args.meta.names.tarball or null ) != null
) then { name = args.name or args.meta.names.tarball; } else {} ) //
  addBinPerms )
