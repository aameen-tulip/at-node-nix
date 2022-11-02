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

  # XXX: Mainters Note: You must keep `enableImpureFetchers' assignment in sync
  # with `tarballFetcher' purity detection since there is no self reference.
  defaultFlocoConfig = {
    # Used for querying manifests and packuments.
    # Must be an attrset of strings.
    registryScopes._default  = "https://registry.npmjs.org";
    enableImpureMeta         = ! lib.inPureEvalMode;
    enableImpureFetchers     = ! lib.inPureEvalMode;
    allowSubstitutedFetchers = true;
    metaEntOverlays          = [];
    metaSetOverlays          = [];
    pkgEntOverlays           = [];
    pkgSetOverlays           = [];
    # It's only possible to put these here because they are platform agnostic.
    # If you use system dependant fetchers override this.
    fetchers = {
      gitFetcher     = lib.libfetch.flocoGitFetcher;
      pathFetcher    = lib.libfetch.flocoPathFetcher;
      fileFetcher    = if   lib.libcfg.defaultFlocoConfig.enableImpureFetchers
                       then lib.libfetch.flocoTarballFetcher
                       else lib.libfetch.fetchurlNoteUnpackDrvW;
      tarballFetcher = if   lib.libcfg.defaultFlocoConfig.enableImpureFetchers
                       then lib.libfetch.flocoTarballFetcher
                       else lib.libfetch.fetchurlNoteUnpackDrvW;
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
        tarballFetcher = if enableImpureFetchers
                         then lib.libfetch.fetchurlUnpackDrvW
                         else lib.libfetch.fetchurlNoteUnpackDrvW;
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
