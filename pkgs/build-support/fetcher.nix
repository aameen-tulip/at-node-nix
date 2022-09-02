
# XXX: For the record this file is probably going to be deprecated.
# It was written during an early stage of the project before scopes were
# created, and effectively it acts as a miniature scope containing only fetcher
# routines and metadata.
# In all likelihood ( I say from experience ) using this miniature scope will
# cause you more pain than simply writing your own `sourceInfo -> outPath'
# routines from scratch; I wound up writing my own for nearly every project.
# Having said all of this, seeing the defaultFetchers below may provide a useful
# point of reference for designing your own fetchers since they highlight the
# equivalent args across various fetcher implementations.

{ lib
, fetchurlDrv ? lib.fetchurlDrv
, fetchurl  # The Nixpkgs implementation. Not the builtin.
, fetchgit
, fetchzip
, impure ? ( builtins ? currentTime )
} @ globalAttrs:

  # The `typeOf' for `nixpkgs.fetchurl' is a `set', the builtin is a `lambda'.
  assert builtins.typeOf fetchurl == "set";


/* -------------------------------------------------------------------------- */

let

  inherit (builtins) match toJSON head elemAt;
  inherit (lib.libfetch)
    typeOfEntry
    fetcherForType
    plockEntryHashAttr
    plock2EntryFetchArgs
  ;

/* -------------------------------------------------------------------------- */

  # FIXME: For local paths, use `nix-gitignore' or use `fetchTree' at the repo's
  #        top level so that you properly scrub gitignored files.
  # XXX: Handle `.npmignore' files? ( seriously fuck that feature )
  defaultFetchers = {
    defaultFetchTree = {
      urlFetcher     = fa: fetchurlDrv ( fa.lib.fetchurlDrv or fa );
      tarballFetcher = fa: fetchTree ( fa.builtins.fetchTree or fa );
      gitFetcher     = fa: fetchTree ( fa.builtins.fetchTree or fa );
      linkFetcher    = fa: fetchTree ( fa.builtins.fetchTree or fa );
      dirFetcher     = fa: fetchTree ( fa.builtins.fetchTree or fa );
    };
    defaultBuiltins = {
      # FIXME: Prefer `fetchTarball' in impure mode
      urlFetcher     = fa: fetchurlDrv ( fa.lib.fetchurlDrv or fa );
      tarballFetcher = fa: builtins.fetchurl ( fa.builtins.fetchurl or fa );
      gitFetcher     = fa: builtins.fetchGit ( fa.builtins.fetchGit or fa );
      linkFetcher    = fa: builtins.path     ( fa.builtins.path     or fa );
      dirFetcher     = fa: builtins.path     ( fa.builtins.path     or fa );
    };
    defaultNixpkgs = {
      # FIXME: Prefer `fetchzip' in impure mode
      urlFetcher     = fa: fetchurl ( fa.nixpkgs.fetchurl or fa );
      tarballFetcher = fa: fetchurl ( fa.nixpkgs.fetchurl or fa );
      gitFetcher     = fa: fetchgit ( fa.nixpkgs.fetchgit or fa );
      linkFetcher    = fa: builtins.path ( fa.builtins.path or fa );
      dirFetcher     = fa: builtins.path ( fa.builtins.path or fa );
    };
  };

  getPreferredFetchers = preferBuiltins: preferFetchTree:
     if preferFetchTree then defaultFetchers.defaultFetchTree else
     if preferBuiltins  then defaultFetchers.defaultBuiltins  else
     defaultFetchers.defaultNixpkgs;


/* -------------------------------------------------------------------------- */

  # I'll admit that I'm not in love with this.
  # It's definitely appealing to simply say "just use `fetchTree'", but we know
  # that `fetchTree' fails for a small number of registry tarballs, and in
  # practice the inflexibility of fetchers in other tools was one of the issues
  # that led me to create this utility in the first place.
  #
  # TODO:
  # Something a big more clever for argument handling is definitely apppropriate
  # though, rather than multiple attrsets of args you can make one blob of
  # fields that you run through `intersectAttrs' ( similar to `callPackage' ).
  fetcher = {
    cwd             # Directory containing `package-lock.json' used to realpath
  , preferBuiltins  ? false
  , preferFetchTree ? preferBuiltins
  , tarballFetcher  ? null
  , urlFetcher      ? null
  , gitFetcher      ? null
  , linkFetcher     ? null
  , dirFetcher      ? null
  , simple          ? false  # Omits `fetchInfo' in resulting attrset
  } @ cfgArgs: let
    defaults = getPreferredFetchers preferBuiltins preferFetchTree;
    config = {
      inherit cwd;
      urlFetcher     = cfgArgs.urlFetcher     or defaults.urlFetcher;
      tarballFetcher = cfgArgs.tarballFetcher or defaults.tarballFetcher;
      gitFetcher     = cfgArgs.gitFetcher     or defaults.gitFetcher;
      linkFetcher    = cfgArgs.linkFetcher    or defaults.linkFetcher;
      dirFetcher     = cfgArgs.dirFetcher     or defaults.dirFetcher;
    };
    fetcherInfo = config: key: entry: let
      type = typeOfEntry entry;
    in {
      inherit type;
      fetchFn   = fetcherForType config type;
      fetchArgs = plock2EntryFetchArgs config.cwd key entry;
    };
  in config // {
    __functor = self: key: entry: let
      fi = fetcherInfo self key entry;
      fetched = fi.fetchFn fi.fetchArgs;
      fmeta = ( lib.optionalAttrs ( ! simple ) { fetchInfo = fi; } );
      fattrs = if builtins.isString fetched then { outPath = fetched; } else
        if builtins.isAttrs fetched then fetched else
        throw ( "(fetcher) Unexpected return type '${builtins.typeOf fetched}'"
                + " from fetch function" );
    in fattrs;
  };


/* -------------------------------------------------------------------------- */

in { inherit defaultFetchers getPreferredFetchers fetcher; }

/* -------------------------------------------------------------------------- */
