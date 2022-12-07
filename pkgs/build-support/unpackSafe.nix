
# `unpackSafe { tarball, name?,  metaEnt? }'
#
# Note: this is really meant for unpacking tarballs in pure mode.
# It doesn't patch or set bin bin permissions.
#
# All it does differently that regular `tar' is create directories before
# unpacking to prevent them from being clobbered.
#
# XXX: DO NOT PATCH SHEBANGS
# XXX: DO NOT PATCH SHEBANGS
# XXX: DO NOT PATCH SHEBANGS
# XXX: `mkTarballFromLocal' and similar routines used to "un-Nixify" builds
# rely on a `source' that is unpatched.
# Patching is performed when modules are installed globally or into a
# `node_modules/' directory anyway so don't worry about it here.

{ name          ? metaEnt.names.src or null
, tarball       ? args.outPath or args.src
, metaEnt       ? args.passthru.metaEnt or {}
, setBinPerms   ? metaEnt.hasBin or true
, untarSanPerms
, jq
, system
, allowSubstitutes ? ( builtins.currentSystem or null ) != system
# Fallbacks/Optionals
, src      ? null
, passthru ? {}
, ...
} @ args: let
  addBinPerms' = if ! setBinPerms then {} else {
    postTar = ''
      for f in $( $JQ -r '
        if .bin == null then "" else (
          if ( .bin|type ) == "string" then .bin else .bin[] end
        ) end
      ' "$out/package.json"; ); do
        if [[ -n "$f" ]]; then
          chmod -R +rw "$out/''${f%/*}";
          chmod +wxr "$out/$f";
        else
          d="$( $JQ -r '.directories.bin // ""' "$out/package.json"; )";
          if [[ -n "$d" ]]; then
            chmod -R +wrx "$out/$d";
          fi
        fi
      done
    '';
  };
  name' = if name == null then {} else { inherit name; };
in untarSanPerms ( {
  inherit tarball;
  tarFlags = [
    "--no-same-owner"
    "--no-same-permissions"
    "--delay-directory-restore"
    "--no-overwrite-dir"
  ];
  extraDrvAttrs = let
    jq' = if setBinPerms then { JQ = "${jq}/bin/jq"; } else {};
  in { allowSubstitutes = allowSubstitutes; } // jq';
  extraAttrs.meta     = args.meta or {};
  extraAttrs.passthru = let
    binPermsSet' = if ! setBinPerms then {} else { binPermsSet = true; };
  in ( args.passthru or {} ) // binPermsSet';
} // addBinPerms' )
