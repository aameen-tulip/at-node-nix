# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt  = lib.ytypes // lib.ytypes.Prim // lib.ytypes.Core;
  plt = yt.NpmLock.Structs // yt.NpmLock;

# ---------------------------------------------------------------------------- #
#
# Abstracts builtin fetchers for compatibility with `nixpkgs' forms, and
# identifies the correct fetcher for various types of Node.js/NPM source trees.
#
# ---------------------------------------------------------------------------- #

  # Given a `resolved' URI from a `package-lock.json', ROUGHLY discern its
  # `builtins.fetchTree' source "type".
  # NOTE: this is not exact.
  # For example, `git' may refer to either `git', `github', or `sourcehut'.
  # Selecting the correct fetcher for each subtype is deferred to the fetchers.
  # This rough approximation helps us limit the number of fetchers we require
  # users to define - at a minimum they must define at least the 3 named here.
  identifyResolvedType = r: let
    isPath = ( ! ( lib.liburi.Url.isType r ) ) &&
             ( yt.NpmLock.Strings.relative_file_uri.check r );
    isGit = let
      data = ( lib.liburi.Url.fromString r ).scheme.data or null;
    in ( lib.liburi.Url.isType r ) && ( data == "git" );
    isFile = lib.libstr.isTarballUrl r;
  in if isPath   then { path = r; } else
     if isGit    then { git = r; } else
     if isFile   then { file = r; } else
     throw "(identifyResolvedType) unable to determine type of ${r}";


# ---------------------------------------------------------------------------- #

  # Given a package entry from a `package-lock.json(v[23])', return one of
  # "file", "path", or "git" indicating the source type.
  identifyPlentSourceType = ent: let
    tagged = lib.libtypes.discrTypes {
      path = yt.NpmLock.Structs.pkg_path_v3;
      git  = yt.NpmLock.Structs.pkg_git_v3;
      file = yt.NpmLock.Structs.pkg_tarball_v3;
    } ent;
  in if ! ( ent ? resolved ) then "path" else  # FIXME type is broken
     builtins.head ( builtins.attrNames tagged );


# ---------------------------------------------------------------------------- #

  # FIXME: move to `ak-nix:lib.libenc'.
  tagHash = {
    __functionArgs = {
      shasum    = true;
      sha1      = true;
      sha256    = true;
      sha512    = true;
      md5       = true;
      integrity = true;
      hash      = true;
      narHash   = true;
    };
    __innerFunction = x: let
      h = let
        hfs = builtins.intersectAttrs tagHash.__functionArgs x;
      in if builtins.isString x then x else
         builtins.head ( builtins.attrValues hfs );
      # NOTE: original implementation yanked `m[2]', I think for Nixpkgs hash.
      m = builtins.match "(sha(512|256|1))-(.*)" h;
      # Try to take a shortcut and ID using an SRI prefix.
      fromSri  = { "${builtins.head m}_sri" = h; };
      # Fallback to a full audit.
      fromHash = lib.libtypes.discrTypes {
        inherit (yt.Hash.Strings) sha1_hash sha256_hash sha512_hash md5_hash;
      } h;
    in if m == null then fromHash else fromSri;
    __functor = self: let
      cond = x: let
        vt = lib.libtag.verifyTag x;
        tags = [
          "md5_hash"
          "sha1_sri"   "sha1_hash"
          "sha256_sri" "sha256_hash"
          "sha512_sri" "sha512_hash"
        ];
      in vt.isTag && ( builtins.elem vt.name tags );
      tt = yt.restrict "hash:tagged" cond ( yt.Core.attrs yt.Prim.string );
    in yt.defun [yt.any tt] self.__innerFunction;
  };

# ---------------------------------------------------------------------------- #

  # Essentially an optimized `tagHash'.
  # XXX: I'm unsure of whether or not this works with v1 locks.
  plockEntryHashAttr = {
    __innerFunction = entry:
      if entry ? integrity then tagHash entry.integrity else
      if entry ? sha1      then { sha1_hash = entry.sha1; } else {};
    __functionArgs = { sha1 = true; integrity = true; };
    __functor = self: self.__innerFunction;
  };


# ---------------------------------------------------------------------------- #

  # FIXME: move these
  Sums.hash = yt.sum {
    shasum = yt.Hash.sha1;
    inherit (yt.Hash) md5 sha1 sha256 sha512;
    inherit (yt.Hash.String)
      sha1_hash sha256_hash sha512_hash md5_hash
      sha1_sri sha256_sri sha512_sri
    ;
    narHash   = yt.Strings.sha256_sri;   # FIXME: this uses a different charset
    integrity = yt.eitherN [
      yt.Strings.sha1_sri
      yt.Strings.sha256_sri
      yt.Strings.sha512_sri
    ];
  };

  # path tarball file git github
  # NOTE: `fetchTree { type = "indirect"; id = "foo"; }' works!
  Enums.sourceType = let
    cond = x: ! ( builtins.elem x ["indirect" "sourcehut" "mercurial"] );
  in yt.restrict "floco" cond yt.FlakeRef.Enums.ref_type;

  Structs.sourceInfo = yt.struct "sourceInfo" {
    outPath = yt.FS.store_path;
    narHash = yt.Hash.Strings.sha256_sri;
    # Git/Github/Path
    lastModified     = yt.Prim.int;
    lastModifiedDate = yt.Prim.string;  # FIXME: timestamp
    # Git/Github
    rev      = yt.option yt.Git.rev;
    shortRev = yt.option yt.Prim.string;
    # Git
    revCount   = yt.option yt.Prim.int;
    submodules = yt.option yt.Prim.bool;
  };

  Structs.fetched = yt.struct "fetchedSource" {
    type       = Enums.sourceType;
    outPath    = yt.FS.store_path;
    sourceInfo = Structs.sourceInfo;
    fetchInfo  = yt.attrs yt.any;
    passthru   = yt.option ( yt.attrs yt.any );
    meta       = yt.option ( yt.attrs yt.any );
  };

  # TODO: types
  #   barename ( no extensions )
  #   relpath  ( string + struct )
  #   path     ( sumtype )
  #   file     ( sumtype )
  #   md5 sri
  #   narHash  ( check charset )
  #   git reponame
  #   fetchTree sourceInfo


# ---------------------------------------------------------------------------- #

  # Tarball Fetcher Argsets.

  nixpkgsFetchurlArgs = {
    name          = true;   # defaults to url basename
    url           = false;  # real one is optional but only with `urls = [...]'
    executable    = true;
    recursiveHash = true;   # for a single file choose "false"
    # One of the following
    sha1          = true;
    sha256        = true;
    sha512        = true;
    hash          = true;
    md5           = true;
    # ...
  };

  nixpkgsFetchzipArgs      = { url = false; sha256 = false; };
  builtinsFetchTarballArgs = { url = false; sha256 = false; };
  # XXX: accepts as a string not an attrset.
  builtinsFetchurlArgs = { url = false; };

  # This super-set can support any tarball/file fetcher.
  genericTarballArgs = {
    name  = yt.FS.Strings.filename;
    type  = yt.enum ["file" "tarball"];
    url   = yt.Uri.Strings.uri_ref;
    flake = yt.option yt.bool;
    inherit (Sums) hash;
    unpack     = yt.option yt.bool;
    executable = yt.option yt.bool;
  };


# ---------------------------------------------------------------------------- #

  nixpkgsFetchgitArgs = {
    name = true;
    url  = false;
    # Options
    branchName = true;
    deepClone  = true;
    fetchLFS   = true;
    fetchSubmodules = true;
    leaveDotGit     = true;
    sparseCheckout  = true;
    # One of
    hash   = true;
    sha256 = true;
    md5    = true;
    rev    = true;
    # ...
  };

  builtinsFetchgitArgs = {
    url     = false;
    rev     = true;  # can be parsed from URL
    allRefs = true;  # Defaults to false
    shallow = true;  # "deepClone"
  };


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
  genericGitArgFields = {
    name  = yt.FS.Strings.filename;  # for `nixpkgs.fetchgit' this is the outdir
    type  = yt.enum ["git" "github" "sourcehut"];
    url   = yt.FlakeRef.Strings.git_ref;
    flake = yt.bool;
    inherit (yt.Git) rev ref;  # `branchName' is alias of `ref' for `nixpkgs'
    inherit (Sums) hash;   # nixpkgs accepts a slew of options.
    allRefs    = yt.bool;  # nixpkgs: sparseCheckout
    submodules = yt.bool;  # nixpkgs: fetchSubmodules
    shallow    = yt.bool;  # nixpkgs: deepClone?
    repo       = yt.Git.Strings.ref_component;
    owner      = yt.Git.Strings.owner;
  };

  genericGitArgs' = pure: let
    checkPresent = x: let
      comm = builtins.intersectAttrs x genericGitArgFields;
    in builtins.all ( k: comm.${k}.check x.${k} ) ( builtins.attrNames comm );
    minimal = x: builtins.all ( p: p ) [
      # `builtins.fetchTree { type = "github"; }' uses `{ owner, repo }'.
      ( ( x.type or null ) == "github" -> ( x ? owner ) && ( x ? repo ) )
      # Everything else requires a URL.
      ( ( x.type or null ) != "github" -> x ? url )
      # Require purifying info when `pure == true'.
      ( pure && ( builtins.elem ( x.type or null ) ["github" "git"] )
        ->
        ( x ? rev ) || ( x ? hash.narHash ) ||
        ( ( x.type == "github" ) && ( x ? ref ) ) )
      # `builtins.fetchGit' requires `rev' in pure mode.
      ( pure && ( ! ( x ? type ) ) -> ( x ? hash ) || ( x ? rev ) )
    ];
    tname = "fetchInfo:generic:git:${if pure then "" else "im"}pure";
    cond = x: ( checkPresent x ) && ( minimal x );
  in yt.restrict tname cond ( yt.attrs yt.any );


  genericGitArgsPure   = genericGitArgs' true;
  genericGitArgsImpure = genericGitArgs' false;


# ---------------------------------------------------------------------------- #

  # FIXME: move to `rime'.
  isGithubUrl = url:
    lib.test "([^@]+@)?github\\.com" ( lib.liburi.parseFullUrl url ).authority;

  parseGitUrl = {
    __functionArgs.url = false;
    __innerFunction = { url }: let
      parsed = lib.liburi.parseFullUrl url;
      hp     = lib.liburi.parseServer parsed.authority;
      repo = let
        m = builtins.match "(.*)\\.git.*" ( baseNameOf parsed.path );
      in if m == null then baseNameOf parsed.path else builtins.head m;
    in {
      inherit repo url;
      inherit (parsed.scheme) transport;
      type = if baseNameOf hp.hostport == "github" then "github" else "git";
      user = hp.userinfo;
      host = hp.hostport;
      # XXX: There's a good chance you're going to bad results for any
      # non-github hosts; but there's no real use case for the `owner' field
      # outside of `github' so fuck it.
      owner = let
        s  = builtins.split "/${repo}\\.git" parsed.path;
        s0 = builtins.head s;
        d = if s0 == "" then dirOf parsed.path else s0;
      in baseNameOf d;
      # FIXME: I think flake-ref do `.../foo.git/<REV>?<QUERY>`
      rev = if parsed.fragment != null then parsed.fragment else
        if ( lib.test ".*rev=.*" parsed.query )
        then ( lib.liburi.parseQuery parsed.query ).rev
        else null;
      # FIXME: ref
    };
    __processArgs = self: x:
      if builtins.isString x then { url = x; } else {
        url = x.url or x.resolved;
      };
    __functor = self: args:
      self.__innerFunction ( self.__processArgs self args );
  };


# ---------------------------------------------------------------------------- #

  # NOTE: the fetcher for `git' entries need to distinguish between `git',
  # `github', and `sourcehut' when processing these args.
  # They should not try to interpret the `builtins.fetchTree' type using
  # `identify(Resolved|PlentSource)Type' which conflates all three `git' types.
  # XXX: I'm not sure we can get away with using `type = "github";' unless we
  # are sure that we know the right `ref'/`branch'. Needs testing.
  plockEntryToGenericGitArgs = let
    inner = { resolved, ... } @ args: let
      inherit (parseGitUrl resolved) owner rev repo type;
      allRefs' = let
        bname         = baseNameOf ( args.ref or "refs/heads/HEAD" );
        defaultBRefs  = ["HEAD" "master" "main"];
        preferAllRefs = ! ( builtins.elem bname defaultBRefs );
      in if type == "github" then {} else {
        allRefs = args.allRefs or preferAllRefs;
      };
    in {
      inherit type repo owner rev;
      name = repo;
      url  = resolved;
    } // allRefs';
  in yt.defun [yt.NpmLock.Structs.pkg_git_v3 genericGitArgsPure] inner;


# ---------------------------------------------------------------------------- #

  fetchGitW = {
    __functionArgs = {
      url        = false;
      name       = true;
      allRefs    = true;
      shallow    = true;
      submodules = true;
      # Depends on pure mode
      rev = true;
      ref = true;
    };

    __thunk   = {
      submodules = false;
      shallow    = false;
      allRefs    = true;
    };

    __innerFunction = builtins.fetchGit;

    __processArgs = self: args: let
      args' = if ! ( yt.NpmLock.Structs.pkg_git_v3.check args ) then args else
              plockEntryToGenericGitArgs args;
    in builtins.intersectAttrs self.__functionArgs ( self.__thunk // args' );

    __functor = self: args:
      self.__innerFunction ( self.__processArgs self args );
  };


# ---------------------------------------------------------------------------- #

  # XXX: This is NOT compatible with `type = "github";'.
  fetchTreeGitW = {
    __functionMeta = {
      name     = "fetchTreeGitW";
      argTypes = let
        # FIXME: allow other types of args like attrsets.
        # NOTE: `__processArgs' already allows NPM lock entries to be used.
        # Currently we don't typecheck base on `argTypes' so this is fine.
        ftga = yt.struct {
          url     = yt.FlakeRef.Strings.git_ref;  # FIXME: "SERVER[:/]OWNER"
          type    = yt.option ( yt.enum ["git"] );
          narHash = yt.option yt.Hash.Strings.sha256_sri;
          rev     = yt.option yt.Git.rev;
          ref     = yt.option yt.Git.ref;
          allRefs = yt.option yt.bool;
          shallow = yt.option yt.bool;
          submodules = yt.option yt.bool;
        };
      in [ftga];
    };

    __functionArgs = {
      url        = false;
      type       = true;
      allRefs    = true;
      shallow    = true;
      submodules = true;
      # One of the following is required in pure mode.
      rev     = true;
      ref     = true;
      narHash = true;
    };

    __innerFunction = builtins.fetchTree;

    __thunk = fetchGitW.__thunk // { type = "git"; };

    __processArgs = self: args: let
      args' = if ! ( yt.NpmLock.Structs.pkg_git_v3.check args ) then args else
              plockEntryToGenericGitArgs args;
    in builtins.intersectAttrs self.__functionArgs ( self.__thunk // args' );

    __processResult = self: {
      outPath
    , narHash
    , lastModified
    , lastModifiedDate
    , rev
    , shortRev
    # Only for `type = "git"', not `type = "github"'. Others are common.
    , revCount
    , submodules
    } @ sourceInfo: {
      type = "git";
      inherit outPath sourceInfo;
    };

    __functor = self: args: let
      fetchInfo = self.__processArgs self args;
      result    = self.__processResult self ( self.__innerFunction fetchInfo );
    in result // { inherit fetchInfo; };
  };


# ---------------------------------------------------------------------------- #

  # FIXME: This shouldn't be trying to reinterpret args specific to plent.
  fetchTreeGithubW = {
    __functionMeta = {
      name     = "fetchTreeGithubW";
      argTypes = let
        # NOTE: `__processArgs' already allows NPM lock entries to be used.
        ftgha = yt.struct {
          type     = yt.option ( yt.enum ["github"] );
          owner    = yt.Git.owner;
          repo     = yt.Git.Strings.ref_component;
          # In pure mode you need at least one:
          narHash  = yt.option yt.Hash.Strings.sha256_sri;
          rev      = yt.option yt.Git.rev;
          ref      = yt.option yt.Git.ref;
          # NOTE: `shortRev' appears in `sourceInfo' but doesn't work as an arg.
        };
      in [ftgha];
    };

    __functionArgs = {
      type    = true;
      owner   = false;
      repo    = false;
      # One of the following is required in pure mode.
      narHash = true;
      rev     = true;
      ref     = true;
    };

    __innerFunction = builtins.fetchTree;

    __thunk = { type = "github"; };

    __processArgs = self: args: let
      # FIXME: this ain't going to cover `https://github.com' and other shit
      # that it absolutely should cover.
      pargs = let
        parsed = parseGitUrl args;
        core = {
          owner = args.owner or parsed.owner;
          repo  = args.repo or args.name or parsed.repo;
        };
        opt = let
          rev = args.rev or parsed.rev or null;
          fallbackRef = if rev == null then "refs/heads/HEAD" else null;
        in lib.filterAttrs ( _: v: v != null ) {
          inherit rev;
          ref     = args.ref or fallbackRef;
          narHash = args.narHash or args.sha256 or null;
        };
      in core // opt;
      args' = if ! ( yt.NpmLock.Structs.pkg_git_v3.check args ) then pargs else
              plockEntryToGenericGitArgs args;
    in builtins.intersectAttrs self.__functionArgs ( self.__thunk // args' );

    __processResult = self: {
      latModified
    , lastModifiedDate
    , narHash
    , outPath
    , rev
    , shortRev
    } @ sourceInfo: {
      type = "github";
      inherit outPath sourceInfo;
    };

    __functor = self: args: let
      fetchInfo = self.__processArgs self args;
      result    = self.__processResult self ( self.__innerFunction fetchInfo );
    in result // { inherit fetchInfo; };
  };


# ---------------------------------------------------------------------------- #

  # Takes `genericGitArgFields' as its second argument.
  # In pure mode we really get choosy based on which type of `hash' or `rev'
  # was provided.
  # Returns a flake-ref URI for non-builtins.
  pickGitFetcherFromArgs' = pure: args: let
    hash = args.hash or ( lib.apply tagHash args );
    pMissingRev = pure && ( ! ( args ? rev ) );
    # In pure mode we can fetch without `rev' if `narHash' is given.
    pMissingNarHash = pure && ( ! ( hash ? narHash ) );
    isGithub        = isGithubUrl args.url;
    preferFTGithub  = ( args ? owner ) || ( args ? repo ) || isGithub;
    ftg = if preferFTGithub then fetchTreeGithubW else fetchTreeGitW;
  in if pMissingRev && pMissingNarHash then "nixpkgs#fetchgit" else
     if pMissingNarHash then ftg else
     # Regardless of purity, if a hash is given we'll assume the user meant for
     # us to take advantage of it using `nixpkgs#fetchgit'.
     if args ? hash then "nixpkgs#fetchgit" else
     # Try to use `fetchTree{ type = "github"; }' whenver possible.
     if preferFTGithub then fetchTreeGithubW else
     fetchGitW;

  pickGitFetcherFromArgsPure   = pickGitFetcherFromArgs' true;
  pickGitFetcherFromArgsImpure = pickGitFetcherFromArgs' false;


# ---------------------------------------------------------------------------- #

  # FIXME: use `pickGitFetcherFromArgs'
  # FIXME: hashes
  flocoGitFetcher = {
    __processArgs = self: arg: let
      parsed = parseGitUrl arg;
      inherit (parsed) owner rev repo host url type;
    in {
      fetcher = if parsed.type == "github" then fetchTreeGithubW else
                if arg ? type then fetchTreeGitW else fetchGitW;
      fetchInfo = lib.filterAttrs ( _: v: v != null ) parsed;
      original  = arg;
    };

    __innerFunction = { fetcher, fetchInfo, original }: let
      args = fetchInfo //
             ( if builtins.isString original then {} else original );
    in fetcher args;

    __functor = self: args:
      self.__innerFunction ( self.__processArgs self args );
  };


# ---------------------------------------------------------------------------- #

  builtinsPathArgs = {
    name   = yt.FS.Strings.filename;
    path   = yt.FS.abspath;
    filter = yt.function;
  };

  genericPathArgs = {
    inherit (builtinsPathArgs) name path filter;
    type  = yt.enum ["path"];
    flake = yt.bool;
    url   = yt.FlakeRef.Strings.path_ref;
    # I made these up
    basedir = yt.FS.abspath;
    relpath = yt.NpmLock.relative_file_uri;  # FIXME: move this type
  };


# ---------------------------------------------------------------------------- #

  # Wraps `fetchurlDrv'.
  # Since it isn't technically a builtin this wrapper is really just for
  # consistency with the other wrappers.
  # NOTE: You can't avoid unpacking in a platform dependant way in pure mode;
  # with that in mind the best we can do is fetch the tarball and pass a message
  # for builders to handle later.
  # We add the field `needsUpack = true' in pure mode.
  # In practice the best thing to do is to override this fetcher in pure mode
  # in your config.
  fetchurlDrvW = {
    #__functionArgs = hashFields // { name = true; url = false; };
    __functionArgs = ( lib.functionArgs lib.fetchurlDrv ) // {
      unpackAfter = true;  # Allows acting as a `tarballFetcher' in pure mode.
    };

    __thunk = {
      unpack           = false;
      unpackAfter      = false;
      allowSubstitutes = true;
    };

    __innerFunction = lib.fetchurlDrv;

    __processArgs = self: args: let
      args' = removeAttrs ( self.__thunk // args ) ["unpackAfter"];
    in builtins.intersectAttrs self.__functionArgs args';

    # Call inner without `unpackAfter' arg, preserving it as a tag in our result
    __functor = self: args: let
      fetched = self.__innerFunction ( self.__processArgs self args );
      # Unpack
      unpacked      = builtins.fetchTarball { url = fetched.outPath; };
      unpackedFull  = unpacked // { passthru.tarball = fetched; };
      doUnpackAfter = args.unpackAfter or self.__thunk.unpackAfter;
    in if doUnpackAfter then unpackedFull else fetched;
  };

  fetchurlUnpackDrvW     = fetchurlDrvW // { __thunk.unpackAfter = true; };
  fetchurlNoteUnpackDrvW = fetchurlDrvW // {
    __functor = self: args:
      ( fetchurlDrvW.__functor self args ) // { needsUnpack = true; };
  };


# ---------------------------------------------------------------------------- #

  # Wraps `builtins.path' and automatically filters out `node_modules/' dirs.
  # You can always wipe out or redefine that filter.
  # When using this with relative paths you need to set `cwd' to an absolute
  # path before calling:
  #   ( lib.pathW // { __thunk.cwd = toString ./../../foo; }  ) "./baz"
  #   or
  #   let fetchFromFoo = lib.pathW // { __thunk.cwd = toString ./../../foo; };
  #   in builtins.mapAttrs
  #
  # NOTE: If you pass an attrset with `outPath' or `path.outPath' as your args,
  # this is essentially an accessor that just returns that `outPath'.
  # The rationale for this is that it allows users to set `sourceInfo.path' to
  # a derivation using `sourceInfo.type = "path";' as a way to override sources
  # in `metaEnt' data ( this still applies `filter' if it is defined ).
  # If `outPath' is an arg no filtering is applied; the path it taken "as is",
  # which helps avoid needlessly duplicating store paths.
  pathW = {
    __functionArgs = {
      name      = true;
      path      = true;
      filter    = true;
      recursive = true;
      sha256    = true;
      cwd       = false;  # FIXME: remove this and put in `flocoPathFetcher'
    };

    __thunk = {
      filter = name: type: let
        bname = baseNameOf name;
      in ( type == "directory" -> ( bname != "node_modules" ) ) &&
         ( lib.libfilt.genericFilt name type );
    };

    __innerFunction = builtins.path;

    __processArgs = self: args: let
      # NOTE: `path' may be a set in the case where it is a derivation; so in
      # order to pass to `builtins.path' we need to make it a string.
      p = args.path or args.resolved or args.outPath or "";
      # Coerce an abspath
      path = if lib.libpath.isAbspath p then p else
             "${args.cwd or self.__thunk.cwd}/${p}";
      name  = args.name or ( baseNameOf p );
      args' = ( removeAttrs args ["cwd"] ) // { inherit name path; };
    in builtins.intersectAttrs self.__functionArgs args';

    __functor = self: args:
      self.__innerFunction ( self.__processArgs self args );
  };


# ---------------------------------------------------------------------------- #

  # The `type = "path"' form of `builtins.fetchTree'.
  # The only change here is we don't require `type' to be specified explicitly,
  # and if additional fields appear in our argset we ignore them.
  # Returns a set `{ type = "path"; sourceInfo = {...}; fetchInfo = {...}; }'.
  fetchTreePathW = {
    __functionMeta = {
      name = "fetchTreePathW";
      argTypes = let
        ftpa = yt.struct {
          type    = yt.option ( yt.enum ["path"] );
          path    = yt.FS.abspath;
          narHash = yt.option yt.Hash.Strings.sha256_sri;
        };
      in [ftpa];
    };

    __functionArgs = {
      type    = true;
      path    = false;
      narHash = lib.flocoConfig.enableImpureFetchers;  # XXX: Probably FIXME
    };

    __innerFunction = builtins.fetchTree;

    __processArgs = self: {
      path
    , type    ? "path"
    , narHash ? null
    , ...
    } @ args: let
      opt = if args ? narHash then { inherit narHash; } else {};
    in assert type == "path";
       { inherit type path; } // opt;

    __processResult = self: {
      latModified
    , lastModifiedDate
    , narHash
    , outPath
    } @ sourceInfo: { inherit outPath sourceInfo; type = "path"; };

    __functor = self: args: let
      fetchInfo = self.__processArgs self args;
      result    = self.__processResult self ( self.__innerFunction fetchInfo );
    in result // { inherit fetchInfo; };
  };



# ---------------------------------------------------------------------------- #

  # FIXME: don't wrap output here do that in `flocoFetch*'.
  fetchTreeW = {
    __functionArgs = {
      # Common
      type    = false;
      narHash = true;
      # `file'/`tarball'/`git' mode
      url = true;
      # `git'/`github' mode
      rev = true;
      ref = true;
      # `git' mode
      allRefs    = true;
      shortRev   = true;
      shallow    = true;
      submodules = true;
      # `github' mode
      owner = true;
      repo  = true;
      # `path' mode
      path = true;
    };

    # Copy the thunk from other fetchers.
    inherit (fetchGitW) __thunk;

    __innerFunction = builtins.fetchTree;

    __processArgs = self: { type, ... } @ args: let
      # Reform `__functionArgs' to reflect given type.
      fa = if builtins.elem type ["tarball" "file"] then {
        url = false;
        # FIXME: only network URLs need `narHash'.
        #narHash = lib.flocoConfig.enableImpureFetchers;
      } else throw "Unrecognized `fetchTree' type: ${type}";
      fc = { type = false; narHash = true; };
      # Force `type' to appear, and inject the thunk from ``
      args' = args // { inherit type; };
    in builtins.intersectAttrs ( fa // fc ) args';

    __functor = self: { type, ... } @ args: let
      fetchInfo  = self.__processArgs self args;
      sourceInfo = self.__innerFunction fetchInfo;
    in if type == "path"   then fetchTreePathW args else
       if type == "github" then fetchTreeGithubW args else
       if type == "git"    then fetchTreeGitW args else
       { inherit fetchInfo sourceInfo type; inherit (sourceInfo) outPath; };
  };


# ---------------------------------------------------------------------------- #

  # A wrapper for your wrapper.
  # This pulls fetchers from your `flocoConfig', and routes inputs to the
  # proper fetcher.
  # Largely relies on `entSubtype', `entries.plock', and `sourceInfo' data.
  # You likely want to create a fetcher for each `lockDir'/`metaSet'; but it
  # will check `entries.plock.lockDir' as a fallback.
  #
  # The following examples will handle `cwd' properly for "dir"/path and
  # "link"/symlink fetchers:
  #   let
  #     lockDir      = toString ../../foo;
  #     plock        = lib.importJSON' "${lockDir}/package-lock.json";
  #     flocoFetcher = lib.mkFlocoFetcher { cwd = lockDir; };
  #   in builtins.mapAttrs ( _: flocoFetcher ) plock.packages
  #
  # With `metaSet' it'll figure out `cwd' from the `entries.plock' attrs.
  #   let
  #     flocoFetcher = lib.mkFlocoFetcher {};
  #     metaSet = lib.libmeta.metaSetFromPlockV3 { lockDir = toString ./.; }
  #   in builtins.mapAttrs ( _: flocoFetcher ) metaSet.__entries
  #
  mkFlocoFetcher = {
    tarballFetcher ? fetchers.tarballFetcher
  , fileFetcher    ? fetchers.fileFetcher
  , gitFetcher     ? fetchers.gitFetcher
  , pathFetcher    ? fetchers.pathFetcher
  , fetchers       ? lib.recursiveUpdate lib.libcfg.defaultFlocoConfig.fetchers
                                         ( flocoConfig.fetchers or {} )
  , flocoConfig          ? lib.flocoConfig
  , enableImpureFetchers ? flocoConfig.enableImpureFetchers
  , allowSubstitutes     ? flocoConfig.allowSubstitutedFetchers or true
  , cwd                  ? throw "You must set cwd for relative path fetching"
  } @ cargs: {
    fetchers = {
      # We don't carry pure/impure past argument handling because we're actually
      # going to fetch.
      inherit
        pathFetcher
        gitFetcher
        tarballFetcher
        fileFetcher
      ;
    };
    inherit cwd;

    # FIXME: a hot mess over here.
    # FIXME: refer to `fetchInfo' not `sourceInfo'.
    __innerFunction = fetchers: args: let
      sourceInfo = if args ? type then args else args.sourceInfo or {};
      plent = if yt.NpmLock.package.check args then args else
              args.entries.plock;
      type = args.type or sourceInfo.type or ( identifyPlentSourceType plent );
      cwd'  =
        if type  != "path"  then {} else
        if args  ?  cwd     then { __thunk.cwd = args.cwd; }      else
        if plent ?  lockDir then { __thunk.cwd = plent.lockDir; } else
        {};
      fetcher = fetchers."${type}Fetcher" // cwd';
      args' = if sourceInfo != {} then sourceInfo else plent;
      fetched = fetcher ( { inherit type; } // args' );
    # Don't refetch if `outPath' is defined.
    in if sourceInfo ? outPath then sourceInfo else fetched;

    __functor = self: args:
      self.__innerFunction self.fetchers ( args // { inherit (self) cwd; } );
  };

# ---------------------------------------------------------------------------- #

in {
  inherit
    identifyResolvedType
    identifyPlentSourceType
    plockEntryHashAttr

    # Git stuff
    pickGitFetcherFromArgsPure pickGitFetcherFromArgsImpure
    plockEntryToGenericGitArgs
    fetchTreeGitW fetchTreeGithubW
    fetchGitW
    flocoGitFetcher

    fetchTreePathW

    fetchTreeW pathW

    fetchurlDrvW fetchurlUnpackDrvW fetchurlNoteUnpackDrvW
    mkFlocoFetcher
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
