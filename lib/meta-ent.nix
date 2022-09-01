# ============================================================================ #
#
# FIXME: Rename and tweak this for V3 explicitly.
# FIXME: Remove `package.json' references.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib) genMetaEntRules;
  inherit (lib.libmeta) metaEntWasPlock;

# ---------------------------------------------------------------------------- #

  getFromEntries = { entries ? {} }: builtins.attrValues entries;

  getScripts = { scripts ? {} , entries ? {} }: let
    entScripts = builtins.catAttrs "scripts" ( builtins.attrValues entries );
  in ( builtins.foldl' ( a: b: a // b ) {} entScripts ) // scripts;


# ---------------------------------------------------------------------------- #

  hasStageFromScripts = stage: scripts:
    ( scripts ? ${stage} )        ||
    ( scripts ? "pre${stage}" )   ||
    ( scripts ? "post${stage}" );

  hasBuildFromScripts   = hasStageFromScripts "build";
  hasPrepareFromScripts = hasStageFromScripts "prepare";
  hasInstallFromScripts = hasStageFromScripts "install";
  hasTestFromScripts    = hasStageFromScripts "test";
  hasPublishFromScripts = hasStageFromScripts "publish";


# ---------------------------------------------------------------------------- #

  hasStageScript = stage: ent: let
    sl = builtins.catAttrs "scripts"
                           ( builtins.attrValues ( ent.entries or {} ) );
  in if ( ent ? scripts ) then hasStageFromScripts stage else
    builtins.any ( hasStageFromScripts stage ) sl;

  entHasBuildScript   = hasStageScript "build";
  entHasInstallScript = hasStageScript "install";
  entHasPrepareScript = hasStageScript "prepare";
  entHasTestScript    = hasStageScript "test";
  entHasPublishScript = hasStageScript "publish";

  # Returns null for inconclusive;
  entHasBuild = ent: let
    entSubtype = ent.sourceInfo.entSubtype or
                 ent.sourceInfo.type or
                 ( lib.libfetch.typeOfEntry ent );
    isTb         = ! ( builtins.elem entSubtype ["path" "symlink" "git"] );
    fromPjs = if ent ? entries.pjs
              then hasBuildFromScripts ent.entries.pjs.scripts
              else null;
    fromSubtype  = if entSubtype == null then null else ( ! isTb ) && fromPjs;
  in ent.hasBuild or fromSubtype;


# ---------------------------------------------------------------------------- #

  # Fields that we can scrape from `package.json' that `package-lock.json' lacks
  metaEntPlockGapsFromPjs = x: let
    pjs = x.entries.pjs or x;
  in {
    hasBuild   = hasBuildFromScripts   ( pjs.scripts or {} );
    hasPrepare = hasPrepareFromScripts ( pjs.scripts or {} );
    hasTest    = hasTestFromScripts    ( pjs.scripts or {} );
  };

  inherit (
    genMetaEntRules "PlockGapsFromPjs" metaEntWasPlock metaEntPlockGapsFromPjs
  ) metaEntAddPlockGapsFromPjs
    metaEntUpPlockGapsFromPjs
    metaEntExtendPlockGapsFromPjs
  ;


# ---------------------------------------------------------------------------- #

  metaEntFromPlockSubtype = x: let
    plent  = x.entries.plent or x;
    pjsDir = if plent.pkey == "" then "" else
             if plent.link or false then "/${plent.resolved}" else
             "/${plent.pkey}";
    pjsPath = "${pjsDir}/package.json";
    tryPjs  = ( x ? entries.pjs ) || ( builtins.pathExists pjsPath );
    pjs     = x.entries.pjs or ( lib.importJSON' "${pjsDir}/package.json" );
    fromPjs = ( metaEntPlockGapsFromPjs pjs ) // {
      sourceInfo.path = plent.resolved;
      entries.pjs = pjs // { inherit pjsDir; };
    };
    isLocal     = ( entSubtype == "path" ) || ( entSubtype == "symlink" );
    isRemoteSrc = ( entSubtype == "git" ) || ( entSubtype == "source-tarball" );
    isTb        = ( entSubtype == "registry-tarball" ) ||
                  ( entSubtype == "source-tarball" );
    entSubtype =
      if builtins.isString x then x else
      x.sourceInfo.entSubtype or ( lib.libfetch.typeOfEntry plent );
    core = {
      sourceInfo = {
        type = if isLocal then "path" else if isTb then "tarball" else "git";
        inherit entSubtype;
      };
    };
    conds = let
      mergeCond = a: { c, v }: if ! c then a else lib.recursiveUpdate a v;
    in builtins.foldl' mergeCond core [
      { c = isTb;               v.hasBuild = false;                        }
      { c = isLocal && tryPjs;  v = fromPjs;                               }
      { c = ! isLocal;          v.sourceInfo.url = plent.resolved;         }
      {
        c = isLocal && ( plent.hasInstallScript or false );
        v = builtins.pathExists "${pjsDir}/binding.gyp";
      }
      # This is NOT redundant alongside the `plockEntryHashAttrs' call.
      { c = plent ? integrity;  v.sourceInfo.hash = plent.integrity;       }
    ];
    forAttrs = builtins.foldl' lib.recursiveUpdate core [
      conds
      # Returns `sha(512|256|1) = integrity' or `hash -integrity' as a fallback.
      { sourceInfo = lib.libfetch.plockEntryHashAttr plent; }
    ];
  in if builtins.isString x then core else forAttrs;

  inherit (
    genMetaEntRules "PlockSubtype" metaEntWasPlock metaEntFromPlockSubtype
  ) metaEntAddPlockSubtype
    metaEntUpPlockSubtype
    metaEntExtendPlockSubtype
  ;


# ---------------------------------------------------------------------------- #

  metaEntFromPlockV3 = { lockDir, lockfileVersion ? 3 }: pkey: {
    ident            ? plent.name or ( lib.libplock.pathId pkey )
  , version
  , hasInstallScript ? false
  , hasBin           ? ( plent.bin or {} ) != {}
  , ...
  } @ plent: let
    key = ident + "/" + version;
    depInfo = lib.libpkginfo.normalizedDepsAll plent;
    meta = let
      core = lib.libmeta.mkMetaEntCore { inherit key ident version; };
    in core.__update ( {
      inherit hasInstallScript hasBin depInfo;
      entFromtype = "package-lock.json(v${toString lockfileVersion})";
      entries = {
        __serial = false;
        plent = plent // { inherit pkey lockDir; };
      };
    } // ( lib.optionalAttrs hasBin { inherit (plent) bin; } ) );
    sub = let
      st = lib.recursiveUpdate ( metaEntFromPlockSubtype meta.__entries )
                               meta.__entries;
    in meta.__update st;
  in sub;


/* -------------------------------------------------------------------------- */

  metaEntriesFromPlockV2 = {
    plock           ? lib.importJSON' lockPath
  , lockDir         ? dirOf lockPath
  , lockPath        ? "${lockDir}/package-lock.json"
  , metaEntOverlays ? []  # Applied to individual packages in `metaSet'
  , metaSetOverlays ? []  # Applied to `metaSet'
  , ...
  } @ args: assert lib.libplock.supportsPlockV3; let
    ents = let
      pins = lib.libplock.pinVersionsFromLockV2 plock;
      metaEnts = let
        mkOneEnt = p: e: metaEntFromPlockV3 {
          inherit lockDir;
          inherit (plock) lockfileVersion;
        };
        wf = builtins.mapAttrs ( metaEntFromPlockV3 lockDir ) plock.packages;
        addPin = e: e.__extend ( _: prev: {
          depInfo = ( prev.depInfo or { __serial = false; } ) // pins.${e.key};
        } );
        lst = map ( { key, ... } @ value: {
          name  = key;
          value = addPin value;
        } ) ( builtins.attrValues wf );
      in builtins.listToAttrs lst;
      entOv = if builtins.isFunction metaEntOverlays then metaEntOverlays else
              lib.composeManyExtensions metaEntOverlays;
      withOv = builtins.mapAttrs ( _: e: e.__extend entOv ) metaEnts;
      final = if metaEntOverlays != [] then withOv else metaEnts;
    in final;
    metaSet = let
      __meta = let
        hasRootPkg = ( plock ? name ) && ( plock ? version );
        rootKey = "${plock.name}/${plock.version}";
      in {
        setFromtype = assert lib.libplock.supportsPlockV3 plock;
          "package-lock.json(v${toString plock.lockfileVersion})";
        inherit plock lockDir lockPath metaSetOverlays metaEntOverlays;
      } // ( lib.optionalAttrs hasRootPkg { inherit rootKey;} );
    in lib.libmeta.mkMetaSet ( ents // { inherit __meta; } );
  in metaSet.__extend ( lib.composeManyExtensions metaSetOverlays );


/* -------------------------------------------------------------------------- */

in {
  inherit
    metaEntFromPlockV3
    metaEntriesFromPlockV2

    metaEntPlockGapsFromPjs
    metaEntAddPlockGapsFromPjs
    metaEntUpPlockGapsFromPjs
    metaEntExtendPlockGapsFromPjs

    metaEntFromPlockSubtype
    metaEntAddPlockSubtype
    metaEntUpPlockSubtype
    metaEntExtendPlockSubtype
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
