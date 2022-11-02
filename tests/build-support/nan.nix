{ floco     ? builtins.getFlake ( toString ../.. )
, lib       ? floco.lib
, system    ? builtins.currentSystem
, pkgsFor   ? floco.legacyPackages.${system}
, coerceDrv ? pkgsFor.coerceDrv
, nan-src   ? builtins.fetchTree {
    type = "tarball";
    url  = "https://registry.npmjs.org/nan/-/nan-2.17.0.tgz";
    narHash = "sha256-5r+kH/G43Jk8vchs/zzepgd/5ouh0hIG7lWc6OfxLJ0=";
  }
}: let
  pjs = lib.importJSON "${nan-src}/package.json";
  nan-meta = {
    ident = pjs.name;
    key   = "${pjs.name}/${pjs.version}";
    inherit (pjs) version;
  };
in coerceDrv {
  name = ( lib.libmeta.metaEntNames pjs ).names.src;
  inherit (pjs) version;
  src      = nan-src;
  meta     = nan-meta;
  passthru = { inherit pjs; };
}
