# `unpackSafe { tarball, name ? ,  meta ? }'
#
# Note: this is really meant for unpacking tarballs in pure mode.
# It doesn't patch or set bin bin permissions.
#
# All it does differently that regular `tar' is create directories before
# unpacking to prevent them from being clobbered.
#
{ name    ? throw "Let untarSanPerms set the name"
, tarball ? args.outPath or args.src
, meta    ? {}
#, setBinPerms   ? true   # FIXME
#, patchShebangs ? false  # FIXME
, untarSanPerms
, ...
} @ args: untarSanPerms ( {
  inherit tarball;
  tarFlags = [
    "--no-same-owner"
    "--delay-directory-restore"
    #"--no-same-permissions"
    "--no-overwrite-dir"
  ];
  extraDrvAttrs.allowSubstitutes = false;
  extraAttrs.meta = args.meta or {};
} // ( lib.optionalAttrs (
  ( args.name or args.meta.names.tarball or null ) != null
) { name = args.name or args.meta.names.tarball; } ) )
