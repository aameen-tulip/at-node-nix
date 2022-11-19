# ============================================================================ #
#
# Routines related to scraping `package-lock.json' data.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Prim // lib.ytypes.Core;
  inherit (lib.libdep) pinnableFields;

# ---------------------------------------------------------------------------- #

  # TODO: move to `ak-nix'
  mkTypeChecker = { __functionMeta, ... }: let
    argt = builtins.head __functionMeta.signature;
    rslt = builtins.elemAt __functionMeta.signature 1;
    name = __functionMeta.name or "<LAMBDA>";
    checkOne = type: v: let
      checked = type.checkType v;
      ok      = type.checkToBool checked;
      err'    = if ok then {} else { err = type.toError v checked; };
    in err' // { inherit type checked ok; };
  in lib.libtypes.typedef' {
    inherit name;
    checkType = { args, result ? null }: let
      arg_info = checkOne argt args;
      rsl_info = checkOne rslt result;
    in {
      inherit arg_info rsl_info;
      ok = arg_info.ok && rsl_info.ok;
    };
    toError = { args, result }: { ok, arg_info, rsl_info }: let
      a = arg_info; r = rsl_info;
    in if ok then "no errors." else
       if a.ok then "Typecheck of result failed:\n${r.err}" else
       if r.ok then "Typecheck of inputs failed:\n${a.err}" else
       "Typecheck of inputs and result failed.\n" +
       "Input Error: ${a.err}\nResult Error:\n ${r.err}\n";
    def = { inherit argt rslt name checkOne; };
  };


# ---------------------------------------------------------------------------- #

  # Because `package-lock.json(V2)' supports schemas v1 and v3, these helpers
  # shorten schema checks.

  supportsPlV1 = { lockfileVersion, ... }:
    ( lockfileVersion == 1 ) || ( lockfileVersion == 2 );

  supportsPlV3 = { lockfileVersion, ... }:
    ( lockfileVersion == 2 ) || ( lockfileVersion == 3 );


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
  discrPlentLifecycleV3' = lib.libtypes.discrTypes {
    git     = yt.NpmLock.Structs.pkg_git_v3;
    tarball = yt.NpmLock.Structs.pkg_file_v3;
    link    = yt.NpmLock.Structs.pkg_link_v3;
    dir     = yt.NpmLock.Structs.pkg_dir_v3;
  };

  discrPlentLifecycleV3 =
    yt.defun [yt.NpmLock.package yt.FlocoFetch.Sums.tag_lifecycle_plent]
             discrPlentLifecycleV3';


# ---------------------------------------------------------------------------- #

  # NOTE: works for either "file" or "tarball".
  # You can pick a specialized form using the `postFn' arg.
  # I recommend `asGeneric*ArgsImpure' here since those routines
  # doesn't use a real type checker.
  # They just have an assert that freaks out if you're missing a hash field.
  # Our inner fetchers will catch that anyway so don't sweat it.
  plockEntryToGenericUrlArgs' = {
    postFn    ? lib.libfetch.asGenericUrlArgsImpure
  , typecheck ? false
  }: let
    inner = {
      resolved
    , sha1_hash ? plent.sha1 or plent.shasum or null
    , integrity ? null  # Almost always `sha512_sri` BUT NOT ALWAYS!
    , ...
    } @ plent: let
      rough   = { url = resolved; inherit sha1_hash integrity; };
      args    = lib.filterAttrs ( _: x: x != null ) rough;
    in postFn args;
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
        checked = if ! typecheck then result else
                  self.__typeCheck self { inherit args result; };
      in postFn checked;
    };
    typechecker' = if typecheck then { __typeCheck  = mkTypeChecker; }
                                else { _typeChecker = mkTypeChecker funk; };
  # Even if `typecheck' is false we will stash a partially applied typechecker
  # as a field that can run without the functor.
  in funk // typechecker';


# ---------------------------------------------------------------------------- #

  # NOTE: the fetcher for `git' entries need to distinguish between `git',
  # `github', and `sourcehut' when processing these args.
  # They should not try to interpret the `builtins.fetchTree' type using
  # `identify(Resolved|Plen)FetcherFamily' which conflates all three
  # `git' types.
  # XXX: I'm not sure we can get away with using `type = "github";' unless we
  # are sure that we know the right `ref'/`branch'. Needs testing.
  plockEntryToGenericGitArgs' = {
    postFn    ? ( x: x )
  , typecheck ? false
  }: let
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
        result = self.__innerFunction args;
        checked = if ! typecheck then result else
                  self.__typeCheck self { inherit args result; };
      in postFn checked;
    };
    typechecker' = if typecheck then { __typeCheck  = mkTypeChecker; }
                                else { _typeChecker = mkTypeChecker funk; };
  # Even if `typecheck' is false we will stash a partially applied typechecker
  # as a field that can run without the functor.
  in funk // typechecker';


# ---------------------------------------------------------------------------- #

  plockEntryToGenericPathArgs' = {
    postFn    ? ( x: x )
  , typecheck ? false
  , basedir
  }: let
    inner = { resolved, link ? false } @ args: let
    in {};
  in #yt.defun [yt.NpmLock.Structs.pkg_git_v3 rtype] inner;
    inner;


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
  fetchInfoFromPlentV3' = {
    pure      ? lib.inPureEvalMode
  , ifd       ? true
  , typecheck ? false
  }: {
    lockDir
  , postFn  ? ( x: x )  # Applied to generic argset before returning
  }: let
    toGenericArgs = lib.matchLam {
      git  = plockEntryToGenericGitArgs' { inherit typecheck; };
      file = plockEntryToGenericUrlArgs' { inherit typecheck; };
      # TODO: processor for path args doesn't typecheck
      path = lib.libfetch.processGenericPathArgs {
        __thunk.basedir = lockDir;
      };
    };
  in {
    pkey
  , plent
  }: let
    byFF        = discrPlentFetcherFamily plent;
    ftype       = lib.tagName byFF;
    genericArgs = toGenericArgs byFF;
  in postFn {
  };


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
  getKeyPlV3' = plock: path: data: let
    plent   = plock.packages.${path};
    ident   = getIdentPlV3' plock path data;
    version = data.version or plent.version or ( realEntry plock path ).version;
  in data.key or "${ident}/${version}";

  getKeyPlV3 = plock: path: let
    plent   = plock.packages.${path};
    ident   = plent.name or ( lookupRelPathIdentV3 plock path );
    version = plent.version or ( realEntry plock path ).version;
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
  # FIXME: use a fixed point to perform recursion and memoize lookups in
  # the `scope' attrsets; this gives you the lazy lookup behavior that you
  # actually set out to accomplish while still handling the relevant edge case.
  # This routine's current scope creation routine is useful for other
  # applications though and is worth saving as a standalone library function.
  #
  # FIXME: another optimization may be to split the path-names first and
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

in {
  inherit
    discrPlentFetcherFamily
    identifyPlentFetcherFamily
    discrPlentLifecycleV3'
    discrPlentLifecycleV3
    fetchInfoFromPlentV3'

    plockEntryHashAttr
    plockEntryToGenericUrlArgs'
    plockEntryToGenericGitArgs'
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
    getKeyPlV3'
    getKeyPlV3
  ;
  inherit mkTypeChecker;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
