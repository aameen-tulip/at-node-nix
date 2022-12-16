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
, name    ? metaEnt.names.global or "${baseNameOf ident}-${version}"
, ident   ? args.metaEnt.ident or ( dirOf args.key )
, version ? args.metaEnt.version or ( baseNameOf args.key )
, key     ? args.metaEnt.key or "${ident}/${version}"
, src
, globalNmDirCmd ? args.nmDirCmd or ":"
, metaEnt        ? lib.libmeta.mkMetaEntCore { inherit ident version; }
, evalScripts
, ...
} @ args: let
  mkDrvArgs = removeAttrs args ["evalScripts"];
in evalScripts ( {
  inherit name ident version src globalNmDirCmd metaEnt;
  runScripts    = [];
  globalInstall = true;
  postUnpack    = ":";
  dontBuild     = true;
  dontConfigure = true;
} // mkDrvArgs )


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
