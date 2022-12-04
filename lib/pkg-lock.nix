# ============================================================================ #
#
# Routines related to scraping `package-lock.json' data.
#
# TODO: work out a way to integrate `allowPjsReads = true' or equivalent
# setting to allow `meta(Ent|Set)FromPlockV[13]' to scrape local trees'
# `package.json' info.
# The legacy routines did this without asking which was bad, but we from the
# perspective of the caller it makes sense to read that info as long as they've
# permitted it explicitly.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Prim // lib.ytypes.Core;
  inherit (lib.libdep) pinnableFields;
  inherit (lib.libfunk) mkFunkTypeChecker;

# ---------------------------------------------------------------------------- #

  # Because `package-lock.json(V2)' supports schemas v1 and v3, these helpers
  # shorten schema checks.

  supportsPlV1 = yt.NpmLock.plock_supports_v1.check;
  supportsPlV3 = yt.NpmLock.plock_supports_v3.check;


# ---------------------------------------------------------------------------- #

  # Given a package entry from a `package-lock.json(v[23])', return the entry
  # "tagged" as "file", "path", or "git" indicating the fetcher family to be
  # used by `flocoFetch'.
  #   discrPlentFetcherFamily { link = true; resolved = "../foo"; }
  #   => { path = { link - true; resolved = "../foo"; }; }
  discrPlentFetcherFamily = lib.libtypes.discrTypes {
    git  = yt.NpmLock.Structs.pkg_git_v3;
    file = yt.NpmLock.Structs.pkg_file_v3;
    path = yt.NpmLock.Structs.pkg_path_v3;
  };

  # Just returns the tag name.
  identifyPlentFetcherFamily = ent: lib.tagName ( discrPlentFetcherFamily ent );


# ---------------------------------------------------------------------------- #

  # These are the "source types" recognized by NPM.
  # We refer to them as "lifecycle types" because in this context we are
  # strictly interested in the way NPM treats different types of sources when
  # triggering "lifecycle scripts".
  #
  # FIXME: `file:/' needs to be "file".
  discrPlentLifecycleV3' = lib.libtypes.discrTypes {
    git  = yt.NpmLock.Structs.pkg_git_v3;
    file = yt.NpmLock.Structs.pkg_file_v3;
    link = yt.NpmLock.Structs.pkg_link_v3;
    dir  = yt.NpmLock.Structs.pkg_dir_v3;
  };

  discrPlentLifecycleV3 =
    yt.defun [yt.NpmLock.package yt.NpmLock.Sums.tag_lifecycle_plent]
             discrPlentLifecycleV3';


# ---------------------------------------------------------------------------- #

  identifyPlentLifecycleV3' = plent: let
    plentFF = lib.libplock.identifyPlentFetcherFamily plent;
  in if plentFF != "path" then plentFF else
     if lib.hasPrefix "file:" ( plent.resolved or "" ) then "file" else
     if plent.link or false then "link" else "dir";

  identifyPlentLifecycleV3 =
    yt.defun [yt.NpmLock.package yt.FlocoFetch.Sums.tag_lifecycle_plent]
             identifyPlentLifecycleV3';


# ---------------------------------------------------------------------------- #

  # URL

  # NOTE: works for either "file" or "tarball".
  # You can pick a specialized form using the `postFn' arg.
  # I recommend `asGeneric*ArgsImpure' here since those routines
  # doesn't use a real type checker.
  # They just have an assert that freaks out if you're missing a hash field.
  # Our inner fetchers will catch that anyway so don't sweat it.
  plockEntryToGenericUrlArgs' = {
    ifd, pure, typecheck, allowedPaths
  } @ fenv: { postFn ? ( x: x ) }: let
    inner = {
      resolved
    , sha1_hash ? plent.sha1 or plent.shasum or null
    , integrity ? null  # Almost always `sha512_sri` BUT NOT ALWAYS!
    , ...
    } @ plent: let
      rough   = { url = resolved; inherit sha1_hash integrity; };
      prep    = lib.filterAttrs ( _: x: x != null ) rough;
      generic = lib.libfetch.asGenericUrlArgsImpure prep;
    in removeAttrs generic ["flake" "sha"];

    rtype = let
      # Typecheck generic arg fields ( optional ).
      cond = x: let
        # Collect matching typecheckers and run them as we exit.
        # The outer checker can just focus on fields.
        tcs  = builtins.intersectAttrs x lib.libfetch.genericUrlArgFields;
        proc = acc: f: acc && ( tcs.${f}.check x.${f} );
      in builtins.foldl' proc true ( builtins.attrNames tcs );
    in yt.restrict "fetchInfo:generic:url:rough" cond ( yt.attrs yt.any );
    # Configured functor based on `typecheck' setting.
    funk = {
      __functionMeta = {
        name = "plockEntryToGenericUrlArgs";
        from = "at-node-nix#lib.libplock";
        properties = { pure = true; inherit typecheck; };
        signature = [yt.NpmLock.Structs.pkg_file_v3 rtype];
      };
      __functionArgs.resolved  = false;
      __functionArgs.integrity = true;
      __functionArgs.sha1      = true;
      __functionArgs.shasum    = true;
      __innerFunction = inner;
      __functor = self: args: let
        result  = self.__innerFunction args;
        checked =
          if ! typecheck then result else
          ( self.__typeCheck self { inherit args result; } ).result;
      in postFn checked;
    };
    typechecker' = if typecheck then { __typeCheck  = mkFunkTypeChecker; }
                                else { _typeChecker = mkFunkTypeChecker funk; };
  # Even if `typecheck' is false we will stash a partially applied typechecker
  # as a field that can run without the functor.
  in funk // typechecker';


# ---------------------------------------------------------------------------- #

  # GIT

  # NOTE: the fetcher for `git' entries need to distinguish between `git',
  # `github', and `sourcehut' when processing these args.
  # They should not try to interpret the `builtins.fetchTree' type using
  # `identify(Resolved|Plen)FetcherFamily' which conflates all three
  # `git' types.
  # XXX: I'm not sure we can get away with using `type = "github";' unless we
  # are sure that we know the right `ref'/`branch'. Needs testing.
  plockEntryToGenericGitArgs' = {
    ifd, pure, typecheck, allowedPaths
  } @ fenv: { postFn ? ( x: x ) }: let
    inner = { resolved, ... } @ args: let
      inherit (lib.libfetch.parseGitUrl resolved) owner rev repo type ref;
      allRefs' = let
        bname        = baseNameOf ref;
        defaultBRefs = ["HEAD" "master" "main"];
        allRefs      = ! ( builtins.elem bname defaultBRefs );
      in if ( type == "github" ) || ( ref == null ) then {} else {
        inherit allRefs;
      };
      owner' = if builtins.elem owner [null "" "."] then {} else
               { inherit owner; };
      ref' = if ref == null then {} else { inherit ref; };
    in {
      inherit type repo rev;
      name = repo;
      # Simplify URL for processing as a struct.
      # `builtins.fetch[Tree]Git' gets pissed off if you include URI params in
      # the `url' string, it wants you to move them to attrs.
      # We strip off the `data' portion of the scheme, and drop any params or
      # fragments to get the "base" URL.
      # NOTE: the `lib.ytypes.NpmLock.pkg_git_v3' expects a `git+<TRANSPORT>://'
      # in the scheme, so keep that in mind if you serialize `fetchInfo' and
      # try to recycle any `resolved' URI -> type discriminators.
      url  = lib.yankN 1 "(git\\+)?([^?#]+).*" resolved;
    } // allRefs' // owner' // ref';
    # Configured functor based on `typecheck' setting.
    funk = {
      __functionMeta = {
        name = "plockEntryToGenericGitArgs";
        from = "at-node-nix#lib.libplock";
        properties = { pure = true; inherit typecheck; };
        signature = [
          yt.NpmLock.Structs.pkg_git_v3
          lib.libfetch.genericGitArgsPure
        ];
      };
      __functionArgs.resolved = false;
      __innerFunction = inner;
      __functor = self: args: let
        result  = self.__innerFunction args;
        checked =
          if ! typecheck then result else
          ( self.__typeCheck self { inherit args result; } ).result;
      in postFn checked;
    };
    typechecker' = if typecheck then { __typeCheck  = mkFunkTypeChecker; }
                                else { _typeChecker = mkFunkTypeChecker funk; };
  # Even if `typecheck' is false we will stash a partially applied typechecker
  # as a field that can run without the functor.
  in funk // typechecker';


# ---------------------------------------------------------------------------- #

  # PATH

  # XXX: YO STOP RIGHT NOW. You want to read this:
  #
  # NPM explicitly labels "file:" URI in cases where the entry should be trated
  # as a "file" for Lifecycle.
  # Stop and re-read that, and be reminded that "file" essentially means
  # "treat this like a registry tarball" and do not execute any build/prepare
  # lifecycle scripts.
  # This is important because the lifecycle and fetcher MUST NOT BE CONFLATED
  # here because they mean very different things to the build system.
  #
  # XXX: "path" fetcher does not imply "run builds/prepare" ( they call it the
  # "dir" fetcher ).

  #yt.defun [yt.NpmLock.Structs.pkg_git_v3 rtype] inner;
  plockEntryToGenericPathArgs' = {
    typecheck, pure, ifd, allowedPaths
  } @ fenv: { postFn ? ( x: x ) }: let
    inner = {
      resolved ? _pkey
    , link     ? false
    , _lockDir
    , _pkey
    , ...
    } @ args: let
      tagged = lib.discr [  # A list is used to prevent sorting by keys.
        { uri_abs = lib.test "file:/.*"; }
        { uri_rel = lib.test "file:.*"; }
        { abspath = lib.ytypes.FS.abspath.check; }
        { relpath = lib.ytypes.FS.Strings.relpath.check; }
      ] resolved;
      tname = lib.tagName tagged;
      # `pkey' is relative, so all `link' entries and any entry without
      # `resolved' don't need to be checked with regex.
      isRelpathByPkey     = ! ( ( args ? resolved ) || link );
      isRelpathByResolved = builtins.elem tname ["uri_rel" "relpath"];
      isRelpath = isRelpathByPkey || isRelpathByResolved;
      noUri     = if isRelpathByPkey then resolved else
                  lib.yankN 1 "(file:)?(.*)" resolved;
      abspath =
        if _pkey == "" then _lockDir else
        if ! isRelpath then noUri else
        builtins.concatStringsSep "/" [_lockDir noUri];
      # TODO: apply filter to `file:' entries?
    in {
      type      = "path";
      path      = abspath;
      recursive = true;
      #url       = "path:" + abspath;
      #basedir   = _lockDir;
    };
    # Configured functor based on `typecheck' setting.
    funk = {
      __functionMeta = {
        name = "plockEntryToGenericPathArgs";
        from = "at-node-nix#lib.libplock";
        properties = { inherit typecheck; };
        signature = let
          argt = yt.struct {
            lockDir = yt.FS.abspath;
            #pkey    = yt.FS.Strings.relpath;
            pkey    = yt.NpmLock.pkey;
            plent   = yt.NpmLock.Structs.pkg_path_v3;
          };
          # FIXME: this routine lies about being "generic" but the generic
          # routine in `laika' is incomplete so this is alright for now.
          rtype = yt.struct "fetchInfo:builtins.path" {
            inherit (lib.libfetch.genericPathFetchFields) type path recursive;
          };
        in [argt rtype];
      };
      # TODO: arg processor to curry
      __functionArgs = {
        lockDir   = false;
        pkey      = false;
        resolved  = false;
        link      = true;
      };
      __innerFunction = inner;
      __functor = self: args: let
        args'   = args.plent // { _lockDir = args.lockDir; _pkey = args.pkey; };
        result  = self.__innerFunction args';
        checked =
          if ! typecheck then result else
          ( self.__typeCheck self { inherit args result; } ).result;
      in postFn checked;
    };
    typechecker' = if typecheck then { __typeCheck  = mkFunkTypeChecker; }
                                else { _typeChecker = mkFunkTypeChecker funk; };
  # Even if `typecheck' is false we will stash a partially applied typechecker
  # as a field that can run without the functor.
  in funk // typechecker';


# ---------------------------------------------------------------------------- #

  # Responsible for preparing `fetchInfo' structs to be passed to `flocoFetch'.
  # This is pretty simple since the `package-lock.json' writes integrity for
  # archives rather than their contents.
  # In pure mode the info in the lock means that `fetchurlDrv' is the only
  # valid "file" family fetcher which simplifies things.
  #
  # `git' vs. `github' vs. `https' ( file ) is the actually annoying one since
  # you have to rewrite `ssh+git://git@...' to `https://', and distinguish it
  # from `https://' of tarballs.
  #
  # This "Generic" form aims to return as much information as possible, and in
  # practice you'll likely prefer a narrower scraper for your use case.
  # With that in mind you might see this routine as a reference spec for more
  # optimized "practical" scrapers.
  fetchInfoGenericFromPlentV3' = {
    pure, ifd, typecheck, allowedPaths
  } @ fenv: {
    lockDir
  , postFn  ? ( x: x )  # Applied to generic argset before returning
  }: let
    # These "generic" arg sets are the fully exploded set of what we can infer
    # from the package lock entry.
    #
    # The `postFn' is our hook to filter those giant blobs down to something
    # more reasonable before they become part of the `metaEnt' or get sent
    # to fetchers.
    toGenericArgs = lib.matchLam {
      git  = plockEntryToGenericGitArgs'  fenv {};
      file = plockEntryToGenericUrlArgs'  fenv {};
      path = plockEntryToGenericPathArgs' fenv {};
    };
  in { pkey, plent }: let
    byFF  = discrPlentFetcherFamily plent;
    ftype = lib.tagName byFF;
    prep  = if ftype != "path" then byFF else
            { path = { inherit lockDir pkey plent; }; };
  in postFn ( toGenericArgs prep );


# ---------------------------------------------------------------------------- #

  # A practical implementation of `fetchInfo*FromPlentV3' that aims to satisfy
  # Nix builtin fetchers whenever possible.
  fetchInfoBuiltinFromPlentV3' = TODO: null;


# ---------------------------------------------------------------------------- #

  # FIXME: `fenv'

  # Three args.
  # First holds "global" settings while the second is the actual plock entry.
  # Second and Third are the "path" and "entry" from `<PLOCK>.packages', and
  # the intention is that you use `builtins.mapAttrs' to process the lock.
  metaEntFromPlockV3 = {
    lockDir
  , lockfileVersion ? 3
  , pure            ? lib.inPureEvalMode
  , ifd             ? true
  , typecheck       ? false
  , allowedPaths    ? []
  , plock           ? lib.importJSON ( lockDir + "/package-lock.json" )
  , includeTreeInfo ? false  # Includes info about this instance and changes
                             # the `key' field to include the `pkey' path.
  }:
  # `mapAttrs' args. ( `pkey' and `args' ).
  # `args' may be either an entry pulled directly from a lock, or a `metaEnt'
  # skeleton with the `plent' stashed in `args.metaFiles.plock'.
  pkey:
  {
    ident   ? args.name or ( lib.libplock.getIdentPlV3 plock pkey )
  , version ? args.version or ( lib.libplock.getVersionPlV3 plock pkey )
  , ...
  } @ args: let
    plent  = args.metaFiles.plock or args;
    hasBin = ( plent.bin or {} ) != {};
    key'   = ident + "/" + version;
    key    = if includeTreeInfo then key' + ":" + pkey else key';
    extra  = builtins.intersectAttrs {
      os      = true;
      cpu     = true;
      engines = true;
    } plent;
    # Only included when `includeTreeInfo' is `true'.
    # Otherwise including this info would cause key collisions in `metaSet'.
    metaFiles = {
      __serial = false;
      plock = assert ! ( plent ? metaFiles );
              plent // { inherit pkey lockDir; };
    };
    baseFields = extra // {
      inherit key ident version;
      inherit hasBin;
      ltype            = lib.libplock.identifyPlentLifecycleV3' plent;
      depInfo          = lib.libdep.depInfoEntFromPlockV3 pkey plent;
      hasInstallScript = plent.hasInstallScript or false;
      entFromtype      = "package-lock.json(v${toString lockfileVersion})";
      fetchInfo        = lib.libplock.fetchInfoGenericFromPlentV3' {
        inherit pure ifd typecheck allowedPaths;
      } { inherit lockDir; } { inherit pkey; plent = args; };
    } // ( lib.optionalAttrs hasBin { inherit (plent) bin; } )
      // ( lib.optionalAttrs includeTreeInfo { inherit metaFiles; } );
    meta = lib.libmeta.mkMetaEnt baseFields;
    ex = let
      # FIXME:
      #ovs = metaEntOverlays or [];
      ovs = [];
      ov  = if builtins.isList ovs then lib.composeManyExtensions ovs else ovs;
    in if ( ovs != [] ) then meta.__extend ov else meta;
  in ex;


# ---------------------------------------------------------------------------- #

  # TODO: `fenv'
  metaSetFromPlockV3 = {
    plock           ? lib.importJSON' lockPath
  , lockDir         ? dirOf lockPath
  , lockPath        ? lockDir + "/package-lock.json"

  # FIXME
  , pure            ? lib.inPureEvalMode
  , ifd             ? false
  , typecheck       ? false
  , allowedPaths    ? []

  , includeTreeInfo ? false
  , ...
  } @ args: assert lib.libplock.supportsPlV3 plock; let
    inherit (plock) lockfileVersion;
    mkOne = lib.libplock.metaEntFromPlockV3 {
      inherit pure ifd typecheck allowedPaths;
      inherit lockDir plock includeTreeInfo;
      inherit (plock) lockfileVersion;
    };
    # FIXME: we are going to merge multiple instances in a really dumb way here
    # until we get this moved into the spec for proper sub-instances.
    metaEntryList = lib.mapAttrsToList mkOne plock.packages;
    auditKeyValuesUnique = let
      toSerial = e: e.__serial or e;
      toCmp = e:
        lib.filterAttrsRecursive ( _: v: ! ( builtins.isFunction v ) )
                                 ( e.__entries or e );
      pp = e: lib.generators.toPretty { allowPrettyValues = true; }
                                      ( toSerial e );
      # XXX: This is important to pay attention to.
      # We delete like entries from the `metaSet', since what we actually
      # care about are the "out of tree" `dir' entries to pull metadata from.
      # This is the opposite of what we do when creating trees in `libtree' and
      # `mkNmDir' routines since those should never refer to
      # "out of tree paths".
      # In trees we refer to the key in our `metaSet', which will point to the
      # `dir' entry, providing the layer of abstraction that allows us to
      # handle "isolated builds".
      # This is subtle but important abstraction - one that I would say is
      # "the real core" that would have to remain intact if you tried to strip
      # this framework down to its bare minimum.
      # XXX: ^^^ Don't scroll past this if you're learning. ^^^
      noLinks = builtins.filter ( e: e.ltype != "link" ) metaEntryList;
      byKey   = builtins.groupBy ( x: x.key ) noLinks;
      flattenAssertUniq = key: values: let
        uniq   = lib.unique ( map toCmp values );
        nconfs = builtins.length uniq;
        # FIXME: this only diffs the first two values
        header = "Cannot merge key: ${key} with conflicting values:";
        diff   = lib.libattrs.diffAttrs ( builtins.head uniq )
                                        ( builtins.elemAt uniq 1 );
        more = if nconfs == 2 then "" else
               "NOTE: Only the first two instances appear is this diff, " +
               "in total there are ${toString nconfs} conflicting entries.";
        msg = builtins.concatStringsSep "\n" [header ( pp diff ) more];
      in if nconfs == 1 then builtins.head values else throw msg;
    in builtins.mapAttrs flattenAssertUniq byKey;
    metaEntries = auditKeyValuesUnique;
    members = metaEntries // {
      _meta = {
        __serial = false;
        rootKey = "${plock.name or "anon"}/${plock.version or "0.0.0"}";
        inherit plock lockDir;
        fromType = "package-lock.json(v${toString lockfileVersion})";
      };
    };
    base = lib.libmeta.mkMetaSet members;
    ex = let
      # FIXME:
      #ovs = metaSetOverlays or [];
      ovs = [];
      ov  = if builtins.isList ovs then lib.composeManyExtensions ovs else ovs;
    in if ( ovs != [] ) then base.__extend ov else base;
  in ex;


# ---------------------------------------------------------------------------- #

  # Some V3 Helpers

  # (V3) Helper that follows linked entries.
  # If you look in the `package.*' attrs you'll see symlink entries use the
  # `resolved' field to point to out of tree directories, and do not contain
  # any other package information.
  # This helps us fetch the "real" entry so we can look up metadata.
  realEntry = plock: path: let
    e = plock.packages.${path};
    entry = if e.link or false then plock.packages.${e.resolved} else e;
  in assert supportsPlV3 plock;
     entry;


  subdirsOfPathPlockV3' = { plock, path }:
    builtins.filter ( lib.hasPrefix path )
                    ( builtins.attrNames plock.packages );
  subdirsOfPathPlockV3 = x:
    if ( x ? plock ) && ( x ? path ) then subdirsOfPathPlockV3' x else
    path: subdirsOfPathPlockV3 { plock = x; inherit path; };

  # Used to lookup idents for symlinks.
  # For example if a `node_modules/foo' links to `../foo', the plent
  # for the real dir has a `pkey' of "../foo" with no `name' field.
  # The `libplock.pathId' routine cannot scrape the name when processing
  # that path during its first pass so we need to go look it up.`
  lookupRelPathIdentV3 = plock: pkey: let
    isM = _: { resolved ? null, link ? false, ... }:
          link && ( resolved == pkey );
    m = lib.filterAttrs isM plock.packages;
    gn = path: v: v // { ident = v.name or ( lib.libplock.pathId path ); };
    matches = lib.mapAttrsToList gn m;
    len = builtins.length matches;
    ec  = builtins.addErrorContext "lookupRelPathIdentV3:${pkey}";
    te  = x: if 0 < len then x else
             throw "ERROR: Could not find linked module for path: ${pkey}";
    fromPath = let fpi = pathId pkey; in if pkey == "" then plock.name else
                                      if fpi != null then fpi else null;
    fromRel  = ( builtins.head matches ).ident;
    rsl      = if fromPath != null then fromPath else te fromRel;
  in ec rsl;


  # Best effort lookup to get a package identifier associated with a
  # `packages.*' path for a `package-lock.json(V2/3)'.
  # While `pathId' usually does the trick on its own, in the case of symlinks
  # we may have to "reverse index" other lockfile entries to find an identifier.
  #
  # This routine will also read any stashed `ident' values from `data' allowing
  # routines to cache lookups as an optimization ( not required ).
  # This allows you to process a "tree like" structure which may or may not
  # contain `ident' fields in its values, where lookups are only performed
  # as a fallback.
  getIdentPlV3' = plock: path: data: let
    plent = plock.packages.${path};
  in data.ident or data.name or plent.name or
     ( lookupRelPathIdentV3 plock path );

  # As above, but don't accept data as an arg.
  getIdentPlV3 = plock: path: let
    plent = plock.packages.${path};
  in plent.name or ( lookupRelPathIdentV3 plock path );


  # Same deal as `getIdentPlV3' but to lookup keys.
  getVersionPlV3' = plock: path: data: let
    plent = plock.packages.${path};
  in data.version or plent.version or ( realEntry plock path ).version
     or "0.0.0-none";

  getVersionPlV3 = plock: path: let
    plent = plock.packages.${path};
  in plent.version or ( realEntry plock path ).version or "0.0.0-none";


  # Same deal as `getIdentPlV3' but to lookup keys.
  getKeyPlV3' = plock: path: data: let
    plent   = plock.packages.${path};
    ident   = getIdentPlV3' plock path data;
    version = data.version or plent.version or ( realEntry plock path ).version
              or "0.0.0-none";
  in data.key or "${ident}/${version}";

  getKeyPlV3 = plock: path: let
    plent   = plock.packages.${path};
    ident   = plent.name or ( lookupRelPathIdentV3 plock path );
    version = plent.version or ( realEntry plock path ).version or "0.0.0-none";
  in "${ident}/${version}";


# ---------------------------------------------------------------------------- #

  # Essentially an optimized `tagHash'.
  # XXX: I'm unsure of whether or not this works with v1 locks.
  plockEntryHashAttr = {
    __innerFunction = entry:
      if entry ? integrity then lib.libenc.tagHash entry.integrity else
      if entry ? sha1      then { sha1_hash = entry.sha1; } else {};
    __functionArgs = { sha1 = true; integrity = true; };
    __functor = self: self.__innerFunction;
  };


# ---------------------------------------------------------------------------- #

  # Schema Indepent Helpers

  # From a "node_modules/foo/node_modules/@bar/quux" path, get "@bar/quux".
  pathId = lib.yank ".*node_modules/(.*)";

  # Drop one trailing nmDir layer as:
  #   "node_modules/foo/node_modules/@bar/quux" -> "node_modules/foo".
  # Used to find "the parent dir of a subdir".
  # Return `null' if path is the root.
  # Returns "" for a child of the root. 
  parentPath = p: let
    m = lib.yank "(.*)/node_modules/(@[^/]+/)?[^/]+" p;
  in if p == "" then null else if m == null then "" else m;

  # Given a `node_modules/foo/node_modules/@bar/quux/...' path ( string ), split
  # to a list of identifiers with the same hierarcy.
  # In the example above we expect `["foo" "@bar/quux"]'.
  splitNmToIdentPath = nmpath: let
    sp = builtins.tail ( lib.splitString "node_modules/" nmpath );
    stripTrailingSlash = s: let
      m = lib.yank "(.*[^/])/" s;
    in if m == null then s else m;
  in map stripTrailingSlash sp;


# ---------------------------------------------------------------------------- #

  # (V3)
  # Starting at `from' directory/package in the `node_modules/' tree, resolve
  # `ident' and return the associated entry.
  # Node resolution searches for modules first in `<FROM>/node_modules/' if one
  # exists ( top level only, not recursively ) and if a module is not found it
  # begins searching "up" in parent dirs until the filesystem root is reached.
  # In Nix builds we use isolated builds under `/tmp/' at build time or
  # `/nix/store/' at runtime so in theory we should only care about the entries
  # in our lock when searching "up".
  # In any case the builders in this framework actually enforce sandboxing so
  # we actually can rely on this.
  # Returns `null' if resolution fails.
  resolveDepForPlockV3 = plock: from: ident: let
    asSub = let
      # We can't do "${from}/..." because `from' may be "".
      fs = if from == "" then "" else "${from}/";
    in "${fs}node_modules/${ident}";
    # Traverse towards parents to resolve. ( Only if `ident' isn't a subdir )
    fromParent = let
      pf = parentPath from;
    in if from != "" then resolveDepForPlockV3 plock pf ident else
       # Handle attempts to resolve "`from' from `from'" ( love it )
       if ident != plock.name then null else {
         inherit ident;
         resolved = "";
         value    = plock.packages."";
       };
  in assert supportsPlV3 plock;
     if from == null then null else
     if ( ! ( plock.packages ? ${asSub} ) ) then fromParent else {
       inherit ident;
       resolved = asSub;
       value    = realEntry plock asSub;
     };


# ---------------------------------------------------------------------------- #

  # (V1)
  # Same deal as the V3 form, except we use args `parentPath' and
  # `fromPath' and traverse `dependencies' fields instead of `packages' field.
  # Because this form is a hierarchy of attrs is a little bit of a pain; but
  # it's more of less the same process.
  # The only real "gotcha" is that V1 schema uses `dependencies' field for
  # subdirs ( with nested entries ), and `requires' fields ( descriptors only )
  # for resolutions in parent dirs.
  # This function accepts `from' as a V3 style path optionally and will convert
  # it for you, but the `fromPath' argument is faster, if you are performing
  # several calls it may be more efficient to pre-process your args this way.
  resolveDepForPlockV1 = {
    plock
  , from       ? ""
  , parentPath ? lib.take ( ( builtins.length fromPath ) - 1 ) fromPath
  , fromIdent  ? if from == "" then plock.name else pathId from
  , fromPath   ?
      if ctx ? parentPath then ( parentPath ++ [fromIdent] ) else
      ( splitNmToIdentPath from )
  , ent ? if fromPath == [] then plock else
    lib.getAttrFromPath ( lib.intersperse "dependencies" fromPath )
                        plock.dependencies
  } @ ctx: ident: let
    # NOTE: because we want the real entry we only look at `dependencies' and
    # not `requires'; instead we let recursion get the real entry for us.
    isSub = ent ? dependencies.${ident};
    depEnt = {
      inherit ident;
      resolved = let
        # NOTE: "" case is handled below don't sweat it here.
        isp = lib.intersperse "/node_modules/" ( fromPath ++ [ident] );
      in "node_modules/${builtins.concatStringsSep "" isp}";
      value = ent.dependencies.${ident};
    };
    fromParent = if ( fromPath == [] ) && ( ident == plock.name ) then {
      inherit ident;
      resolved = "";
      value = plock;
    } else resolveDepForPlockV1 { inherit plock; fromPath = parentPath; } ident;
  in assert supportsPlV1 plock;
     if isSub then depEnt else
     # Failure case
     if ( fromPath == [] ) && ( ident != plock.name ) then null else
     fromParent;


# ---------------------------------------------------------------------------- #

  # (V1)
  # Rewrite all `requires' fields with resolved versions using lock entries.
  pinVersionsFromPlockV1 = { plock }: let
    pinEnt = scope: e: let
      depAttrs = removeAttrs ( builtins.intersectAttrs pinnableFields e )
                             ["requires"];
      # Extend parent scope with our subdirs to pass to children.
      newScope = let
        depVers = builtins.mapAttrs ( _: { version, ... }: version );
      in builtins.foldl' ( a: b: a // ( depVers b ) ) scope
                         ( builtins.attrValues depAttrs );
      # Pin our requires with actual versions.
      pinned = let
        deps = builtins.mapAttrs ( _: builtins.mapAttrs ( _: pinEnt newScope ) )
                                 depAttrs;
        req  = lib.optionalAttrs ( e ? requires ) {
          requires = builtins.intersectAttrs e.requires scope;
        };
      in e // deps req;
    in pinned;
    rootEnt = lib.optionalAttrs ( plock ? name ) {
      ${plock.name} = plock.version or
                      ( throw "No version specified for ${plock.name}" );
    };
    # The root entry has a bogus `requires' field in V2 locks which needs to
    # be hidden while running `pinEnt'.
    # This stashes the value to be restored later.
    rootReq = lib.optionalAttrs ( plock ? requires ) {
      inherit (plock) requires;
    };
    pinnedLock = pinEnt rootEnt ( removeAttrs plock ["requires"] );
  in assert supportsPlV1 plock;
     pinnedLock // rootReq;


# ---------------------------------------------------------------------------- #

  # (V3)
  # Convert version descriptors to version numbers based on a lock's contents.
  # This is used to isolate builds with a reduced scope to avoid
  # spurious rebuilds.
  # Without pins and isolated builds, any change to the lock would require all
  # packages with install scripts, builds, or prepare routines to be rerun.
  # By minimizing the derivation environments we avoid rebuilds that should have
  # no effect on a package.
  #
  # NOTE: I had to patch this recently to account for modules that had been
  # pushed into parent directories from children.
  # Originally this was operating under the ( incorrect ) assumption that all
  # members of a package's `node_modules/' directory would be listed in one of
  # the relevant `dependencies' fields; but this doesn't account for cases where
  # child modules had pushed their deps up.
  # In retrospect this was goofy that I botched that, I know how they work...
  # I used a naive regex to avoid deep recursion; but since I anticipate that
  # this is going to be slow now it might be work trying.
  #
  # TODO: use a fixed point to perform recursion and memoize lookups in
  # the `scope' attrsets; this gives you the lazy lookup behavior that you
  # actually set out to accomplish while still handling the relevant edge case.
  # This routine's current scope creation routine is useful for other
  # applications though and is worth saving as a standalone library function.
  #
  # TODO: another optimization may be to split the path-names first and
  # possibly use `builtins.groupBy' to get a structure similar to the V1 lock.
  pinVersionsFromPlockV3 = { plock }: let

    pinPath = { scopes, ents } @ acc: path: let
      e = plock.packages.${path};
      # Our `node_modules' dir.
      myNm = if path == "" then "node_modules" else "${path}/node_modules";
      # Get versions of subdirs and add to current scope.
      # This wipes out packages with the same ident in the same way that the
      # Node resolution algorithm does.
      newScope = let
        # Fetch parent scope and extend it with our subdirs.
        parentScope = if path == "" then {} else scopes.${parentPath path};
        maybeAddToScope = scope': path: let
          subId = lib.yank "${myNm}/((@[^/]*/)?[^/]*)" path;
          # This speeds things up slightly
          keep  = ( ! ( scopes ? path ) ) && ( subId != null );
          re    = realEntry plock path;
          addv  = lib.optionalAttrs keep { ${subId} = re.version; };
        in scope' // addv;
        # I fucking hate that I wound up having to use regex here...
        # This redundantly processes paths up to N^2 times.
        paths = builtins.attrNames plock.packages;
      in builtins.foldl' maybeAddToScope parentScope paths;

      # Pin our dependency fields with actual versions.
      pinned = let
        fields     = builtins.intersectAttrs pinnableFields e;
        rewriteOne = _: ef: builtins.intersectAttrs ef newScope;
      in e // ( builtins.mapAttrs rewriteOne fields );
      # Skip link entries, we will pin the "real" entry which users will locate
      # using `realEntry'.
      optNotLink = lib.optionalAttrs ( ! ( e.link or false ) );
    in {
      # I believe still need to record the scope of link entries.
      # XXX: This might not really be necessary, but I haven't tested and would
      # like to err on the safe side until I do.
      scopes = scopes // { ${path} = newScope; };
      ents   = ents // ( optNotLink { ${path} = pinned; } );
    };
  in assert supportsPlV3 plock;
     plock // {
       # Replace `packages' field with updated entries.
       # We update rather than replace because we skipped creating `link'
       # entries and want to preserve the old values.
       packages = let
         paths  = builtins.attrNames plock.packages;
         pinned = builtins.foldl' pinPath {
           scopes = {};
           ents   = {};
         } paths;
       in plock.packages // pinned.ents;
     };


# ---------------------------------------------------------------------------- #

  _fenvFns = {
    # TODO: meta(Ent|Set)FromPlockV3
    inherit
      plockEntryToGenericUrlArgs'
      plockEntryToGenericGitArgs'
      plockEntryToGenericPathArgs'
      fetchInfoGenericFromPlentV3'
    ;
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    discrPlentFetcherFamily
    identifyPlentFetcherFamily
    discrPlentLifecycleV3'
    discrPlentLifecycleV3

    plockEntryHashAttr

    plockEntryToGenericUrlArgs'
    plockEntryToGenericGitArgs'
    plockEntryToGenericPathArgs'

    fetchInfoGenericFromPlentV3'
    fetchInfoBuiltinFromPlentV3'

    identifyPlentLifecycleV3'
  ;
  inherit
    supportsPlV1
    supportsPlV3
    realEntry
    pathId
    parentPath
    resolveDepForPlockV1
    resolveDepForPlockV3
    splitNmToIdentPath
    pinVersionsFromPlockV1
    pinVersionsFromPlockV3
    subdirsOfPathPlockV3
    lookupRelPathIdentV3

    getIdentPlV3'
    getIdentPlV3
    getVersionPlV3'
    getVersionPlV3
    getKeyPlV3'
    getKeyPlV3
  ;

  inherit
    metaEntFromPlockV3
    metaSetFromPlockV3
  ;

  # TODO: make configurable
  fetchInfoFromPlentV3' = fetchInfoGenericFromPlentV3';

  __withFenv = fenv: let
    cw  = builtins.mapAttrs ( _: lib.callWith fenv ) _fenvFns;
    app = let
      proc = acc: name: acc // {
        ${lib.yank "(.*)'" name} = lib.apply _fenvFns.${name} fenv;
      };
    in builtins.foldl' proc {} ( builtins.attrNames _fenvFns );
  in cw // app;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
