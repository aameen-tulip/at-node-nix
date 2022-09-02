
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

/* -------------------------------------------------------------------------- */

  # FIXME: For local paths, use `nix-gitignore' or use `fetchTree' at the repo's
  #        top level so that you properly scrub gitignored files.
  # XXX: Handle `.npmignore' files? ( seriously fuck that feature )
  defaultFetchers = {
    defaultWrapped = {
      urlFetcher     = lib.libfetch.fetchurlW;
      tarballFetcher = lib.libfetch.fetchTreeW;
      gitFetcher     = lib.libfetch.fetchGitW;
      dirFetcher     = lib.libfetch.pathW;
      linkFetcher    = lib.libfetch.pathW;
    };
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


/* -------------------------------------------------------------------------- */

in { inherit defaultFetchers; }

/* -------------------------------------------------------------------------- */
