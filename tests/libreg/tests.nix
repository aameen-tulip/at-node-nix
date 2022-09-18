# ============================================================================ #
#
# General tests for `libreg' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib.libreg)
    registryForScope
    fetchPackument
    importFetchPackument
    packumenter
    packumentClosure
    flakeRegistryFromPackuments
    normalizeManifest
    importCleanManifest
  ;

# ---------------------------------------------------------------------------- #

  registryScopes0 = {
    _default = "https://registry.npmjs.org";
    foo      = "http://localhost:4873";
    bar      = "https://npm.pkgs.github.com";
  };

  flocoConfig0 = lib.mkFlocoConfig { registryScopes = registryScopes0; };

  lib0 = lib.extend ( _: _: {
    flocoConfig = flocoConfig0;
  } );


# ---------------------------------------------------------------------------- #

  tests = {

# ---------------------------------------------------------------------------- #

    testRegistryForScope0 = {
      expr     = lib0.libreg.registryForScope "foo";
      expected = registryScopes0.foo;
    };

# ---------------------------------------------------------------------------- #

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
