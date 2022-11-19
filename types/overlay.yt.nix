# ============================================================================ #
#
# Overlays `ytypes' adding new types.
#
# ---------------------------------------------------------------------------- #

final: prev: {
  NpmLifecycle = import ./npm/lifecycle.nix { ytypes = final; };
  NpmLock      = import ./npm-lock.nix      { ytypes = final; };
  Packument    = import ./packument.nix     { ytypes = final; };
  PkgInfo      = import ./pkginfo.nix       { ytypes = final; };
  FlocoFetch   = import ./fetched.nix       { ytypes = final; };
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
