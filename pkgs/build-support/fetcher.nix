{ lib
, fetchurl
, fetchgit
, fetchFromGithub
, fetchzip
, impure ? ( builtins ? currentTime )
}: let
  inherit (builtins) fetchurl;


/* -------------------------------------------------------------------------- */

  plockEntryHashAttr = entry: let
    integrity2Sha = integrity: let
      m = builtins.match "(sha(512|256|1))-(.*)" integrity;
      shaSet = { ${builtins.head m} = ${builtins.elemAt m 2}; };
    in if m == null then { hash = integrity; } else shaSet;
    fromInteg = integrity2Sha entry.integrity;
  in if entry ? integrity then fromInteg else
     if entry ? sha1      then { inherit (entry) sha1; } else {};


/* -------------------------------------------------------------------------- */

  # Registry tarball package-lock entry to fetch* arguments
  per2fetchArgs = { resolved, ... }@entry: let
    prefetched = if ( ! impure ) then {} else fetchTree bft;
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
    impureArgs = {
      nixpkgs.fetchurl      = nfu;
      nixpkgs.fetchzip      = nfz;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr // { inherit (prefetched) narHash; };
      builtins.fetchTarball = bft // { sha256 = prefetched.narHash; };
    };
    pureArgs = {
      nixpkgs.fetchurl      = nfu;
      builtins.fetchurl     = bfu;
      builtins.fetchTree    = bfr;
      builtins.fetchTarball = bft;
    };
  in if impure then impureArgs else pureArgs;


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
     throw "Unrecognized entry type: ${builtins.toJSON entry}";


/* -------------------------------------------------------------------------- */

in null
