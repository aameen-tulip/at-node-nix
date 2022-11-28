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
  # of `metaFiles' by default.
  # We use this accessor to refer to them so that users can override this
  # function with custom implementations that fetch these files.
  # TODO: deprecate `entries' field.
  getMetaFiles = {
    entries   ? {}
  , metaFiles ? {}
  , ...
  } @ args: let
    msg =
      "WARNING: <META-ENT>.entries.* is deprecated. Use <META-ENT>.metaFiles.*";
    pull = attrs: builtins.attrValues ( removeAttrs attrs ["__serial"] );
  in if args ? entries then builtins.trace msg ( pull entries )
                       else pull metaFiles;

  # Abstraction to refer to `package.json' scripts fields.
  getScripts = {
    scripts ? {}
  , ...
  } @ args: let
    fromMetaFiles = builtins.catAttrs "scripts" ( getMetaFiles args );
  in ( builtins.foldl' ( a: b: a // b ) {} fromMetaFiles ) // scripts;


# ---------------------------------------------------------------------------- #

  entHasStageScript = stage: ent: let
    scripts = ent.scripts or ( getScripts ent );
  in lib.libpkginfo.hasStageFromScripts stage scripts;

  entHasPrepareScript = entHasStageScript "prepare";
  entHasTestScript    = entHasStageScript "test";
  entHasPackScript    = ent:
    lib.libpkginfo.hasPackFromScripts ( ent.scripts or ( getScripts ent ) );
  entHasPublishScript = ent:
    lib.libpkginfo.hasPublishFromScripts ( ent.scripts or ( getScripts ent ) );
  entHasBuildScript = ent:
    lib.libpkginfo.hasBuildFromScripts ( ent.scripts or ( getScripts ent ) );
  entHasDepScript = ent: let
    scripts = ent.scripts or ( getScripts ent );
  in lib.libpkginfo.hasDepScriptFromScripts scripts;
  entHasInstallScript = ent: let
    fromScript = entHasStageScript "install" ent;
    fromPlock  = ent.hasInstallScript or false;
  in if lib.libmeta.metaWasPlock ent then fromPlock else fromScript;


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
  , hasBin           ? lib.libpkginfo.pjsHasBin ent
  , hasBuild         ? entHasBuildScript ent
  , hasPrepare       ? entHasPrepareScript ent
  , hasInstallScript ? entHasInstallScript ent
  , gypfile          ? false  # XXX: do not read this field from registries
  , hasTest          ? entHasTestScript ent
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
      # FIXME: this no shouldn't be reading the filesystem without being marked
      # as "impure" or "ifd".
      forMeta = ( lib.optionalAttrs ( value ? lockDir ) {
        pjs   = lib.importJSON' ( value.lockDir + "/package.json" );
        plock = lib.importJSON' ( value.lockDir + "/package-lock.json" );
      } ) // value;
    in if name == "__meta" then forMeta else
       if lib.hasPrefix "__" name then value else
       forEnt;
  in lib.libmeta.mkMetaSet ( builtins.mapAttrs deserial members );


# ---------------------------------------------------------------------------- #

  # NOTE: the main difference here in terms of detection is that `resolved' for
  # dir/link entries will be an absolute path.
  # Aside from that we just have extra fields ( `NpmLock.Structs.pkg_*' types
  # ignore extra fields so this is fine ).
  identifyMetaEntFetcherFamily = {
    fetchInfo ? null
  , ffamily   ? null
  , ...
  } @ metaEnt: let
    plent = ( getMetaFiles metaEnt ).plock or null;
  in if ffamily != null then ffamily else
     if fetchInfo != null
     then lib.libfetch.identifyFetchInfoFetcherFamily fetchInfo else
     if plent != null then lib.libplock.identifyPlentFetcherFamily plent else
     throw "identifyMetaEntFetcherFamily: Cannot discern 'fetcherFamily'";


# ---------------------------------------------------------------------------- #

  # Identify Lifecycle "For Any"
  identifyLifecycle = x: let
    fromFi    = throw "identifyLifecycleType: TODO from fetchInfo";
    plent'    = ( getMetaFiles x ).plock or x;
    fromPlent = lib.libplock.identifyPlentLifecycleV3 plent';
  in if builtins.isString x then x else
     if yt.NpmLock.package.check plent' then fromPlent else
     if yt.FlocoFetch.fetched.check x then x.ltype else
     if yt.FlocoFetch.fetch_info_floco.check x then fromFi else
     throw ( "(identifyLifecycle): cannot infer lifecycle type from '"
             "${lib.generators.toPretty { allowPrettyValues = true; } x}'" );


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
    hasBuild         ? ( attrs.ltype != "file" ) && ( entHasBuildScript attrs )
  , hasInstallScript ? entHasInstallScript attrs
  , hasPrepare       ? entHasPrepareScript attrs
  , hasBin           ? lib.libpkginfo.pjsHasBin attrs
  , hasTest          ? entHasTestScript attrs
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

  # `null' means we aren't sure.
  # Input will be normalized to pairs.
  # If `metaEnt' has `directories.bin' we may use IFD in helper routines.
  # TODO: typecheck
  metaEntBinPairs' = { pure, ifd, allowedPaths, typecheck } @ fenv: ent: let
    getBinPairs = lib.libpkginfo.pjsBinPairs' fenv;
    emptyIsNone = ( lib.libmeta.metaWasPlock ent ) ||
                  ( builtins.elem ent.entFromtype ["package.json" "raw"] );
    keep  = {
      ident           = true;
      bin             = true;
      directories.bin = true;
      fetchInfo       = true;
    };
    comm  = builtins.intersectAttrs keep ( ent.__entries or ent );
    asPjs = lib.libpkginfo.pjsBinPairs' fenv comm;
    empty = ! ( ( comm ? bin ) || ( comm ? directories.bin ) );
    src'  = if ( ( ent.fetchInfo.type or "file" ) == "file" ) ||
               ( ! ( ent ? sourceInfo.outPath ) )
            then null
            else { src = ent.sourceInfo.outPath; };
  in if emptyIsNone && empty then {} else
     if comm ? bin then getBinPairs comm else
     if ( comm ? directories.bin ) && ( src' != null ) then getBinPairs src'
                                                       else null;


# ---------------------------------------------------------------------------- #

  # This helper function collects fields used by many `metaEntFrom*' routines
  # that must be read from the filesystem.
  # Most importantly it collects a set of available `metaFiles', which can be
  # used to create an amalgamated `metaEnt' from various inputs.
  tryCollectMetaFromDir' = { pure, ifd, typecheck, allowedPaths } @ fenv:
    pathlike: let
      readAllowed = lib.libread.readAllowed { inherit pure ifd allowedPaths; };
      checkPl = if typecheck then yt.Typeclasses.pathlike pathlike else
                pathlike;
      dir      = lib.coercePath checkPl;
      isDir    = builtins.pathExists ( dir + "/." );
      pjs      = lib.importJSONOr null ( dir + "/package.json" );
      pjsBP    = lib.libpkginfo.pjsBinPairs' fenv;
      binPairs = if pjs == null then null else
                 lib.apply pjsBP ( pjs // { _src = pathlike; } );
      bps'       = if binPairs == null then {} else { bin = binPairs; };
      sourceInfo = let
        pp  = lib.generators.toPretty { allowPrettyValues = true; };
        msg = "tryCollectMetaFromDir: Unsure of how to coerce sourceInfo " +
              "from value '${pp pathlike}'.";
        fromString = if yt.FS.Strings.store_path.check pathlike then {
          outPath = pathlike;
        } else null;
      in if yt.FlocoFetch.source_info_floco.check pathlike then pathlike else
        if pathlike ? outPath then pathlike else
        if builtins.isString pathlike then fromString else
        throw msg;
      sourceInfo' = if sourceInfo == null
                    then { fetchInfo = { type = "path"; path = pathlike; }; }
                    else { inherit sourceInfo; };
      rsl = if ( readAllowed dir ) && isDir then bps' // sourceInfo' // {
        metaFiles = lib.filterAttrs ( _: v: v != null ) {
          inherit pjs;
          plock = lib.importJSONOr null ( dir + "/package-lock.json" );
          metaJ = lib.importJSONOr null ( dir + "/meta.json" );
          metaN =
            if ! ( builtins.pathExists ( dir + "/meta.nix" ) ) then null else
            import ( dir + "/meta.nix" );
        };
        gypfile  = builtins.pathExists ( dir + "/binding.gyp" );
      } else {};
      rsl_hit_t = yt.struct {
        bin        = yt.option yt.PkgInfo.bin_pairs;
        metaFiles  = yt.attrs yt.any;
        gypfile    = yt.bool;
        sourceInfo = yt.option yt.FlocoFetch.Eithers.source_info_floco;
        fetchInfo  = yt.option yt.FlocoFetch.Structs.fetch_info_path;
      };
      rslt = yt.either yt.unit rsl_hit_t;
    in if typecheck then rslt rsl else rsl;


# ---------------------------------------------------------------------------- #

  # Returns lists of `metaEnt' records keyed by `<IDENT>/<VERSION>' associated
  # with any metadata that can be scraped from a directory.
  #
  # In practice you'll want to merge this info before using it, but these
  # unmerged lists are useful for a variety of purposes.
  #
  # If you're a regular user, or aren't looking to get into the ugly details of
  # "how the sausage" is made - you probably want to call `metaSetFromDir'.
  #
  # TODO: meta(Ent|Set)Overlays
  metaSetEntListsFromDir' = { pure, ifd, typecheck, allowedPaths } @ fenv: let
    inner = pathlike: let
      msEmpty = lib.libmeta.mkMetaSet {};
      mfd     = tryCollectMetaFromDir' fenv pathlike;
      # Exactly like `metaSetFromPlockV3' except we unfuck the `key' field.
      mkOnePlV3 = pkey: plent: let
        me = lib.libplock.metaEntFromPlockV3 {
          lockDir         = toString pathlike;
          includeTreeInfo = true;
          inherit pure ifd typecheck allowedPaths;
          inherit (mfd.metaFiles) plock;
          inherit (mfd.metaFiles.plock) lockfileVersion;
        } pkey plent;
      in me // { key = me.ident + "/" + me.version; };
      # This is a "raw" form of the `metaSetFromPlockV3' routine that doesn't
      # require unique entries.
      # In our case we are composing a bunch of entries so we want to work with
      # a list of entries that do not necessarily need to be unique.
      mesPl = if ! ( mfd ? metaFiles.plock ) then [] else
              lib.mapAttrsToList mkOnePlV3 mfd.metaFiles.plock.packages;
      # Also carries any info scraped from the directory ( `gypfile', etc ).
      mePjs = let
        base = lib.libpjs.metaEntFromPjsNoWs' fenv {
          pjsDir  = toString pathlike;
          basedir = pathlike.basedir or ( toString pathlike );
          inherit (mfd.metaFiles) pjs;
        };
      in if ! ( mfd ? metaFiles.pjs ) then null else base.__update mfd;
      mesPjs  = if mePjs == null then [] else [mePjs];
      meMfRaw = mfd.metaFiles.metaN or mfd.metaFiles.metaJ or null;
      mesMf   = let
        fixTree = if ! ( meMfRaw ? __meta.trees ) then meMfRaw else meMfRaw // {
          ${meMfRaw.__meta.rootKey} = meMfRaw.${meMfRaw.__meta.rootKey} // {
            inherit (meMfRaw.__meta) trees;
          };
        };
        proc = key: v: lib.metaEntFromSerial ( { inherit key; } // v );
        ents = lib.mapAttrsToList proc ( removeAttrs fixTree ["__meta"] );
        # `genMeta' writes `__meta.trees.{dev,prod}' which should really be
        # pushed down into the `rootKey' entry.
      in if meMfRaw == null then [] else ents;

      allMetaEnts = mesPl ++ mesPjs ++ mesMf;
      grouped     = builtins.groupBy ( x: x.key ) allMetaEnts;
      members     = grouped // {
        __meta = let
          rootKey =
            if meMfRaw ? __meta.rootKey then meMfRaw.__meta.rootKey else
            if mfd ? metaFiles.pjs then mePjs.key else
            if ! ( mfd ? metaFiles.plock ) then null else
            mfd.metaFiles.plock.name + "/" + mfd.metaFiles.plock.version;
          rootKey' = if rootKey == null then {} else { inherit rootKey; };
        in rootKey' // {
          __serial = false;
          fromType = "directory-composite";
          dir = toString pathlike;
          inherit (mfd) metaFiles;
          # TODO: `bin' and `gypfile' fields aren't processed
          dirInfo = removeAttrs mfd ["metaFiles"];
        };
      };
      ms = lib.libmeta.mkMetaSet members;

      # If we merge entries, we prefer `bin', `hasBin', `ltype', `depInfo',
      # `hasInstallScript', and `fetchInfo' from `package-lock.json', and
      # `scripts', `gypfile', `hasBuild', `hasPrepare', `hasPack', `hasPublish',
      # `hasTest', from `package.json'.
      # NOTE: `package.json' gets priority on `gypfile' even over
      # the filesystem!
      # FIXME: Other routines fuck this ( above NOTE ) up right now.
      # TODO: After that `meta.{json,nix}' clobbering is something we need to
      # sort out; but for now I'm giving them priority to act as overrides.

    in if mfd == {} then msEmpty else ms;
    # TODO: make a real typedef for this.
    rslt = yt.restrict "metaSet" ( x: ( x._type or null ) == "metaSet" )
                                 ( yt.attrs yt.any );
  in if typecheck then yt.defun [yt.Typeclasses.pathlike rslt] inner else inner;


# ---------------------------------------------------------------------------- #

  # This is "in broad strokes" the ranking for which metadata sources we trust
  # over others.
  # This does NOT speak to the quality of specific fields, and without going
  # into the implementation details and progress on data normalization for
  # individual fields/sources - suffice to say this is a generalization.
  cmpMetaEntFroms = let
    # 0      ::= "highest priority"/"most trusted"
    # 999... ::= "total dogshit"/replace with any lower rank option
    fromTypesRank = {
      raw                     = 0;   # Assumed to be explitly defined by user.
      "package.json"          = 5;   # Once normalized this is most accurate.
      "package-lock.json(v2)" = 10;  # Contains more info than v3.
      "package-lock.json(v3)" = 15;  # Actually "better" than v2, but less info.
      "package-lock.json(v1)" = 20;  # Only "better" for pinning dep versions.
      "package-lock.json"     = 25;  # No internal routines mark this.
      # From Registry - this info is often inaccurate
      vinfo     = 50;  # A specific "abbreviated version" record in Packument.
      packument = 60;  # Registry record for all package versions.

      # Not supported/Yarn is garbage and if you're reading this you should
      # migrate your project away from it.
      # It poses real security risks and after months of building support for it
      # in this framework I arrived at the conclusion that, effort aside, it
      # would be ethically wrong to build any tooling that made Yarn even
      # remotely more usable than it was in in 2019 - if you or someone you know
      # is still using Yarn please seek help.
      #
      # It may make sense to support Yarn v1; but let me be clear - this tool
      # was originally designed to support Yarn v2 and v3 BEFORE NPM, and it
      # was after several months of investigating "why are the
      # hashes non-deterministic" that I realized that past Yarn v1 the code
      # quality and security ( particularly regarding checksums ) became
      # completely inexcusible.
      # I'll admit that if I read this exact inline comment a few months ago,
      # I would've said "wow this author sounds like a total crank, come on
      # how bad could it really be?", to which I'd freely admit "look, I might
      # be a kook, but I'm not a crank - go read the Yarn v2/3 sources for
      # generating cache checksums and keys, or read the issue list's responses
      # to 'why did you reimplement zlib?'".
      "yarn.lock"     = throw "WARNING: Yarn is bad for your health.";
      "yarn.lock(v1)" = throw "WARNING: Yarn is bad for your health.";
      "yarn.lock(v2)" = throw "WARNING: Yarn is bad for your health.";
      "yarn.lock(v3)" = throw "WARNING: Yarn is bad for your health.";
      # the number is arbitrary, just ensure that it's always highest.
      _default = 999;
    };
  in a: b:
     fromTypesRank.${a.entFromType or "_default"} -
     fromTypesRank.${b.entFromType or "_default"};

  # returns true if "a <= b" or "a is more trusted than b".
  cmpMetaEntFromsLE = a: b: ( cmpMetaEntFroms a b ) <= 0;

  sortMetaEntriesByRank = builtins.sort cmpMetaEntFromsLE;


# ---------------------------------------------------------------------------- #

  # TODO: `bin' and `gypfile' fields aren't recorded in the ent list.
  # Get the baseline working then figure those out.
  mergeMetaEntList = ents: let
    genericFtype = e: let
      ftype = e.entFromtype;
    in if ftype == "package.json" then "pjs" else
       if lib.hasPrefix "package-lock.json" ftype then "plock" else
       if lib.hasPrefix "yarn.lock" then "ylock" else
      ftype;
    # TODO: this is going to break `plock' entries with conflicting instances.
    byFtype' = builtins.groupBy genericFtype ents;
    byFtype  = builtins.mapAttrs ( _: es:
      builtins.foldl' ( me: e: me.__extend ( _: prev:
        lib.recursiveUpdate e.__entries prev
      ) ) ( builtins.head es )
          ( if 1 < ( builtins.length es ) then builtins.tail es else [] )
    ) byFtype';

    special = {
      bin = values: let
        bps = builtins.filter yt.PkgInfo.bin_pairs.check values;
      in if bps != [] then builtins.head bps else builtins.head values;
      fetchInfo = values:
        byFtype.raw.fetchInfo or byFtype.plock.fetchInfo or
        ( builtins.head values );
      ltype = values:
        byFtype.raw.ltype or byFtype.plock.ltype or ( builtins.head values );
      hasInstallScript = values:
        byFtype.raw.hasInstallScript or
        byFtype.plock.hasInstallScript or
        byFtype.pjs.hasInstallScript or
        ( builtins.head values );
      gypfile = values:
        byFtype.raw.gypfile or byFtype.pjs.gypfile or ( builtins.head values );
      depInfo = values:
        byFtype.raw.depInfo or byFtype.plock.depInfo or
        ( builtins.head values );
      # preserve early fields, but collect from all
      metaFiles = builtins.foldl' ( acc: a: a // acc ) {};
    };

    ranked = sortMetaEntriesByRank ents;
    zipper = field: values:
      if special ? ${field} then special.${field} values else
      builtins.head values;
    zipped = builtins.zipAttrsWith zipper ( map ( e: e.__entries ) ranked );
    nents  = builtins.length ents;
    # TODO: make `composed' `entFromtype'
  in if nents == 0 then null else
     if nents == 1 then builtins.head ents else
     lib.libmeta.mkMetaEnt ( zipped // { entFromtype = "raw"; } );


# ---------------------------------------------------------------------------- #

  metaSetFromDir' = { ifd, pure, allowedPaths, typecheck } @ fenv: let
    inner = pathlike: let
      lists = metaSetEntListsFromDir' fenv pathlike;
    in lists.__extend ( final: prev:
      builtins.mapAttrs ( _: mergeMetaEntList )
                        ( removeAttrs prev ["__meta" "_type"] )
    );
    # TODO: make a real typedef for this.
    rslt = yt.restrict "metaSet" ( x: ( x._type or null ) == "metaSet" )
                                 ( yt.attrs yt.any );
  in if typecheck then yt.defun [yt.Typeclasses.pathlike rslt] inner else inner;


# ---------------------------------------------------------------------------- #

in {
  inherit
    metaEntFromSerial
    metaSetFromSerial
    metaEntIsSimple
    metaSetPartitionSimple  # by `metaEntIsSimple'
  ;

  inherit
    entHasStageScript
    entHasPrepareScript
    entHasInstallScript
    entHasTestScript
    entHasPackScript
    entHasBuildScript
    entHasPublishScript
    entHasDepScript
  ;

  inherit
    identifyLifecycle
    identifyMetaEntFetcherFamily
  ;

  inherit
    getMetaFiles
    getScripts
  ;

  inherit
    metaEntBinPairs'
  ;
  inherit
    tryCollectMetaFromDir'
    metaSetEntListsFromDir'

    cmpMetaEntFroms
    cmpMetaEntFromsLE
    sortMetaEntriesByRank

    mergeMetaEntList
    metaSetFromDir'
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
