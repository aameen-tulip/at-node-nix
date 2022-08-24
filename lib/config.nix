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
# enableImureFetchers ::= bool
# metaEntOverlays     ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# metaSetOverlays     ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# pkgEntOverlays      ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
# pkgEntOverlays      ::= [overlay ::= ( final ::= attrs -> prev ::= attrs )]
#
#
# ---------------------------------------------------------------------------- #

  defaultFlocoConfig = {
    # Used for querying manifests and packuments.
    # Must be an attrset of strings.
    registryScopes._default = "https://registry.npmjs.org";
    enableImpureMeta        = false;
    enableImpureFetchers    = false;
    metaEntOverlays         = [];
    metaSetOverlays         = [];
    pkgEntOverlays          = [];
    pkgSetOverlays          = [];
    # FIXME: probably remove `fetcher'.
    fetchers = {
      preferBuiltins  = true;
      preferFetchTree = false;
    };
  };


# ---------------------------------------------------------------------------- #

  # Check to see a config is valid.
  # We care about it having the default fields, and some basic type checking.
  # Users are free to add additional fields ( except `enableImpure' ), so we
  # aren't concerned if there's extra fields.
  validateFlocoConfig = cfg: let
    inherit (builtins) intersectAttrs all attrValues attrNames;
    hasDefaultFields = let
      common = intersectAttrs cfg defaultFlocoConfig;
      hasTop = ( attrNames common ) == ( attrNames defaultFlocoConfig );
      hasReg = cfg ? registryScopes ? _default;
      hasFetchers = let
        cf = intersectAttrs cfg.fetcher defaultFlocoConfig.fetcher;
      in ( attrNames cf ) == ( attrNames defaultFlocoConfig.fetcher );
    in hasTop && hasReg && hasFetchers;
    regAllStrings = all builtins.isString ( attrValues cfg.registryScopes );
  in hasDefaultFields && regAllStrings;


# ---------------------------------------------------------------------------- #

  mkFlocoConfig' = {
    registryScopes
  , enableImpure         ? ! lib.inPureEvalMode
  , enableImpureMeta     ? enableImpure
  , enableImpureFetchers ? enableImpure
  , metaEntOverlays
  , metaSetOverlays
  , pkgEntOverlays
  , pkgSetOverlays
  , fetchers
  , ...
  } @ args: let
    ni  = removeAttrs args ["enableImpure"];
    cfg = ni // { inherit enableImpureMeta enableImpureFetchers; };
  in assert validateFlocoConfig cfg;
     cfg;

  mkFlocoConfig = args: let
    fargs    = lib.functionArgs mkFlocoConfig';
    dftArgs  = builtins.intersectAttrs fargs defaultFlocoConfig;
    noImpure = removeAttrs dftArgs ["enableImpureMeta" "enableImpureFetchers"];
    allArgs  = lib.recursiveUpdate noImpure args;
  in mkFlocoConfig' allArgs;


# ---------------------------------------------------------------------------- #

in {
  inherit
    defaultFlocoConfig
    validateFlocoConfig
    mkFlocoConfig
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
