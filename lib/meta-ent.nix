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
  inherit (lib.libmeta) metaWasPlock;

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # original metadata sources such as `package.json' are stashed as members
  # of `entries' by default. 
  # We use this accessor to refer to them so that users can override this
  # function with custom implementations that fetch these files.
  getFromEntries = { entries ? {} }: builtins.attrValues entries;

  # Abstraction to refer to `package.json' scripts fields.
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
  in if lib.libmeta.metaWasPlock ent then fromPlock else fromScript;

  # Returns null for inconclusive;
  # NOTE: `git' sources with `package-lock.json' are the ones that you can run
  # into inconclusive results on the most.
  # The scrapers from local paths generally attempt to read the `package.json'
  # files so you have coverage there; but for `git' we don't try to fetch in
  # order to read the `scripts' field.
  # FIXME: In impure mode actually go collect that info because `git' deps
  # often do have `scripts.build' routines.
  # The routine that adds info from plock `fetchInfo' data already does this.
  entHasBuild = ent: let
    type = ent.fetchInfo.type or
           ( lib.libfetch.identifyPlentFetcherFamily ent );
    fromPjs = if ent ? entries.pjs
              then hasBuildFromScripts ent.entries.pjs.scripts
              else null;
    fromSubtype = if fromPjs == null then null else
                  ( ! ( builtins.elem type ["file" "tarball"] ) ) && fromPjs;
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
    genMetaEntRules "PlockGapsFromPjs" metaWasPlock metaEntPlockGapsFromPjs
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
  , fetchInfo
  # These are just here to get `builtins.intersectAttrs' to work.
  , depInfo          ? {}
  , bin              ? {}
  , hasBin           ? ( ent.bin or ent.directories.bin or {} ) != {}
  , hasBuild         ? entHasBuild ent
  , hasPrepare       ? entHasPrepareScript ent
  , hasInstallScript ? entHasInstallScript ent
  , gypfile          ? false  # XXX: do not read this field from registries
  , hasTest          ? entHasTestScript    ent
  , scripts          ? {}
  , os               ? null
  , cpu              ? null
  , engines          ? null
  , trees            ? {}
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
      # XXX: DO NOT READ `gypfile' field from registries!
      vinfo = {
        # TODO: This list is incomplete. See `libreg' for full list of fields.
        inherit
          bin
          scripts
        ;
      };
      # XXX: DO NOT READ `gypfile' field from registries!
      packument = {
        # TODO
      };
      ylock = {
        # Fuck this forreal tho.
        # Probably not going to do this myself.
      };
    };

    ftFields = if lib.libmeta.metaWasPlock ent then fieldsForFT.plock else
               if lib.libmeta.metaWasYlock ent then fieldsForFT.ylock else
               ( fieldsForFT.${entFromtype} or {} );

  in lib.libmeta.mkMetaEnt ( members // ftFields );


# ---------------------------------------------------------------------------- #

  metaSetFromSerial = members: let
    deserial = name: value: let
      forEnt  = metaEntFromSerial value;
      # Regenerate missing `pjs' and `plock' fields if `lockDir' is defined.
      forMeta = ( lib.optionalAttrs ( value ? lockDir ) {
        pjs   = lib.importJSON' ( value.lockDir + "/package.json" );
        plock = lib.importJSON' ( value.lockDir + "/package-lock.json" );
      } ) // value;
    in if name == "__meta" then forMeta else
       if lib.hasPrefix "__" name then value else
       forEnt;
  in lib.libmeta.mkMetaSet ( builtins.mapAttrs deserial members );


# ---------------------------------------------------------------------------- #

  # "Lifecycle Type" indicating the category of `pacote'/NPM source tree
  # as it relates to the execution of lifecycle scripts.
  # For example, NPM will run `build', `prepare', and `prepack' scripts for
  # local paths and `git' "ltypes", but only runs `install' scripts
  # for tarballs.
  # Because we use a variety of backends to perform fetching, it would be
  # inappropriate to call these "fetcher types" or "source tree types" like
  # NPM and `pacote' do - so instead we highlight that they explicitly effect
  # the execution of lifecycle scripts in our builders.
  #
  # We do not refer to them as "source types" or "fetcher types", since this
  # would be confusing to users and maintainers in relation to the flocoFetch
  # "fetcher families" ( "git", "path", and "file" ), as well as Nix's
  # "tree types" ( "git", "github", "path", "file", "tarball", etc ).
  #
  # These names and categories are all closesly related and frequently overlap,
  # but the distinctions between them are important depending on their context.


# ---------------------------------------------------------------------------- #

  # NOTE: the main difference here in terms of detection is that `resolved' for
  # dir/link entries will be an absolute path.
  # Aside from that we just have extra fields ( `NpmLock.Structs.pkg_*' types
  # ignore extra fields so this is fine ).
  identifyMetaEntFetcherFamily = {
    fetchInfo ? null
  , entries ? {}
  , ...
  } @ metaEnt:
    if fetchInfo != null
    then lib.libfetch.identifyFetchInfoFetcherFamily fetchInfo else
    if ( entries.plent or null ) != null
    then lib.libplock.identifyPlentFetcherFamily entries.plent
    else throw "identifyMetaEntFetcherFamily: Cannot discern 'fetcherFamily'";


# ---------------------------------------------------------------------------- #

  # Identify Lifecycle "For Any"
  identifyLifecycle = x: let
    fromFi    = throw "identifyLifecycleType: TODO from fetchInfo";
    plent'    = x.entries.plock or x;
    fromPlent = lib.libplock.identifyPlentLifecycleV3 plent';
  in if builtins.isString x then x else
     if yt.NpmLock.package.check plent' then fromPlent else
     if yt.FlocoFetch.fetched.check x then x.ltype else
     if yt.FlocoFetch.fetch_info_floco.check x then fromFi else
     throw ( "(identifyLifecycle): cannot infer lifecycle type from '"
             "${lib.generators.toPretty { allowPrettyValues = true; } x}'" );


# ---------------------------------------------------------------------------- #

  # FIXME: this needs to be organized by command
  metaEntFromLifecycleStrict' = lib.matchLam {
    git = {
      lifecycle.pack    = false;  # effectively an alias of "build"/"dist"
      lifecycle.install = true;   # effectively an alias of "compile"
      lifecycle.prepare = true;   # effectively an alias of "setup"
    };
    link = {
      lifecycle.pack    = true;
      lifecycle.install = true;
      lifecycle.prepare = true;
    };
    dir = {
      lifecycle.pack       = true;  # Runs `prepare'
      lifecycle.install    = true;
      lifecycle.prepublish = true;
      # NO PREPARE, that is only run for links.
    };
  };


# ---------------------------------------------------------------------------- #

  # Three args.
  # First holds "global" settings while the second is the actual plock entry.
  # Second and Third are the "path" and "entry" from `<PLOCK>.packages', and
  # the intention is that you use `builtins.mapAttrs' to process the lock.
  metaEntFromPlockV3 = {
    lockDir
  , lockfileVersion ? 3
  , pure            ? flocoConfig.pure or lib.inPureEvalMode
  , ifd             ? true
  , typecheck       ? false
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
    plent = args.entries.plock or args;
    key = ident + "/" + version;
    hasBin = ( plent.bin or {} ) != {};
    baseFields = {
      inherit key ident version;
      inherit hasBin;
      ltype            = lib.libplock.identifyPlentLifecycleV3' plent;
      depInfo          = lib.libdep.depInfoEntFromPlockV3 pkey plent;
      hasInstallScript = plent.hasInstallScript or false;
      entFromtype = "package-lock.json(v${toString lockfileVersion})";
      fetchInfo   = lib.libplock.fetchInfoGenericFromPlentV3' {
        inherit pure ifd typecheck;
      } { inherit lockDir; } { inherit pkey; plent = args; };
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
    sub  = meta;  # FIXME: add fields based on `ltype'
    ex = let
      ovs = flocoConfig.metaEntOverlays or [];
      ov  = if builtins.isList ovs then lib.composeManyExtensions ovs else ovs;
    in if ( ovs != [] ) then sub.__extend ov else sub;
  in ex;


# ---------------------------------------------------------------------------- #

  metaSetFromPlockV3 = {
    plock       ? lib.importJSON' lockPath
  , pjs         ? lib.importJSON' pjsPath
  , lockDir     ? dirOf lockPath
  , lockPath    ? lockDir + "/package-lock.json"
  , pjsPath     ? lockDir + "/package.json"
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
      inherit (lib.libplock.realEntry plock path) version;
      key = "${ident}/${version}";

      # `*Args' is a "merged" `package-lock.json(v3)' style "package entry"
      # that will be processed by `metaEntFromPlockV3'.
      # Only `ident', `version', `hasInstallScripe', and `hasBin' fields are
      # handled by `metaEntFromPlockV3', and remaining fields are stashed in
      # `{ entries.plock = <ARGS> // { inherit pkey lockDir; }; }' and passed
      # to `metaEntMergeFromLifecycleType' for further processing.
      # The `*LifecycleType' routine creates `fetchInfo', and will also process
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
      ov  = if builtins.isList ovs then lib.composeManyExtensions ovs else ovs;
    in if ( ovs != [] ) then base.__extend ov else base;
  in ex;


# ---------------------------------------------------------------------------- #

  # Determines if a package needs any `node_modules/' to prepare
  # for consumption.
  # This framework aims to build projects in isolation, so this helps us
  # determine which projects actually need processing.
  # If `hasBuild' is not yet set, we will err on the safe side and assume it
  # has a build.
  # XXX: It is strongly recommended that you provide a `hasBuild' field.
  # For tarballs we know there's no build, but aside from that we don't
  # make assumptions here.
  metaEntIsSimple = {
    hasBuild         ? attrs.ltype != "file"
  , hasInstallScript ? false
  , hasPrepare       ? false
  , hasBin           ? false
  , hasTest          ? false
  , ...
  } @ attrs: ! ( hasBuild || hasInstallScript || hasPrepare || hasBin );

  # Split a collection of packages based on `metaEntIsSimple'.
  metaSetPartitionSimple = mset: let
    lst = builtins.attrValues mset.__entries;
    parted = builtins.partition metaEntIsSimple lst;
  in {
    simple       = parted.right;
    needsModules = parted.wrong;
  };


# ---------------------------------------------------------------------------- #

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

    metaEntIsSimple
    metaSetPartitionSimple  # by `metaEntIsSimple'
  ;

  inherit
    identifyMetaEntFetcherFamily
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
