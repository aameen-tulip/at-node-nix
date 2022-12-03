# ============================================================================ #
#
# Organizes configurable routines with common args into sets for the convenience
# of the user.
#
# Legacy routines had a naive approach using `flocoConfig' which was too
# permissive about configs being referenced at a ( basically ) global scope.
# I should have known better but shit grows organically so it sort of just
# happened over time.
#
# The new "flocoEnv" or "fenv" argset is stricter and should never be set
# globally - these args are accepted by every function that is effected by those
# settings so that you can't accidentally form a configured closure
# in calls between subroutines.
#
# There's a few best practices for writing `fenv' functions:
#   1. Never allow fallback args for the core set of fields.
#      Seriously never - I know this seems excessive and tedious but
#      `flocoConfig' was a mess to cleanup and the same mistakes won't be
#      made again.
#   2. All routines that take `fenv' must use "formal" argsets at tag the set
#      as `fenv' so that `grep' and similar tools can quickly search for them.
#   3. Don't mix `fenv' args with regular argsets unless you have a very
#      compelling reason to do so.
#      Some legacy routines being migrated from `flocoConfig' mix these args
#      temporarily - but don't be misguided by those few examples.
#   4. Unconfigured args must be named with "prime" marking, and no "unprime"
#      function of the same name should ever be defined in the regular lib sets.
#      As with (3) there exist a few legacy routines that break this rule; but
#      rest assured that the long arm of the law will bring them to justice
#      soon enough.
#   5. Don't use these to do what a "config"/"NixOS module" style system is
#      supposed to do.
#      Again, `flocoConfig' was an anti-pattern, and as convenient as it is to
#      have configured functions at the top level when you're in a REPL - you're
#      going to kick yourself later when you have to debug the nasty unaligned
#      closures they wind up forming.
#      - TODO: libreg is the big offender here, but we don't currently depend on
#        any of those routines in build pipelines.
#        You should plug those into a NixOS module config system to achieve the
#        desired usage; but this is not a high priority at time of writing.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  getDefaultRegistry = "https://registry.npmjs.org";


# ---------------------------------------------------------------------------- #

  # These libs contain functions which take `fenv' as an arg.
  # NOTE: some libs are merges of multiple files and only some files might
  # contain effected functions.
  # TODO: this list is not magically auto-updated or audited, so try not to fuck
  # that up by forgetting to add new libs here as new routines are added.
  # TODO: certain `laika', `rime', and `ak-nix' lib routines could/should get
  # handled here as well.
  takeFenv = [
    "libfetch"
    "libmeta"
    "libpjs"
    "libpkginfo"
    "libplock"
    "libtree"
    "libfloco"
  ];

  # Makes a "configured" subset of lib routines that share common `fenv' args.
  # These do not necessarily need to be used together - it's often fine to
  # mix routines across sets, but you're on your own in terms of "consistency"
  # if you choose to do that.
  #
  # Any routines marked as "primes" ( foo', bar', and baz' ) are thunked with
  # fallbacks of `fenv' args so `foo' { pure = true; }' is effectively similar
  # to `callPackageWith { pure = false; } foo' { pure = true; }'.
  # Any routines not marked "prime" have applied `fenv' and are ready to accept
  # "regular" arguments.
  mkFenvLibSet = {
    pure
  , ifd
  , allowedPaths
  , typecheck
  } @ fenv: let
    proc= acc: libname: acc // {
      ${libname} = lib.${libname}.__withFenv fenv;
    };
  in builtins.foldl' proc {} takeFenv;


# ---------------------------------------------------------------------------- #

in {
  inherit
    getDefaultRegistry
    mkFenvLibSet
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
