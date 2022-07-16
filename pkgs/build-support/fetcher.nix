{ lib
, fetchurl
, fetchgit
, fetchzip
, impure ? ( builtins ? currentTime )
}: let
  inherit (builtins) fetchurl match toJSON head elemAt;


/* -------------------------------------------------------------------------- */

  # Symlink: { resolved :: relative path string, link :: bool }
  #
  # Git ( private and public ):
  #   "resolved": "git+ssh://git@github.com/<owner>/<repo>.git#<rev>",
  #   This URI is consistent regardless of `https://' or other descriptors.
  #   So, if `builtins.match "git\\+.*" entry.resolved != null' you need to run
  #   the `prepare' ( or whatever ) lifecycle scripts.
  typeOfEntry = entry: let
    isLink  = entry.link or false;
    isGit   = entry ? resolved && ( lib.test "git\\+.*" entry.resolved );
    isPath  = ! ( ( entry ? link ) || ( entry ? resolved ) );
    isRegTb =
      ( ( entry ? integrity ) || ( entry ? sha1 ) ) &&
      ( entry ? resolved ) && ( lib.test "http.*\\.tgz" entry.resolved );
  in if isLink  then "symlink"          else
     if isGit   then "git"              else
     if isPath  then "path"             else
     if isRegTb then "registry-tarball" else
     throw "Unrecognized entry type: ${toJSON entry}";


/* -------------------------------------------------------------------------- */

  plockEntryHashAttr = entry: let
    integrity2Sha = integrity: let
      m = match "(sha(512|256|1))-(.*)" integrity;
      shaSet = { ${head m} = elemAt m 2; };
    in if m == null then { hash = integrity; } else shaSet;
    fromInteg = integrity2Sha entry.integrity;
  in if entry ? integrity then fromInteg else
     if entry ? sha1      then { inherit (entry) sha1; } else {};


/* -------------------------------------------------------------------------- */

  # Registry tarball package-lock entry to fetch* arguments
  #
  # Remember that Nix is lazily evaluated, so while this may look like a wasted
  # effort, since we ultimately only use one of these attributes - you need
  # to look at these like "lenses" ( or an object accessor for y'all OOP heads
  # in the audience ).
  #
  # If `impure' is enabled, the `narHash' of the unpacked tarball will be
  # calculated by pre-fetching.
  # This allows the `fetchzip' derivation to be created which is useful if you
  # plan to push/pull from remote binary caches or stores.
  # Ideally you would pre-fetch to define the derivation, then use
  # `nix-store --dump-db ...' or serialize this info with `toJSON' to stash the
  # info to optimize/purify future runs.
  per2fetchArgs = { resolved, ... }@entry: let
    prefetched = if ( ! impure ) then {} else fetchTree bfr;
    nha = plockEntryHashAttr entry;
    # nixpkgs.fetchurl
    nfu = { url = resolved; } // nha;
    # XXX: You cannot use `nixpkgs.fetchzip' without knowing the unpacked hash.
    # If `impure == true' we prefetch and record the hash so that it's possible
    # to push the derivation to a cache - this isn't /really/ that useful in
    # practice, but it is better than not having a DRV at all.
    nfz = { url = resolved; sha256 = prefetched.narHash; };
    # builtins.fetchurl
    bfu = resolved;                               # XXX: Impure
    # builtins.fetchTree
    bfr = { type = "tarball"; url = resolved; };  # XXX: Impure
    # builtins.fetchTarball
    bft = { url = resolved; };                    # XXX: Impure
    flake = bfr // { flake = false; };
    impureArgs = {
      nixpkgs.fetchurl      = nfu;
      nixpkgs.fetchzip      = nfz;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr   // { inherit (prefetched) narHash; };
      builtins.fetchTarball = bft   // { sha256 = prefetched.narHash; };
      flake                 = flake // { inherit (prefetched) narHash; };
    };
    pureArgs = {
      nixpkgs.fetchurl      = nfu;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr;
      builtins.fetchTarball = bft;
      inherit flake;
    };
  in if impure then impureArgs else pureArgs;


/* -------------------------------------------------------------------------- */

  # Pacote/NPM check for the following scripts for Git checkouts:
  #   scripts.build
  #   scripts.preinstall
  #   scripts.install
  #   scripts.postinstall
  #   scripts.prepack     NOTE: I'm getting conflicting info on this. Maybe difference in NPM versions?
  #   scripts.prepare
  # If any are defined, `npm install' is run to get dependencies, then
  # `pacote' passes the checked out directory to `dirFetcher', to `dirFetcher'
  # which is the routine that "really" runs the life-cycle scripts.
  # This is useful to know, because we can follow to same pattern to avoid
  # redundantly implementing a lifecycle driver for local trees and git repos.

  # Git
  peg2fetchArgs = { resolved, ... }@entry: let
    # I'm pretty sure you can pass this "as is" to `fetchTree'.
    # I'm also pretty sure that Eelco implemented `fetchTree' and Flake refs
    # based on NPM's URIs to support Node.js at Target - the commonality is
    # uncanny even for NPM's extended URIs.
    #   0: protocol ( ssh, http(s), etc )
    #   1: host     ( git@github.com, github.com, gitlab.com, etc )
    #   2: owner
    #   3: repo
    #   4: rev
    murl = match "(git+[^:]+)://([^/:]+)[/:]([^/]+)/([^#]+)#(.*)" resolved;
    protocol = head murl;
    host     = elemAt murl 1;
    owner    = elemAt murl 2;
    repo     = elemAt murl 3;
    rev      = elemAt murl 4;

    #
    # NOTE: If a hostname has a `git@' ( ssh ) prefix, it MUST use a ":", not
    #       "/" to separate the hostname and path.
    #       Nix's `fetchGit' and `fetchTree' do not use a ":" here, so replace
    #       it with "/" - if you don't, you'll get an error:
    #       "make sure you have access rights".

    # builtins.fetchGit { url = "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c"; }
    # builtins.fetchTree { type = "git"; url = "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c"; }
    # NOTE: You must provide `type = "git";' for `fetchTree' it doesn't parse
    #       the URI to try and guess ( flake refs will ).
    # NOTE: You must leave the "<path>#<rev>" as is for the builtin fetchers -
    #       a "<path>/<rev>" will not work; but I think flake inputs DO want it
    #       replaced with a "/".
    bfg = { url = "${protocol}://${host}/${owner}/${repo}#${rev}"; };
    bfr = bfg // { type = "git"; };
    prefetched = if ( ! impure ) then {} else fetchTree bfr;
    # You'll still need a SHA here, Nixpkgs won't use the `rev'.
    # I tried fooling with encoding/decoding the `rev' - which "in theory" is
    # related to the repo's checksum; but there's no clear mapping - the
    # removal of the `.git/' may be causing this; but in any case, we can only
    # use `nixpkgs.fetchGit' if we prefetch.
    # XXX: Impure
    nfg = {
      inherit rev;
      url = "${protocol}://${host}/${owner}/${repo}";
      sha256 = prefetched.narHash;
    };
    flake = bfr // { flake = false; };
    impureArgs = {
      nixpkgs.fetchgit   = nfg;
      builtins.fetchTree = bfr   // { inherit (prefetched) narHash; };
      builtins.fetchGit  = bfg   // { inherit (prefetched) narHash; };
      flake              = flake // { inherit (prefetched) narHash; };
    };
    pureArgs = {
      builtins.fetchTree = bfr;
      builtins.fetchGit  = bfg;
      inherit flake;
    };
  in if impure then impureArgs else pureArgs;


/* -------------------------------------------------------------------------- */

  # This is the only fetcher that doesn't take the entry itself.
  # You need to pass the "key" ( relative path to directory ) and CWD instead.
  # NOTE: We intentionally avoid a check like `assert builtins.pathExists abs'
  #       here because these fetchers may be generated before dependant paths
  #       are actually fetched, and if they refer to store paths, they may not
  #       be built yet.
  #       Instead we put faith in the lazy evaluator.
  #       For this same reason, we strongly recommend that you explicitly set
  #       `cwd' because relying on the default of `PWD' makes a BIG assumption,
  #       which is that all of these paths are locally available.
  pkp2fetchArgs = {
    cwd ? ( if impure then builtins.getEnv "PWD"
                      else throw "Cannot determine CWD to resolve path URIs" )
  , key # relative path
  }: let
    cwd' = assert lib.libpath.isAbspath cwd; head ( match "(.*[^/])/?" cwd );
    abs = if ( lib.libpath.isAbspath key ) then key else "${cwd'}/${key}";
  in {
    builtins.path      = { path = abs; };
    builtins.fetchTree = { type = "path"; path = abs; };
    # FIXME: I have no idea if this works.
    flake              = { type = "path"; path = abs; flake = false; };
  };


/* -------------------------------------------------------------------------- */

  # Symlink Relative ( "dirFetcher" in `pacote' taxonomy )
  # NOTE: This fetcher triggers additional lifecycle routines that are not
  #       run for a regular "node_modules/<path>" entry.
  #       We do not trigger life-cycle here, and defer to the caller.
  pel2fetchArgs = {
    cwd ? ( if impure then builtins.getEnv "PWD"
                      else throw "Cannot determine CWD to resolve link URIs" )
  }: { resolved, ... }: pkp2fetchArgs { inherit cwd; key = resolved; };


/* -------------------------------------------------------------------------- */

  pke2fetchArgs = cwd: key: entry: let
    type = typeOfEntry entry;
    cwda = if cwd == null then {} else cwd;
  in if type == "symlink" then pel2fetchArgs cwda entry                   else
     if type == "path"    then pkp2fetchArgs ( { inherit key; } // cwda ) else
     if type == "git"     then peg2fetchArgs entry                        else
     if type == "registry-tarball" then per2fetchArgs entry               else
     throw "Unrecognized entry type for: ${key}";


/* -------------------------------------------------------------------------- */

  # FIXME: For local paths, use `nix-gitignore' or use `fetchTree' at the repo's
  #        top level so that you properly scrub gitignored files.
  # XXX: Handle `.npmignore' files? ( seriously fuck that feature )
  defaultFetchers = pb: pr: let
    defaultFetchTree = {
      urlFetcher  = fa: fetchTree ( fa.builtins.fetchTree or fa );
      gitFetcher  = fa: fetchTree ( fa.builtins.fetchTree or fa );
      linkFetcher = fa: fetchTree ( fa.builtins.fetchTree or fa );
      dirFetcher  = fa: fetchTree ( fa.builtins.fetchTree or fa );
    };
    defaultBuiltins = {
      # FIXME: Prefer `fetchTarball' in impure mode
      urlFetcher  = fa: builtins.fetchurl ( fa.builtins.fetchurl or fa );
      gitFetcher  = fa: builtins.fetchGit ( fa.builtins.fetGit   or fa );
      linkFetcher = fa: builtins.path     ( fa.builtins.path     or fa );
      dirFetcher  = fa: builtins.path     ( fa.builtins.path     or fa );
    };
    defaultNixpkgs = {
      # FIXME: Prefer `fetchzip' in impure mode
      urlFetcher  = fa: fetchurl      ( fa.nixpkgs.fetchurl or fa );
      gitFetcher  = fa: fetchgit      ( fa.nixpkgs.fetchgit or fa );
      linkFetcher = fa: builtins.path ( fa.builtins.path    or fa );
      dirFetcher  = fa: builtins.path ( fa.builtins.path    or fa );
    };
  in if pr then defaultFetchTree else
     if pb then defaultBuiltins  else
     defaultNixpkgs;

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
  , urlFetcher      ? null
  , gitFetcher      ? null
  , linkFetcher     ? null
  , dirFetcher      ? null
  } @ cfgArgs: let
    defaults = defaultFetchers preferBuiltins preferFetchTree;
    config = {
      inherit cwd;
      urlFetcher  = cfgArgs.urlFetcher  or defaults.urlFetcher;
      gitFetcher  = cfgArgs.gitFetcher  or defaults.gitFetcher;
      linkFetcher = cfgArgs.linkFetcher or defaults.linkFetcher;
      dirFetcher  = cfgArgs.dirFetcher  or defaults.dirFetcher;
    };
    doFetch = { cfg }: key: entry: let
      type = typeOfEntry entry;
      fetchArgs = pke2fetchArgs cfg.cwd key entry;
      fetchFn =
      if type == "symlink"          then cfg.linkFetcher else
      if type == "path"             then cfg.dirFetcher  else
      if type == "git"              then cfg.gitFetcher  else
      if type == "registry-tarball" then cfg.urlFetcher  else
      throw "Unrecognized entry type for: ${entry}";
    in fetchFn fetchArgs;
  in lib.makeOverridable doFetch { cfg = config; };


/* -------------------------------------------------------------------------- */

in {
  inherit
    typeOfEntry
    # NOTE: These are really just exposed for niche scenarios, I know the names
    #       are esoteric.
    #       We really want users to call `fetcher' instead of messing with these
    #       "internal" implementations.
    per2fetchArgs
    peg2fetchArgs
    pel2fetchArgs
    pkp2fetchArgs
    pke2fetchArgs    # This is the router.
    defaultFetchers
    fetcher
  ;
}
