# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  pi = yt.PkgInfo;

# ---------------------------------------------------------------------------- #

  # Typeclass for Package/Module "Scope" name.
  Scope = let
    coercibleSums = yt.sum {
      ident = pi.Strings.identifier_any;
      name  = pi.Strings.identifier_any;
      meta  = yt.attrs yt.any;
      inherit (pi.Strings) key;
    };
    coercibleStructs_l = [
      ( yt.struct { inherit (pi.Strings) scope; } )
      pi.Structs.scope
      pi.Structs.identifier
      pi.Structs.id_locator
      pi.Structs.id_descriptor
    ];
    coercibleStrings_l = [
      ( yt.restrict "scope(dirty)" ( lib.test "@([^@/]+)" ) yt.string )
      pi.Strings.scope
      pi.Strings.scopedir
      pi.Strings.identifier_any
      pi.Strings.id_locator
      pi.Strings.id_descriptor
      pi.Strings.key
    ];
    # null -> `{ scope = null; scopedir = ""; }'
    coercibleType = let
      eithers = coercibleStructs_l ++ coercibleStrings_l ++ [coercibleSums];
    in yt.option ( yt.eitherN eithers );
  in {
    name = "Scope";
    # Strict YANTS type for a string or attrset representation of a Scope.
    # "foo" or { scope ? "foo"|null, scopedir = ( "" | "@${scope}/" ); }
    ytype  = yt.either pi.Strings.id_part pi.Structs.scope;
    isType = Scope.ytype.check;
    # Is `x' coercible to `Scope'?
    isCoercible = coercibleType.check;

    # Nullable
    empty = { scope = null; scopedir = ""; };
    fromNull = yt.defun [yt.nil pi.Structs.scope] ( _: Scope.empty );

    # Parser
    fromString = let
      inner = str: let
        m         = builtins.match "((@([^@/]+)(/.*)?)|[^@/]+)" str;
        scopeAt   = builtins.elemAt m 2;
        scopeBare = builtins.head m;
        scope     = if scopeAt == null then scopeBare else scopeAt;
      in if ( m == null ) || ( scope == "unscoped" ) then Scope.empty else {
        inherit scope;
        scopedir = "@${scope}/";
      };
    in yt.defun [( yt.eitherN coercibleStrings_l ) yt.PkgInfo.Structs.scope]
                inner;
    # Writer
    toString = let
      inner = x:
        if builtins.isString x then "@${x}" else
        if x.scope == null then "" else "@${x.scope}";
    in yt.defun [Scope.ytype yt.string] inner;

    # Parser
    fromAttrs = let
      inner = x: let
        fromField =
          if ! ( x ? scope ) then Scope.empty else
          if builtins.isString x.scope then Scope.fromString x.scope else
          x.scope;
      in if pi.Structs.scope.check x then x else
         if x ? meta then Scope.fromAttrs x.meta else
         if ( x ? key ) || ( x ? ident ) || ( x ? name ) then
           Scope.fromString ( x.key or x.ident or x.name )
         else fromField;
      eithers = coercibleStructs_l ++ [coercibleSums];
    in yt.defun [( yt.eitherN eithers ) pi.Structs.scope] inner;
    # Serializer
    toAttrs = x: { inherit (Scope.coerce x) scope; };

    # Best effort conversion
    coerce = let
      inner = x:
        if x == null           then Scope.empty else
        if builtins.isString x then Scope.fromString x
        else Scope.fromAttrs x;
    in yt.defun [coercibleType pi.Structs.scope] inner;

    # Object Constructor/Instantiator
    __functor    = self: x: {
      _type      = self.name;
      val        = self.coerce x;
      __toString = child: self.toString child.val;
      __serial   = child: self.toAttrs child.val;
      __vtype    = self.ytype;
    };
  };


# ---------------------------------------------------------------------------- #

  # FIXME: move to `libparse'
  parseNodeNames = identish: let
    m     = builtins.match "((@([^@/]+)/)?([^@/])[^@/]+).*" identish;
    ident = builtins.head m;
    scope = builtins.elemAt m 2;
    sl    = builtins.elemAt m 3;
  in yt.PkgInfo.Structs.node_names {
    _type = "NodeNames";
    inherit ident scope;
    bname = baseNameOf ident;
    sdir  = if scope == null then "unscoped/${sl}" else scope; # shard dir
  };


# ---------------------------------------------------------------------------- #

  node2nixName = { ident ? args.name, version, ... } @ args: let
    fid = "${builtins.replaceStrings ["@" "/"] ["_at_" "_slash_"] ident
            }-${version}";
    fsb = ( if args.scope != null then "_at_${args.scope}_slash_" else "" ) +
          "${args.bname}-${version}";
  in if ( args ? bname ) && ( args ? scope ) then fsb else fid;


# ---------------------------------------------------------------------------- #

  # NPM's registry does not include `scope' in its tarball names.
  # However, running `npm pack' DOES produce tarballs with the scope as a
  # a prefix to the name as: "${scope}-${bname}-${version}.tgz".
  asLocalTarballName = { bname, scope ? null, version }:
    if scope != null then "${scope}-${bname}-${version}.tgz"
                     else "${bname}-${version}.tgz";

  asNpmRegistryTarballName = { bname, version }: "${bname}-${version}.tgz";


# ---------------------------------------------------------------------------- #

  # Matches "/foo/*/bar", "/foo/*", "*".
  # But NOT "/foo/\*/bar".
  # NOTE: In `.nix' files, "\*" ==> "*", so the "escaped" glob in the example
  #       above is written as : hasGlob "foo/\\*/bar" ==> false
  #       When reading from a file however, the examples above are "accurate".
  hasGlob = p:
    lib.test ".*\\*.*" ( builtins.replaceStrings ["\\*"] [""] p );

  hasDoubleGlob = p:
    lib.test ".*\\*\\*.*" ( builtins.replaceStrings ["\\*"] [""] p );

  hasSingleGlob = p: let
    esc = builtins.replaceStrings ["\\*"] [""] p;
  in lib.test ".*[^*]\\*[^*].*|.*[^*]\\*|\\*" esc;


# ---------------------------------------------------------------------------- #

  explicitWorkspaces = builtins.filter ( p: ! ( hasGlob p ) );

  singleGlobWorkspaces = builtins.filter hasSingleGlob;

  doubleGlobWorkspaces = builtins.filter hasDoubleGlob;

  ignoreNodeModulesDir = name: type:
    ! ( ( type == "directory" ) && ( ( baseNameOf name ) == "node_modules" ) );

  # Non-Recursive
  dirHasPjs = p: builtins.pathExists "${lib.coercePath p}/package.json";


# ---------------------------------------------------------------------------- #

  # Expand globs in workspace paths for a `package.json' file.
  # XXX: This only supports globs at the end of paths.
  processWorkspacePath = p: let
    dirs =
      if ( hasSingleGlob p ) then ( lib.libfs.listSubdirs ( dirOf p ) ) else
      if ( hasDoubleGlob p ) then ( lib.libfs.listDirsRecursive ( dirOf p ) )
      else [p];
    process = builtins.filter ( x: x != null );
    msg = "processGlobEnd: Only globs at the end of paths arg handled: ${p}";
  in if ( hasGlob ( dirOf p ) ) then throw msg else ( process dirs );

  # Looks up workspace paths ( if any ) in a `package.json'.
  # This supports either NPM or Yarn style workspace fields
  workspacePackages = dir: pkgInfo: let
    packages = pkgInfo.workspaces.packages or pkgInfo.workspaces or [];
    processPath = p: processWorkspacePath "${toString dir}/${p}";
  in builtins.concatLists ( map processPath packages );

  # Given a path to a project dir or `package.json', return list of ws paths.
  readWorkspacePackages = p: let pjp = pjsPath p; in
    workspacePackages ( dirOf pjp ) ( lib.importJSON' pjp );

  # Make workspace paths absolute.
  normalizeWorkspaces = dir: pjs:
    if ! ( pjs ? workspaces ) then [] else
    map ( lib.libpath.realpathRel dir ) ( workspacePackages dir pjs );


# ---------------------------------------------------------------------------- #

  # Given a path-like `p', add `${p}/package.json' if `p' if `p' isn't a path
  # to a `package.json' file already.
  # This is implemented naively, but allows use to directory names and filepaths
  # interchangeably to refer to projects.
  # This is analogous to Nix's `path/to/ --> path/to/default.nix' behavior.
  #
  # Context can be stripped if desired, be sure you understand what that means.
  pjsPath' = { discardStringContext }: pathlike: let
    p   = if builtins.isString pathlike then pathlike else toString pathlike;
    sub = if builtins.isPath pathlike then pathlike + "/package.json" else
          if lib.test ".*/" pathlike then pathlike + "package.json" else
          pathlike + "/package.json";
    rsl = if ( baseNameOf pathlike ) == "package.json" then p else
          if ( dirOf pathlike ) == "." then "package.json" else sub;
  in if discardStringContext then builtins.unsafeDiscardStringContext rsl
                             else rsl;

  # We won't strip context by default.
  pjsPath = let
    inner = pjsPath' { discardStringContext = false; };
    pstype = yt.either yt.string yt.Typeclasses.pathlike;
  in yt.defun [pstype pstype] inner;


# ---------------------------------------------------------------------------- #

  # TODO: move to `ak-nix'

  # Reads a JSON file from a pathlike input.
  # This will enforce the `pure' and `ifd' settings indicated even if the
  # runtime environment is more permissive.
  readJSONFromPath' = { pure, ifd }: pathlike: let
    p    = if pathlike ? __toString then toString pathlike else pathlike;
    pjs  = lib.importJSON p;
    msgD = "readPjsFromPath: Cannot read path '${p}' when `IFD' is disable.";
    forD = if ifd then pjs else throw msgD;
    msgP = "readPjsFromPath: Cannot read unlocked path '${p}' in pure mode.";
    forP = if ( ! pure ) || ( lib.isStorePath p ) then pjs else throw msgP;
  in if ( lib.isDerivation pathlike ) then forD else forP;

  readJSONFromPath = let
    inner = readPjsFromPath' { pure = lib.inPureEvalMode; ifd = true; };
  in yt.defun [yt.Typeclasses.pathlike ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # Reads a `package.json' from a pathlike input.
  # This will enforce the `pure' and `ifd' settings indicated even if the
  # runtime environment is more permissive.
  readPjsFromPath' = { pure, ifd }: pathlike:
    readJSONFromPath' { inherit pure ifd; } ( pjsPath pathlike );

  readPjsFromPath = let
    inner = readPjsFromPath' { pure = lib.inPureEvalMode; ifd = true; };
  in yt.defun [yt.Typeclasses.pathlike ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # Converts an attrset or pathlike to an attrset with `package.json' contents.
  # If `x' is already the contetns of a `package.json' this is a no-op.
  # Otherwise we will read/import from the path representation of `x', accepting
  # a path to `package.json' directly, or a dir containing `package.json'.
  coercePjs' = { pure, ifd }: x: let
    isPjs = ( builtins.isAttrs x ) && ( ! ( yt.Typeclasses.pathlike.check x ) );
  in if isPjs then x else readPjsFromPath' { inherit pure ifd; } x;

  coercePjs = let
    inner = coercePjs' { pure = lib.inPureEvalMode; ifd = true; };
    argt  = yt.either yt.Typeclasses.pathlike ( yt.attrs yt.any );
  in yt.defun [argt ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # TODO: this functor should be generalized to an accessor and reused.

  # `packge.json' files can indicate that they have bins using either the
  # `bin' field ( a string or attrs ), or by specifying a relative path to
  # a directory filled with executables using the `directories.bin' field.
  # This predicate lets us know if we need to handle "any sort of bin stuff"
  # for a `package.json'.
  pjsHasBin' = { pure, ifd }: {
    __functionMeta = {
      name = "pjsHasBin";
      from = "at-node-nix#lib.libpkginfo";
      signature = let
        # FIXME: package_json type is phony.
        tp = yt.Typeclasses.pathlike;
        ts = yt.PkgInfo.Structs.package_json;
        t0 = if pure then ts else yt.either tp ts;
      in [t0 yt.bool];
      properties = { inherit pure ifd; };
    };
    __functionArgs  = {
      directories = true;
      bin         = true;
      outPath     = true;
      pjs         = true;
    };
    __innerFunction = pjs: ( pjs.bin or pjs.directories.bin or {} ) != {};
    __processArgs = self: x: let
      loc = "${self.__functionMeta.from}.${self.__functionMeta.name}";
    in x.pjs or coercePjs' { inherit pure ifd; };
    __functor = self: x: let
      loc = "${self.__functionMeta.from}.${self.__functionMeta.name}";
      pjs = self.__processArgs self x;
      pp  = lib.generators.toPretty { allowPrettyValues = true; };
      ec  = builtins.addErrorContext "(${loc}): called with ${pp x}";
      rsl = self.__innerFunction pjs;
    in ec rsl;
  };

  pjsHasBin = { pure = lib.inPureEvalMode; ifd = true; };


# ---------------------------------------------------------------------------- #

  # XXX: IFD, maybe impure depending on path
  pjsBinPairsFromDir = {
    absdir ? src + "/${bindir}"
  , bindir ? if directories != null then directories.bin else
             lib.yank "${src}/(.*)" args.absdir
  , directories ? args.pjs.directories or null
  , src ? throw (
      "(at-node-nix#lib.libpkginfo.pjsBinPairsFromDir): " +
      "You must pass either `absdir' + `bindir' or `src' + directories."
    )
  } @ args: let
    ents  = builtins.readDir absdir;
    files = lib.filterAttrs ( _: type: type != "directory" ) ents;
    proc  = acc: fname: acc // {
      ${lib.libfs.baseNameOfDropExt fname} = "${bindir}/${fname}";
    };
  in builtins.foldl' proc {} ( builtins.attrNames files );


  # Normalize `bin' or `directories.bin' field to pairs of `{ <BIN> = <PATH>; }'
  # where any "./" prefix has been stripped from `<PATH>' values.
  # This may be used to check equivalence between various forms.
  #
  # Set `ifd' and `pure' to restrict reading the filesystem, or "unlocked"
  # paths; this is needed for `directories.bin', and `bin' as a string if the
  # caller omits the `ident'/`bname' args.
  pjsBinPairs' = let
    loc = "at-node-nix#lib.libpkginfo.pjsBinPairs'";
  in { ifd ? true, pure ? lib.inPureEvalMode }: {
    bin         ? null
  , directories ? {}
  , bname       ? baseNameOf ident
  , ident ?
    if ! ifd then throw "(${loc}): Cannot lookup `ident' without IFD." else
    if pure && ( ! ( lib.isStorePath src ) )
    then throw "(${loc}): Cannot read non-store path in pure mode."
    else ( lib.importJSON ( src + "/package.json" ) ).name
  , src ? throw ( "(${loc}): To produce binpairs from `directories.bin' you " +
                  "must pass `src' as an arg." )
  } @ pjs: let
    stripDS = lib.yank "\\./(.*)";
  in if builtins.isAttrs bin  then builtins.mapAttrs ( _: stripDS ) bin else
     if builtins.isString bin then { ${bname} = stripDS bin; } else
     pjsBinPairsFromDir { inherit src directories; };


# ---------------------------------------------------------------------------- #

  # Replace `package.json' dependency descriptors ( "^1.0.0" ) with new values;
  # presumably paths to the Nix Store or exact versions.
  # `resolves' is an attrset of
  #   `{ foo = "new value"; }' or `{ foo = prev: "new value"; }'
  # mappings, which will be used to replace or transform fields.
  # `depFields' may be set to indicate that additional dependency lists should
  # be modified:
  #   depFields = ["devDependencies" "peerDependencies" ...];
  rewriteDescriptors = { pjs, resolves, depFields ? ["dependencies"] }: let
    inherit (builtins)
      all elem partition isFunction isString
      mapAttrs attrValues intersectAttrs listToAttrs;
    allowedFields = [
      "dependencies" "devDependencies" "optionalDependencies" "peerDependencies"
    ];
    verifyField = f: if ( elem f allowedFields ) then true else
      throw "Unrecognized dependency field name: ${f}";
    verifyFields = all verifyField depFields;
    # FIXME: this should be done lazily.
    #verifyResolves =
    #  all ( x: isFunction x || isString x ) ( attrValues resolves );
    verifyResolves = true;
    rewriteDeps = deps: let
      alist  = lib.attrsToList ( intersectAttrs deps resolves );
      parted = partition ( x: isFunction x.value ) alist;
      parted' = mapAttrs ( _: listToAttrs ) parted;
      applied = mapAttrs ( k: fn: fn deps.${k} ) parted'.right;
      merged = deps // parted'.wrong // applied;
    in merged;
    rewriteField = acc: f:
      if ( ! ( acc ? ${f} ) ) then acc else
      ( acc // { ${f} = rewriteDeps acc.${f}; } );
    rewritten = builtins.foldl' rewriteField pjs depFields;
  in assert verifyFields; assert verifyResolves; rewritten;


# ---------------------------------------------------------------------------- #

  # This isn't necessarily the perfect place for this function; but it will
  # check a directory, or attrset associated with a `package.json' or a single
  # package entry from a `package-lock.json' to see if it has an install script.
  # It is best to use this with a path or `package-lock.json' entry, since this
  # will fail to detect `node-gyp' installs with a regular `package.json'.
  pjsHasInstallScript' = { pure ? lib.inPureEvalMode }: x: let
    # TODO: path might be pure, but might not. Check
    # I would normally force the more restrictive assumption but shit that's
    # actually pure in real builds currently depends on this.
    pjs      = coercePjs x;
    explicit = pjs.hasInstallScript or false;  # for lock entries
    scripted = ( pjs ? scripts ) && builtins.any ( a: pjs.scripts ? a ) [
      "preinstall" "install" "postinstall"
    ];
    asPath = lib.libpath.coercePath x;
    isDir = ( pjs != x ) && ( lib.libpath.isCoercibleToPath x ) &&
            ( ( lib.libpath.categorizePath asPath ) == "directory" );
    hasGyp = isDir && ( builtins.pathExists ( asPath + "/binding.gyp" ) );
  in explicit || scripted || hasGyp;

  pjsHasInstallScript = pjsHasInstallScript' {};


# ---------------------------------------------------------------------------- #

  # FIXME: these don't actually reflect the lifecycle events run for various
  # commands, for example `npm install' runs all kinds of shit.
  # TODO: Finish mapping the real event lifecycle in `events.nix'.
  #

  hasStageFromScripts = stage: scripts:
    ( scripts ? ${stage} )        ||
    ( scripts ? "pre${stage}" )   ||
    ( scripts ? "post${stage}" );

  hasPrepareFromScripts = hasStageFromScripts "prepare";
  hasInstallFromScripts = hasStageFromScripts "install";
  hasTestFromScripts    = hasStageFromScripts "test";

  # XXX: reminder that this says nothing about "lifecycle events".
  # We're just scraping info.
  hasPackFromScripts = scripts: ( scripts ? prepack ) || ( scripts ? postpack );

  # We treat `prepublish' ( legacy ) as an alias of "build"
  hasBuildFromScripts = scripts:
    ( hasStageFromScripts "build" scripts ) ||
    ( scripts ? prepublish );

  # This one has edge cases
  hasPublishFromScripts = scripts:
    ( scripts ? publish )        ||
    ( scripts ? prepublishOnly ) ||
    ( scripts ? postpublish );

  # Run when deps are added/removed/modified in `package.json'.
  hasDepScriptFromScripts = scripts: scripts ? dependencies;


# ---------------------------------------------------------------------------- #

in {

  inherit
    Scope
  ;

  inherit
    rewriteDescriptors
    pjsHasInstallScript' pjsHasInstallScript
    pjsHasBin'           pjsHasBin
  ;

  # `package.json' locators
  inherit
    readJSONFromPath' readJSONFromPath
    pjsPath'          pjsPath
    readPjsFromPath'  readPjsFromPath
    coercePjs'        coercePjs
  ;

  # Normalize fields
  inherit
    pjsBinPairsFromDir
    pjsBinPairs'
  ;

  # Names
  inherit
    parseNodeNames
    node2nixName
    asLocalTarballName
    asNpmRegistryTarballName
  ;

  # Workspaces
  inherit
    workspacePackages
    readWorkspacePackages
    normalizeWorkspaces
  ;

  inherit
    hasStageFromScripts
    hasPrepareFromScripts
    hasInstallFromScripts
    hasTestFromScripts
    hasPackFromScripts
    hasBuildFromScripts
    hasPublishFromScripts
    hasDepScriptFromScripts
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
