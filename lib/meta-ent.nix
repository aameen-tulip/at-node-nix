# ============================================================================ #
#
# I strongly recommend reading
# [[file:../doc/processes-and-metadata.org][Processes and Metadata]]
# for a primer on "which processes actually use which pieces of metadata".
#
# Understanding when it is worthwhile to put in extra effort to infer a bit of
# info before generating derivations, and when it's mellow to defer to ad-hoc
# handling inside of a derivation is useful context for leveraging these
# routines in your build pipeline; and even moreso when augmenting these
# routines to satisfy the unique needs of your workflow.
#
# The metadata routines defined here should be viewed as your "out of the box"
# standard metadata scrapers - they will make quick work of most projects,
# particularly published tarballs; but you are sincerely encouraged to
# add extra fields to suite your own purposes.
#
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
  entHasPrepareScript = hasStageScript "prepare";
  entHasTestScript    = hasStageScript "test";
  entHasPublishScript = hasStageScript "publish";

  entHasInstallScript = ent: let
    fromScript = hasStageScript "install" ent;
    fromPlock  = ent.hasInstallScript or false;
  in if lib.libmeta.metaEntWasPlock ent then fromPlock else fromScript;

  # Returns null for inconclusive;
  entHasBuild = ent: let
    entSubtype = ent.sourceInfo.entSubtype or
                 ent.sourceInfo.type or
                 ( lib.libfetch.typeOfEntry ent );
    isTb         = ! ( builtins.elem entSubtype ["path" "symlink" "git"] );
    fromPjs = if ent ? entries.pjs
              then hasBuildFromScripts ent.entries.pjs.scripts
              else null;
    fromSubtype = if entSubtype == null then null else
                  if fromPjs == null then null else
                  ( ! isTb ) && fromPjs;
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

  # Reconstruct a `metaEnt' from its serialized form.
  # This performs a small amount of fixup in an effort to support "raw" inputs;
  # but it is designed for use with `metaEntFrom*' routines that have been
  # dumped to files.
  #
  # If you are "spoofing" a particular type of entry ( ex: `package-lock.json` )
  # you should refer to the `metaEntFrom*' implementation and real serialized
  # data to align with it - we do NOT call their actual constructors again and
  # you cannot rely on any of the impure/inferred values that they normally add.
  #
  # XXX: This does not add `entries.*' fields which is important to remember
  #      particularly for `package-lock.json' entries since you cannot access
  #      `lockDir', `pkey', or `lockfileVersion' values that are normally
  #      stashed there - those fields are "really" associated with the `metaSet'
  #      and the decision to exclude them after serialization is intentional.
  metaEntFromSerial = {
    key
  , ident       ? dirOf key
  , version     ? baseNameOf key
  , scoped      ? lib.test "@[^@/]+/[^@/]+" ident
  , entFromtype ? "raw"
  , sourceInfo
  # These are just here to get `builtins.intersectAttrs' to work.
  , depInfo          ? {}
  , bin              ? {}
  , hasBin           ? ( ent.bin or ent.directories.bin or {} ) != {}
  , hasBuild         ? entHasBuild ent
  , hasPrepare       ? entHasPrepareScript ent
  , hasInstallScript ? entHasInstallScript ent
  , gypfile          ? false
  , hasTest          ? entHasTestScript    ent
  , scripts          ? {}
  , ...
  } @ ent: let
    hasBuild' = lib.optionalAttrs ( hasBuild != null ) { inherit hasBuild; };
    members =
      { inherit ident version scoped entFromtype; } //
      ( lib.optionalAttrs ( ent ? bin || ent ? hasBin ) {
        inherit hasBin;
      } ) // ent;
    # Use these fallback fields for certain `entFromtype' values.
    fieldsForFT = {
      plock = {
        inherit
          bin
          hasBin
          hasInstallScript
          depInfo
        ;
      } // hasBuild' ;  # `hasBuild' will be inconclusive for some `git' deps.
      "package.json" = {
        inherit
          bin
          hasBin
          hasBuild
          scripts
          hasPrepare
          hasInstallScript
          hasTest
          depInfo
        ;
      };
      manifest = {
        # TODO: This list is incomplete. See `libreg' for full list of fields.
        inherit
          bin
          scripts
          gypfile
        ;
      };
      packument = {
        # TODO
      };
      ylock = {
        # Fuck this forreal tho.
        # Probably not going to do this myself.
      };
    };

    ftFields = if lib.libmeta.metaEntWasPlock ent then fieldsForFT.plock else
               if lib.libmeta.metaEntWasYlock ent then fieldsForFT.ylock else
               ( fieldsForFT.${entFromtype} or {} );

  in lib.libmeta.mkMetaEnt ( members // ftFields );


# ---------------------------------------------------------------------------- #

  metaSetFromSerial = members: let
    deserial = name: value: let
      forEnt  = metaEntFromSerial value;
      # Regenerate missing `pjs' and `plock' fields if `lockDir' is defined.
      forMeta = ( lib.optionalAttrs ( value ? lockDir ) {
        pjs   = lib.importJSON' "${value.lockDir}/package.json";
        plock = lib.importJSON' "${value.lockDir}/package-lock.json";
      } ) // value;
    in if name == "__meta" then forMeta else
       if lib.hasPrefix "__" name then value else
       forEnt;
  in lib.libmeta.mkMetaSet ( builtins.mapAttrs deserial members );


# ---------------------------------------------------------------------------- #

  metaEntFromPlockSubtype = x: let
    plent   = x.entries.plock or x;
    lockDir = plent.lockDir;
    pjsDir  = if plent.pkey == "" then lockDir else
              if plent.link or false then "${lockDir}/${plent.resolved}" else
               "${lockDir}/${plent.pkey}";
    pjsPath = "${pjsDir}/package.json";
    tryPjs  = ( x ? entries.pjs ) || ( builtins.pathExists pjsPath );
    pjs     = x.entries.pjs or ( lib.importJSON' pjsPath );
    fromPjs = ( metaEntPlockGapsFromPjs pjs ) // {
      sourceInfo.path = pjsDir;
      entries.pjs     = pjs // { inherit pjsDir; };
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
        v.gypfile = builtins.pathExists "${pjsDir}/binding.gyp";
      }
      # This is NOT redundant alongside the `plockEntryHashAttrs' call.
      { c = plent ? integrity;  v.sourceInfo.hash = plent.integrity;       }
    ];
    forAttrs = builtins.foldl' lib.recursiveUpdate core [
      conds
      # Returns `sha(512|256|1) = integrity' or `hash -integrity' as a fallback.
      { sourceInfo = lib.libfetch.plockEntryHashAttr plent; }
    ];
    ec = builtins.addErrorContext "metaEntFromPlockSubtype";
  in if builtins.isString x then core else ec forAttrs;

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
  # `mapAttrs' args. ( `pkey' and `args' ).
  # `args' may be either an entry pulled directly from a lock, or a `metaEnt'
  # skeleton with the `plent' stashed in `args.entries.plock'.
  pkey:
  {
    ident   ? args.name or ( lib.libplock.pathId pkey )
  , version
  , ...
  } @ args: let
    plent = if args ? entries.plock then args.entries.plock else args;
    key = ident + "/" + version;
    hasBin = ( plent.bin or {} ) != {};
    baseFields = {
      inherit key ident version;
      inherit hasBin;
      depInfo = lib.libdep.depInfoEntFromPlockV3 pkey plent;
      hasInstallScript = plent.hasInstallScript or false;
      entFromtype = "package-lock.json(v${toString lockfileVersion})";
      entries = {
        __serial = false;
        plock = assert ! ( plent ? entries );
                plent // { inherit pkey lockDir; };
      };
    } // ( lib.optionalAttrs hasBin { inherit (plent) bin; } )
      // ( lib.optionalAttrs ( plent ? gypfile ) { inherit (plent) gypfile; } );
    # Merge with original arguments unless they were a raw package-lock entry.
    argFields = if ! ( args ? entries ) then baseFields else
                lib.recursiveUpdate baseFields args;
    meta = lib.libmeta.mkMetaEnt argFields;
    sub = lib.libmeta.metaEntMergeFromPlockSubtype meta;
    ex = let
      ovs = flocoConfig.metaEntOverlays or [];
      ov  = if builtins.isList ovs then lib.composeManyExtensions ovs else ovs;
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
      ident   = let
        # If entry is a link to an out of tree dir we will miss it using this
        # basic lookup but it handles the vast majority of deps.
        subs = ent.ident or ent.name or ( lib.libplock.pathId path );
      in if subs == null then lib.lookupRelPathIdentV3 plock path else subs;
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

    mergeOne = a: b: let
      links = ( a.entries.plock.links or [] ) ++
              ( b.entries.plock.links or [] );
      # This is just in case the linked entry is before the real entry.
      pkeys = ( a.entries.plock.pkeys or [] ) ++
              ( b.entries.plock.pkeys or [] );
      stage1 = lib.recursiveUpdate a b;
      plock  = stage1.entries.plock // ( {
        inherit pkeys;
      } // ( lib.optionalAttrs ( links != [] ) { inherit links; } ) );
    in stage1 // { entries = stage1.entries // { inherit plock; }; };

    mergeInstances = key: instances: let
      merged = builtins.foldl' mergeOne ( builtins.head instances )
                                        ( builtins.tail instances );
      ectx =
        builtins.addErrorContext "metaSetFromPlockV3:mergeInstances: ${key}"
                                  merged;
      me = metaEntFromPlockV3 { inherit lockDir lockfileVersion flocoConfig; }
                              ( builtins.head merged.entries.plock.pkeys )
                              ( builtins.deepSeq ectx merged );
    in me;

    ents = lib.mapAttrsToList mkOne plock.packages;
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

in {
  inherit
    metaEntFromSerial
    metaSetFromSerial

    metaEntFromPlockV3
    metaSetFromPlockV3

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
