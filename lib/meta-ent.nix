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
  in if args ? entries then builtins.trace msg ( builtins.attrValues entries )
                       else builtins.attrValues metaFiles;

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
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
