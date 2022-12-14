# ============================================================================ #
#
# Overlays `ytypes' adding new types.
#
# ---------------------------------------------------------------------------- #

final: prev: {
  Npm          = import ./npm               { ytypes = final; };
  NpmLock      = import ./npm-lock.nix      { ytypes = final; };
  Packument    = import ./packument.nix     { ytypes = final; };
  PkgInfo      = import ./pkginfo.nix       { ytypes = final; };
  FlocoFetch   = import ./fetched.nix       { ytypes = final; };
  FlocoMeta    = import ./meta.nix          { ytypes = final; };
  DepInfo      = import ./depinfo.nix       { ytypes = final; };
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
