# ============================================================================ #
#
# Produces a globally installed executable output ( `global' ) in addition to
# the regular module output ( `out' )
#
# This is incredibly similar to the `installGlobal' builder and you should
# absolutely read the giant comment at the top of that builder about splitting
# outputs and derivations as an optimization and method of skirting circular
# dependency crashes.
#
# For a simple build that's already fast and doesn't have circular deps this is
# a great pick though.
#
# ---------------------------------------------------------------------------- #

{ lib
, name        ? meta.names.global or "${baseNameOf ident}-${version}"
, ident       ? args.meta.ident or ( dirOf args.key )
, version     ? args.meta.version or ( baseNameOf args.key )
, key         ? args.meta.key or "${ident}/${version}"
, src
, globalNmDirCmd ? args.nmDirCmd or ":"
, meta           ? lib.mkMetaEntCore { inherit ident version; }
, evalScripts
, ...
} @ args: let
  mkDrvArgs = removeAttrs args ["evalScripts"];
in evalScripts ( {
  inherit name ident version src globalNmDirCmd meta;
  runScripts    = [];
  globalInstall = true;
  moduleInstall = false;
  postUnpack    = ":";
  dontBuild     = true;
  dontConfigure = true;
} // args )


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
