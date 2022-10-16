# ============================================================================ #
#
# Provides default config, a config constructor, and a validator.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #
#
# registryScopes           ::= { scope ::= string, url ::= string }
# enableImureMeta          ::= bool
# enableImureFetchers      ::= bool
# allowSubstitutedFetchers ::= bool
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
    registryScopes._default  = "https://registry.npmjs.org";
    enableImpureMeta         = false;
    enableImpureFetchers     = false;
    allowSubstitutedFetchers = true;
    metaEntOverlays          = [];
    metaSetOverlays          = [];
    pkgEntOverlays           = [];
    pkgSetOverlays           = [];
    # It's only possible to put these here because they are platform agnostic.
    # If you use system dependant fetchers override this.
    fetchers = let
      tarballFetcherPure   = lib.libfetch.fetchurlNoteUnpackDrvW;
      tarballFetcherImpure = lib.libfetch.fetchTreeW;
    in {
      fileFetcher    = lib.libfetch.fetchurlDrvW;
      gitFetcher     = lib.libfetch.fetchGitW;
      pathFetcher    = lib.libfetch.pathW;
      tarballFetcher = if lib.inPureEvalMode then tarballFetcherPure
                                             else tarballFetcherImpure;
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
      hasReg = cfg ? registryScopes._default;
      hasFetchers = let
        cf = intersectAttrs cfg.fetchers defaultFlocoConfig.fetchers;
      in ( attrNames cf ) == ( attrNames defaultFlocoConfig.fetchers );
    in hasTop && hasReg && hasFetchers;
    regAllStrings = all builtins.isString ( attrValues cfg.registryScopes );
  in hasDefaultFields && regAllStrings;


# ---------------------------------------------------------------------------- #

  mkFlocoConfig' = {
    registryScopes
  , enableImpure             ? ! lib.inPureEvalMode
  , enableImpureMeta         ? enableImpure
  , enableImpureFetchers     ? enableImpure
  , allowSubstitutedFetchers
  , metaEntOverlays
  , metaSetOverlays
  , pkgEntOverlays
  , pkgSetOverlays
  , fetchers
  , ...
  } @ args: let
    ni  = removeAttrs args ["enableImpure"];
    cfg = ni // {
      inherit enableImpureMeta enableImpureFetchers;
      # Define as a fixed point so changed propagate.
      fetchers = {
        tarballFetcher =
          if cfg.enableImpureFetchers
          then cfg.fetchers.tarballFetcherImpure
          else cfg.fetchers.tarballFetcherPure;
      } // fetchers;
    };
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
