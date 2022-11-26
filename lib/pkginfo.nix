# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  pi = yt.PkgInfo;

  defaultFlocoEnv = {
    allowedPaths = [];
    pure         = lib.inPureEvalMode;
    ifd          = true;
  };


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

  # Reads a JSON file from a pathlike input.
  # This will enforce the `pure' and `ifd' settings indicated even if the
  # runtime environment is more permissive.
  # Throws if path is not readable.
  # We explicitly check the contained directory because of how frequently we
  # work with tarballs, `builtins.pathExists "${my-tarball}/.";' fails because
  # `my-tarball' is a file, so this works out.
  readJSONFromPath' = { allowedPaths, pure, ifd } @ fenv: pathlike: let
    doRead = p: let
      isDir = builtins.pathExists ( ( dirOf ( toString p ) ) + "/." );
    in if isDir then lib.importJSON' ( toString p ) else
       throw ( "readJSONFromPath: path '${dirOf ( toString p )}' is not " +
               "a directory." );
  in lib.libread.runReadOp fenv doRead pathlike;

  readJSONFromPath = let
    inner = readPjsFromPath' defaultFlocoEnv;
  in yt.defun [yt.Typeclasses.pathlike ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # Reads a `package.json' from a pathlike input.
  # This will enforce the `pure' and `ifd' settings indicated even if the
  # runtime environment is more permissive.
  readPjsFromPath' = { pure, ifd, allowedPaths } @ fenv: pathlike:
    readJSONFromPath' fenv ( pjsPath pathlike );

  readPjsFromPath = let
    inner = readPjsFromPath' defaultFlocoEnv;
  in yt.defun [yt.Typeclasses.pathlike ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # Converts an attrset or pathlike to an attrset with `package.json' contents.
  # If `x' is already the contents of a `package.json' this is a no-op.
  # Otherwise we will read/import from the path representation of `x', accepting
  # a path to `package.json' directly, or a dir containing `package.json'.
  coercePjs' = { pure, ifd, allowedPaths } @ fenv: x: let
    isPjs = ( builtins.isAttrs x ) && ( ! ( yt.Typeclasses.pathlike.check x ) );
  in if isPjs then x else readPjsFromPath' fenv x;

  coercePjs = let
    inner = coercePjs' defaultFlocoEnv;
    argt  = yt.either yt.Typeclasses.pathlike ( yt.attrs yt.any );
  in yt.defun [argt ( yt.attrs yt.any )] inner;


# ---------------------------------------------------------------------------- #

  # TODO: this functor should be generalized to an accessor and reused.

  # `packge.json' files can indicate that they have bins using either the
  # `bin' field ( a string or attrs ), or by specifying a relative path to
  # a directory filled with executables using the `directories.bin' field.
  # This predicate lets us know if we need to handle "any sort of bin stuff"
  # for a `package.json'.
  pjsHasBin' = { pure, ifd, allowedPaths } @ fenv: {
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
    in x.pjs or coercePjs' fenv;
    __functor = self: x: let
      loc = "${self.__functionMeta.from}.${self.__functionMeta.name}";
      pjs = self.__processArgs self x;
      pp  = lib.generators.toPretty { allowPrettyValues = true; };
      ec  = builtins.addErrorContext "(${loc}): called with ${pp x}";
      rsl = self.__innerFunction pjs;
    in ec rsl;
  };

  pjsHasBin = pjsHasBin' defaultFlocoEnv;


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
  in { ifd, pure, allowedPaths } @ fenv: {
    bin         ? null
  , directories ? {}
  , bname       ? baseNameOf ident
  , ident       ? ( coercePjs' fenv src ).name
  , src ?
    throw ( "(${loc}): To produce binpairs from `directories.bin' you " +
            "must pass `src' as an arg." )
  } @ pjs: let
    stripDS = lib.yank "\\./(.*)";
  in if builtins.isAttrs bin  then builtins.mapAttrs ( _: stripDS ) bin else
     if builtins.isString bin then { ${bname} = stripDS bin; } else
     pjsBinPairsFromDir { inherit src directories; };

  # TODO: make `toError' for allowed read checker
  #  if ! ifd then throw "(${loc}): Cannot lookup `ident' without IFD." else
  #  if pure && ( ! ( ( lib.isStorePath src ) || ( isAllowedPath allowedPaths src ) )
  #  then throw "(${loc}): Cannot read non-store path in pure mode."
  #  else < READ IT >

  pjsBinPairs = pjsBinPairs' defaultFlocoEnv;


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
      if ! ( acc ? ${f} ) then acc else
      acc // { ${f} = rewriteDeps acc.${f}; };
    rewritten = builtins.foldl' rewriteField pjs depFields;
  in assert verifyFields; assert verifyResolves; rewritten;


# ---------------------------------------------------------------------------- #

  # This isn't necessarily the perfect place for this function; but it will
  # check a directory, or attrset associated with a `package.json' or a single
  # package entry from a `package-lock.json' to see if it has an install script.
  # It is best to use this with a path or `package-lock.json' entry, since this
  # will fail to detect `node-gyp' installs with a regular `package.json'.
  pjsHasInstallScript' = { pure, ifd }: x: let
    pjs      = coercePjs' { inherit pure ifd; } x;
    explicit = pjs.hasInstallScript or false;  # for lock entries
    scripted = ( pjs ? scripts ) && builtins.any ( a: pjs.scripts ? a ) [
      "preinstall" "install" "postinstall"
    ];
    asPath = lib.libpath.coercePath x;
    isDir = ( pjs != x ) && ( lib.libpath.isCoercibleToPath x ) &&
            ( ( lib.libpath.categorizePath asPath ) == "directory" );
    hasGyp = isDir && ( builtins.pathExists ( asPath + "/binding.gyp" ) );
  in explicit || scripted || hasGyp;


  pjsHasInstallScript = pjsHasInstallScript' {
    pure = lib.inPureEvalMode;
    ifd  = true;
  };


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
    pjsBinPairs' pjsBinPairs
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
