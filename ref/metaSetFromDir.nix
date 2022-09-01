# I mostly just like how this handled instances; it came out clean
#
# This was the rough draft of the new `metaSetFromPlockV3' routine but it's
# been parted out mostly.
# The instances wasn't merged yet and I don't want to lose it.
metaSetFromDir = lockDir: let
  plock    = lib.importJSON' "${lockDir}/package-lock.json";
  pjs      = lib.importJSON' "${lockDir}/package.json";

  prodTree = lib.libtree.idealTreePlockV3 {
    inherit plock;
    inherit (final) flocoConfig;
    dev = false;
  };
  devTree = lib.libtree.idealTreePlockV3 {
    inherit plock;
    inherit (final) flocoConfig;
  };

  mkOne = path: ent: let
    ident   = ent.ident or ent.name or ( lib.libplock.pathId path );
    version = ( lib.libplock.realEntry plock path ).version;
    key     = "${ident}/${version}";
    extra =
      ( lib.optionalAttrs ( path == "" ) { pjsEnt = pjs; } ) //
      # Allows fields to be injected before any extensions
      ( final.metaHints.${key} or {} );
    simpleArgs = {
      inherit ident version key lockDir path;
      plockEnt = ent // { pkeys = [path]; };
    } // extra;
    # This gets merged with the real key.
    # We mark `linkFrom' and `linkTo' to avoid loss of detail.
    linkedArgs = {
      inherit ident version key lockDir path;
      plockEnt = ent // {
        links = [{ from = ent.resolved; to = path; }];
      };
    };
  in { ${key} = if ent.link or false then linkedArgs else simpleArgs; };

  ents = lib.mapAttrsToList mkOne plock.packages;
  mergeOne = a: b: ( a // b ) // {
    plockEnt = let
      links = ( a.plockEnt.links or [] ) ++ ( b.plockEnt.links or [] );
    in a.plockEnt // b.plockEnt // {
      pkeys = a.plockEnt.pkeys ++ b.plockEnt.pkeys;
    } // ( lib.optionalAttrs ( links != [] ) { inherit links; } );
  };
  mergeInstances = key: instances: let
    merged = builtins.foldl' mergeOne ( builtins.head instances )
                                      ( builtins.tail instances );
    ectx =
      builtins.addErrorContext "mkMetaSetFromDir:mergeInstances: ${key}"
                                merged;
    me = final.mkMetaEntFromDir ( builtins.deepSeq ectx merged );
  in me;
  metaEntries = builtins.zipAttrsWith mergeInstances ents;
  members = metaEntries // {
    __meta = {
      __serial = false;
      rootKey = "${plock.name}/${plock.version}";
      inherit devTree prodTree pjs plock lockDir;
      fromType = "package-lock.json(v2)";
    };
  };
  base = lib.libmeta.mkMetaSet members;
  ex = base.__extend
        ( lib.composeManyExtensions final.flocoConfig.metaSetOverlays );
in ex;
