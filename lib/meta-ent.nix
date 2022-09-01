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
    plent  = x.entries.plock or x;
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
    genMetaEntRules "FromPlockSubtype" metaEntWasPlock metaEntFromPlockSubtype
  ) metaEntAddFromPlockSubtype
    metaEntUpFromPlockSubtype
    metaEntExtendFromPlockSubtype
    metaEntMergeFromPlockSubtype
  ;


# ---------------------------------------------------------------------------- #

  # Three args.
  # First holds "global" settings while the second is the actual plock entry.
  # Second and Third are the "path" and "entry" from `<PLOCK>.packages', and
  # the intention is that you use `builtins.mapAttrs' to process the lock.
  metaEntFromPlockV3 = {
    lockDir
  , lockfileVersion ? 3
  , flocoConfig     ? lib.flocoConfig
  }:
  # `mapAttrs' args:
  pkey: {
    ident            ? plent.name or ( lib.libplock.pathId pkey )
  , version
  , hasInstallScript ? false
  , hasBin           ? ( plent.bin or {} ) != {}
  , ...
  } @ plent: let
    key = ident + "/" + version;
    # FIXME: I'm not in love with this `depInfo'.
    # there's a draft sitting in ./depinfo.nix
    depInfo = lib.libpkginfo.normalizedDepsAll plent;
    meta = lib.libmeta.mkMetaEnt ( {
      inherit key ident version;
      inherit hasInstallScript hasBin depInfo;
      entFromtype = "package-lock.json(v${toString lockfileVersion})";
      entries = {
        __serial = false;
        plock = plent // { inherit pkey lockDir; };
      };
    } // ( lib.optionalAttrs hasBin { inherit (plent) bin; } ) );
    sub = lib.libmeta.metaEntMergeFromPlockSubtype meta;
    ex = let
      ovs = flocoConfig.metaEntOverlays or [];
      ov  = if builtins.isList ovs then lib.composeManExtensions ovs else ovs;
    in if ( ovs != [] ) then sub.__extend ov else sub;
  in ex;


/* -------------------------------------------------------------------------- */

  metaSetRootTreesForPlockV3 = { plock , flocoConfig ? lib.flocoConfig }: let
    ident   = plock.name or plock.packages."".name;
    version = plock.version or plock.packages."".version;
  in {
    rootKey = "${ident}/${version}";
    trees.prod = lib.libtree.idealTreePlockV3 {
      inherit plock flocoConfig;
      dev = false;
    };
    trees.dev = lib.libtree.idealTreePlockV3 { inherit plock flocoConfig; };
  };

  inherit (
    genMetaEntRules "RootTreesForPlockV3" lib.libplock.supportsPlV3 ( e: {
      __meta = metaSetRootTreesForPlockV3 e;
    } ) )
      metaSetAddPlockSubtype
      metaSetUpPlockSubtype
      metaSetExtendPlockSubtype
      metaSetMergePlockSubtype
  ;


/* -------------------------------------------------------------------------- */

  metaSetFromPlockV3 = {
    plock       ? lib.importJSON' lockPath
  , pjs         ? lib.importJSON' pjsPath
  , lockDir     ? dirOf lockPath
  , lockPath    ? "${lockDir}/package-lock.json"
  , pjsPath     ? "${lockDir}/package.json"
  , flocoConfig ? lib.flocoConfig
  , ...
  } @ args: assert lib.libplock.supportsPlV3 plock; let
    inherit (plock) lockfileVersion;

    mkOne = path: ent: let
      ident   = ent.ident or ent.name or ( lib.libplock.pathId path );
      version = ( lib.libplock.realEntry plock path ).version;
      key     = "${ident}/${version}";
      # `*Args' is a "merged" `package-lock.json(v3)' style "package entry"
      # that will be processed by `metaEntFromPlockV3'.
      # Only `ident', `version', `hasInstallScripe', and `hasBin' fields are
      # handled by `metaEntFromPlockV3', and remaining fields are stashed in
      # `{ entries.plock = <ARGS> // { inherit pkey lockDir; }; }' and passed
      # to `metaEntMergeFromPlockSubtype' for further processing.
      # The `*PlockSubtype' routine creates `sourceInfo', and will also process
      # `entries.pjs' if it is provided ( or for local paths in the lock )
      # to detect `hasTest' and `hasPrepare' fields ( it's smart enough to
      # find the `package.json' on its own; you only need to inject it if you
      # are trying to override.
      simpleArgs = {
        inherit ident version key;
        entries.plock = ent // { pkeys = [path]; };
      };
      # This gets merged with the real key.
      # We mark `linkFrom' and `linkTo' to avoid loss of detail.
      linkedArgs = {
        inherit ident version key;
        entries.plock = ( removeAttrs ent ["resolved" "link"]) // {
          links = [{ from = ent.resolved; to = path; }];
        };
      };
    in { ${key} = if ent.link or false then linkedArgs else simpleArgs; };

    ents = lib.mapAttrsToList mkOne plock.packages;
    mergeOne = a: b: let
    in ( a // b ) // {
      entries.plock = let
        links = ( a.entries.plock.links or [] ) ++
                ( b.entries.plock.links or [] );
      in a.entries.plock // b.entries.plock // {
        pkeys = a.entries.plock.pkeys ++ b.entries.plock.pkeys;
      } // ( lib.optionalAttrs ( links != [] ) { inherit links; } );
    };
    mergeInstances = key: instances: let
      merged = builtins.foldl' mergeOne ( builtins.head instances )
                                        ( builtins.tail instances );
      ectx =
        builtins.addErrorContext "metaSetFromPlockV3:mergeInstances: ${key}"
                                  merged;
      me = metaEntFromPlockV3 { inherit lockDir lockfileVersion flocoConfig; }
                              ( builtins.deepSeq ectx merged );
    in me;
    metaEntries = builtins.zipAttrsWith mergeInstances ents;
    members = metaEntries // {
      __meta = {
        __serial = false;
        rootKey = "${plock.name}/${plock.version}";
        inherit pjs plock lockDir;
        fromType = "package-lock.json(v${toString lockfileVersion})";
      };
    };
    base = lib.libmeta.mkMetaSet members;
    ex = let
      ovs = flocoConfig.metaSetOverlays or [];
      ov  = if builtins.isList ovs then lib.composeManExtensions ovs else ovs;
    in if ( ovs != [] ) then base.__extend ov else base;
  in ex;


/* -------------------------------------------------------------------------- */

  metaEntriesFromPlockV2 = {
    plock           ? lib.importJSON' lockPath
  , lockDir         ? dirOf lockPath
  , lockPath        ? "${lockDir}/package-lock.json"
  , metaEntOverlays ? []  # Applied to individual packages in `metaSet'
  , metaSetOverlays ? []  # Applied to `metaSet'
  , ...
  } @ args: assert lib.libplock.supportsPlV3; let
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
        setFromtype = assert lib.libplock.supportsPlV3 plock;
          "package-lock.json(v${toString plock.lockfileVersion})";
        inherit plock lockDir lockPath metaSetOverlays metaEntOverlays;
      } // ( lib.optionalAttrs hasRootPkg { inherit rootKey;} );
    in lib.libmeta.mkMetaSet ( ents // { inherit __meta; } );
  in metaSet.__extend ( lib.composeManyExtensions metaSetOverlays );


/* -------------------------------------------------------------------------- */

in {
  inherit
    metaEntFromPlockV3
    metaSetFromPlockV3

    metaEntriesFromPlockV2

    metaEntPlockGapsFromPjs
    metaEntAddPlockGapsFromPjs
    metaEntUpPlockGapsFromPjs
    metaEntExtendPlockGapsFromPjs

    metaEntFromPlockSubtype
    metaEntAddFromPlockSubtype
    metaEntUpFromPlockSubtype
    metaEntExtendFromPlockSubtype
    metaEntMergeFromPlockSubtype
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
