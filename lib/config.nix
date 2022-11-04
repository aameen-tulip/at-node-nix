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
    # Used for querying manifests and packuments.
    # Must be an attrset of strings.
    registryScopes._default = "https://registry.npmjs.org";
    enableImpureMeta = ! lib.inPureEvalMode;
  };


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

in {
  inherit
    validateFlocoConfig
    mkFlocoConfig
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
