{ lib
, fetchurl
, fetchgit
, fetchFromGithub
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
  #   scripts.postinstall
  #   scripts.build
  #   scripts.preinstall
  #   scripts.install
  #   scripts.prepack
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
    prefetch = if ( ! impure ) then {} else fetchTree bfr;
    # You'll still need a SHA here, Nixpkgs won't use the `rev'.
    # I tried fooling with encoding/decoding the `rev' - which "in theory" is
    # related to the repo's checksum; but there's no clear mapping - the
    # removal of the `.git/' may be causing this; but in any case, we can only
    # use `nixpkgs.fetchGit' if we prefetch.
    # XXX: Impure
    nfg = {
      inherit rev;
      url = "${protocol}://${host}/${owner}/${repo}";
      sha256 = prefetch.narHash;
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

in { inherit per2fetchArgs typeOfEntry; }
