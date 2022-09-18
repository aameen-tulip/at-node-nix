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

  lib0 = lib.extend ( _: _: { flocoConfig = flocoConfig0; } );


# ---------------------------------------------------------------------------- #

  tests = {

# ---------------------------------------------------------------------------- #

    # All of these should return the scope for `foo'.
    testRegistryForScope0 = let
      args = [
        "foo" "@foo" "@foo/bar" "@foo/bar/1.0.0"
        { ident = "@foo/bar"; }           { meta.ident = "@foo/bar"; }
        { name  = "@foo/bar"; }           { meta.name  = "@foo/bar"; }
        { scope = "foo"; }                { meta.scope = "foo"; }
        { scope = "@foo"; }               { meta.scope = "@foo"; }
        { scope = "@foo/"; }              { meta.scope = "@foo/"; }
        { key   = "@foo/bar/1.0.0"; }     { meta.key   = "@foo/bar/1.0.0"; }
        { key   = "@foo/bar/1"; }         { meta.key   = "@foo/bar/1"; }
        { key   = "@foo/bar/1-pre"; }     { meta.key   = "@foo/bar/1-pre"; }
        { key   = "@foo/bar/1.0.0-pre"; } { meta.key   = "@foo/bar/1.0.0-pre"; }
      ];
    in {
      expr     = map lib0.libreg.registryForScope args;
      expected = map ( _: registryScopes0.foo ) args;
    };

# ---------------------------------------------------------------------------- #

    # Test tie-breakers. All of these should match `registryScopes0.foo'.
    # In practice, users shouldn't do this; but I at least want to specify the
    # behavior for completeness.
    testRegistryForScope1 = let
      args = [
        { scope = "foo";            meta.scope = "bar"; }
        { scope = "foo";            ident      = "@bar/baz"; }
        { scope = "foo";            name       = "@bar/baz"; }
        { scope = "foo";            key        = "@bar/baz/1.0.0"; }
        { ident = "@foo/baz";       meta.ident = "@bar/baz"; }
        { name  = "@foo/baz";       meta.name  = "@bar/baz"; }
        { key   = "@foo/baz/1.0.0"; meta.key   = "@bar/baz/1.0.0"; }
      ];
    in {
      expr     = map lib0.libreg.registryForScope args;
      expected = map ( _: registryScopes0.foo ) args;
    };


# ---------------------------------------------------------------------------- #

    # Test `_default'/fallback.
    testRegistryForScope2 = {
      expr = map lib0.libreg.registryForScope [
        "baz" "@baz/bar" "."
        # NOTE: This isn't specified in the docs because I don't want people to
        # rely on it; but it's supported to align with the use of
        # `builtins.match' fallbacks to `null' which are generally how we lookup
        # scopes in most routines.
        # This helps us "do what I mean" when someone misses an edge case check.
        null
        { scope = "baz"; } { ident = "baz"; } { scope = "."; } { scope = null; }
      ];
      expected = let
        inherit (registryScopes0) foo bar _default;
        dft = _default;
      in [
        dft dft dft dft
        dft dft dft dft
      ];
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
