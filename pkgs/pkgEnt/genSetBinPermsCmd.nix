# ============================================================================ #
#
# Generates a snippet used to set executable permissions for a package's bins.
# Optionally this can patch shebangs.
#
# As a hook this allows you to drop this into basically any builder.
# For "simple" tarballs you may have to run this as a prepare routine; but
# for most other packages just tack it on as a `postInstall' hook.
#
#
# ---------------------------------------------------------------------------- #

{ lib, patch-shebangs }: let

  genSetBinPermissionsHook = {
    meta
  , relDir                 ? "$out"
  , dontPatchShebangs      ? false
  , usePatchShebangsScript ? false
  , patch-shebangs
  }: let
    PATCH_SHEBANGS = if usePathShebangsScript
                     then "${patch-shebangs}/bin/patch-shebangs"
                     else "patchShebangs";
    from = let m = builtins.match "(.*)/" relDir; in
            if m == null then relDir else m;
    binPaths = map ( p: "${from}/${p}" ) ( builtins.attrValues meta.bin );
    targets =
      if meta.bin ? __DIR__ then "${from}/${meta.bin.__DIR__}/*" else
      builtins.concatStringsSep " " binPaths;
  in "chmod +x ${targets}\n" + ( lib.optionalString ( ! dontPatchShebangs ) ''
     ${PATCH_SHEBANGS} -- ${targets}
  '' );

in lib.callPackageWith { inherit patch-shebangs; } genSetBinPermissionsHook


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
