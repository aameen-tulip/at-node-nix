# ============================================================================ #
#
# Provides default config, a config constructor, and a validator.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #
#
# registryScopes      ::= { scope ::= string, url ::= string }
# enableImureMeta     ::= bool
# metaEntOverlays     ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# metaSetOverlays     ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# pkgEntOverlays      ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# pkgEntOverlays      ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# flocoFetchArgs      ::= { pure ::= bool, typecheck ::= bool, ... }
#                         see ./fetch.nix:mkFlocoFetcher for full list.
#
#
# ---------------------------------------------------------------------------- #

  # XXX: Used as a base for constructing `flocoConfig'.
  baseFlocoConfig = {
    # Used for querying packuments and abbreviated version info.
    # Must be an attrset of strings.
    registryScopes._default = "https://registry.npmjs.org";
    enableImpureMeta = ! lib.inPureEvalMode;
  };


# ---------------------------------------------------------------------------- #

  getDefaultRegistry =
    ( lib.flocoConfig or baseFlocoConfig ).registryScopes._default;


# ---------------------------------------------------------------------------- #

  # Check to see a config is valid.
  # We care about it having the default fields, and some basic type checking.
  # Users are free to add additional fields ( except `enableImpure' ), so we
  # aren't concerned if there's extra fields.
  validateFlocoConfig = cfg: let
    inherit (builtins) intersectAttrs all attrValues attrNames;
    hasDefaultFields = let
      common = intersectAttrs cfg baseFlocoConfig;
      hasTop = ( attrNames common ) == ( attrNames baseFlocoConfig );
      hasReg = cfg ? registryScopes._default;
    in hasTop && hasReg;
    regAllStrings = all builtins.isString ( attrValues cfg.registryScopes );
  in hasDefaultFields && regAllStrings;


# ---------------------------------------------------------------------------- #

  mkFlocoConfig' = {
    registryScopes
  , enableImpure     ? ! lib.inPureEvalMode
  , enableImpureMeta ? enableImpure
  , metaEntOverlays  ? []
  , metaSetOverlays  ? []
  , pkgEntOverlays   ? []
  , pkgSetOverlays   ? []
  , flocoFetchArgs   ? { pure = ! enableImpure; }
  , ...
  } @ args: let
    ni  = removeAttrs args ["enableImpure"];
    cfg = ni // { inherit enableImpureMeta flocoFetchArgs; };
  in assert validateFlocoConfig cfg;
     cfg;

  mkFlocoConfig = args: let
    fargs    = lib.functionArgs mkFlocoConfig';
    dftArgs  = builtins.intersectAttrs fargs baseFlocoConfig;
    noImpure = removeAttrs dftArgs ["enableImpureMeta"];
    allArgs  = lib.recursiveUpdate noImpure args;
  in mkFlocoConfig' allArgs;


# ---------------------------------------------------------------------------- #

  # These libs contain functions which take `fenv' as an arg.
  # NOTE: some libs are merges of multiple files and only some files might
  # contain effected libs.
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
  , basedir
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
    validateFlocoConfig
    mkFlocoConfig
    mkFenvLibSet
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
