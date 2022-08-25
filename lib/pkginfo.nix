# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (lib) isType setType;
  inherit (lib.libfs) listSubdirs listDirsRecursive;
  inherit (lib.libpath) coercePath;
  inherit (lib.libstr) test;

# ---------------------------------------------------------------------------- #

  # This wipes out any C style comments in JSON files that were written by
  # sub-humans that cannot abide by simple file format specifications.
  # Later this function will be revised to schedule chron jobs which send
  # daily emails to offending projects' authors - recommending various
  # re-education programs they may enroll in.
  importJSON' = file: let inherit (builtins) fromJSON readFile; in
    fromJSON ( lib.libstr.removeSlashSlashComments ( readFile file ) );


# ---------------------------------------------------------------------------- #

  # Split a `package.json' name field into "scope" ( if any ) and the
  # package name, yielding a set with the original name, "bname", and scope.
  # Ex:
  #   "@foo/bar" ==> { name = "@foo/bar"; bname = "bar"; scope = "foo" }
  #   "bar" ==> { name = "bar"; bname = "bar"; scope = null }
  isPkgJsonName = test "(@[^/@.]+/)?([^/@.]+)";

  parsePkgJsonNameField = name: assert ( isPkgJsonName name ); let
    inherit (builtins) substring stringLength;
    dropStr1 = str: substring 1 ( stringLength str ) str;
  in {
    ident = name;
    bname = baseNameOf name;
    scope =
      if ( substring 0 1 name ) == "@" then dropStr1 ( dirOf name ) else null;
    _type = "";
  };


# ---------------------------------------------------------------------------- #

  # `str' may be either a scoped package name ( package.json name field )
  # or just the "scope part" of a name.
  # Ex:
  #   "@foo/bar" ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   "foo/bar"  ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   "@foo/"    ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   "@foo"     ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   "foo/"     ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   "foo"      ==> { scope = "foo"; scopeDir = "@foo/"; }
  #   ""         ==> { scope = null;  scopeDir = ""; }
  #   null       ==> { scope = null;  scopeDir = ""; }
  #   "@/"       ==> error: Invalid scope string: @/
  normalizePkgScope = str:
    let smatch = builtins.match "@?([^/@]+)(/[^/@]*)?" ( lib.toLower str );
    in if ( ( str == null ) || ( str == "" ) )
       then { scope = null; scopeDir = ""; }
       else if ( smatch == null ) then ( throw "Invalid scope string: ${str}" )
       else let scope = builtins.head smatch; in {
                  inherit scope;
                  scopeDir = "@${scope}/";
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

  mkPkgInfo = { ident ? args.name, version, ... } @ args:
    let inherit ( parsePkgJsonNameField ident ) bname scope;
    in args // {
      inherit bname scope ident;
      _type = "pkginfo";

      localTarballName =
        asLocalTarballName { inherit bname scope version; };
      registryTarballName =
        asNpmRegistryTarballName { inherit bname version; };

      scopeDir = if scope != null then "@${scope}/" else "";
      node2nixName =
        if scope != null then "_at_${scope}_slash_${bname}-${version}"
                         else "${bname}-${version}";
    };


# ---------------------------------------------------------------------------- #

  allDepFields = [
    "dependencies"
    "devDependencies"
    "optionalDependencies"
    "peerDependencies"
  ];
  depMetaFields = [
    "bundledDependencies"   # true (all) | false (none) | list of idents
    "bundleDependencies"    # alternative spelling... because sure why not
    "peerDependenciesMeta"  # attrs of `<IDENT> = { ... }'
  ];

  allDependencies = x:
    ( x.optionalDependencies or {} ) // ( x.peerDependencies or {} ) //
    ( x.devDependencies      or {} ) // ( x.dependencies     or {} );

# ---------------------------------------------------------------------------- #

  getDepFields = depFields: x:
    assert builtins.all ( k: builtins.elem k allDepFields ) depFields;
    builtins.foldl' ( acc: k: acc // ( x.${k} or {} ) ) {} depFields;


# ---------------------------------------------------------------------------- #

  normalizedDepFields = depFields: x: let
    a  = x.dependencies or {};
    p  = x.peerDependencies or {};
    d  = x.devDependencies or {};
    o  = x.optionalDependencies or {};
    # This accepts two spellings... ffs.
    b  = x.bundledDependencies or x.bundleDependencies or false;
    pm = x.peerDependenciesMeta or {};
    markDeps = k: v: let
      io = pm.${k}.optional or ( o ? ${k} );
      ib = if builtins.isBool b then b else builtins.elem k b;
      ip = p ? ${k};
      id = d ? ${k};
      ir = ! ( ip || id );
      mo = lib.optionalAttrs io { optional = true; };
      mb = lib.optionalAttrs ib { bundled = true; };
      mp = lib.optionalAttrs ip { peer = true; };
      md = lib.optionalAttrs id { dev = true; };
      mr = lib.optionalAttrs ir { runtime = true; };
    in { descriptor = v; } // mo // mb // mp // md // mr;
  in builtins.mapAttrs markDeps ( getDepFields depFields x );

  normalizedDepsAll = normalizedDepFields allDepFields;


# ---------------------------------------------------------------------------- #

  getNormalizedDeps = {
    optional ? false
  , peer     ? false
  , dev      ? true
  }: x: let
    md = if dev then ["devDependencies"] else [];
    mo = if optional then ["optionalDependencies"] else [];
    mp = if peer then ["peerDependencies"] else [];
    fields = ["dependencies"] ++ md ++ mo ++ mp;
    norm = normalizedDepFields fields x;
    fo = v: ! optional -> ! ( v.optional or false );
    fp = v: ! peer -> ! ( v.peer or false );
    filt = k: v: ( fo v ) && ( fp v );
  in lib.filterAttrs filt norm;


# ---------------------------------------------------------------------------- #

  # Matches "/foo/*/bar", "/foo/*", "*".
  # But NOT "/foo/\*/bar".
  # NOTE: In `.nix' files, "\*" ==> "*", so the "escaped" glob in the example
  #       above is written as : hasGlob "foo/\\*/bar" ==> false
  #       When reading from a file however, the examples above are "accurate".
  hasGlob = p: let g = "[^\\]\\*"; in
    ( builtins.match "(.+${g}.*|.*${g}.+|\\*)" p ) != null;

  hasDoubleGlob = p: let g = "[^\\]\\*\\*"; in
    ( builtins.match "(.+${g}.*|.*${g}.+|\\*\\*)" p ) != null;

  hasSingleGlob = p: let g = "[^\\\\*]\\*"; in
    ( builtins.match "(.+${g}.*|.*${g}.+|\\*)" p ) != null;


# ---------------------------------------------------------------------------- #

  explicitWorkspaces = workspaces:
    builtins.filter ( p: ! ( hasGlob p ) ) workspaces;

  singleGlobWorkspaces = workspaces:
    builtins.filter hasSingleGlob workspaces;

  doubleGlobWorkspaces = workspaces:
    builtins.filter hasDoubleGlob  workspaces;

  ignoreNodeModulesDir = name: type:
    ! ( ( type == "directory" ) && ( ( baseNameOf name ) == "node_modules" ) );

  # Non-Recursive
  dirHasPackageJson = p: builtins.pathExists "${coercePath p}/package.json";


# ---------------------------------------------------------------------------- #

  processWorkspacePath = p: let
    reportDir = d:
      if ( dirHasPackageJson d ) then "${d}/package.json" else null;
    dirs = if ( hasSingleGlob p ) then ( listSubdirs ( dirOf p ) )
           else if ( hasDoubleGlob p ) then ( listDirsRecursive ( dirOf p ) )
           else [p];
    process = dirs: builtins.filter ( x: x != null ) ( map reportDir dirs );
  in if ( ! ( hasGlob ( dirOf p ) ) ) then ( process dirs ) else
    ( throw ( "processGlobEnd: Only globs at the end of paths are " +
              "handled! Cannot process: ${p}" ) );

  workspacePackages = dir: pkgInfo:
    if ! ( pkgInfo ? workspaces.packages ) then [] else
      let processPath = p: processWorkspacePath ( ( toString dir ) + "/${p}" );
      in builtins.concatLists ( map processPath pkgInfo.workspaces.packages );

  readWorkspacePackages = p: let pjp = pkgJsonForPath p; in
    workspacePackages ( dirOf pjp ) ( importJSON' pjp );


# ---------------------------------------------------------------------------- #

  # Given a path-like `p', add `${p}/package.json' if `p' if `p' isn't a path
  # to a `package.json' file already.
  # This is implemented naively, but allows use to directory names and filepaths
  # interchangeably to refer to projects.
  # This is analogous to Nix's `path/to/ --> path/to/default.nix' behavior.
  pkgJsonForPath = p: let
    p' = builtins.unsafeDiscardStringContext ( toString p );
    m = builtins.match "(.*)/" p';
    s = if ( m == null ) then p' else ( builtins.head m );
  in if ( p' == "" ) then "package.json" else
    if ( ( baseNameOf p ) == "package.json" ) then s else "${s}/package.json";


# ---------------------------------------------------------------------------- #

  pkgJsonFromPath = p: let
    pjs = pkgJsonForPath p;
  in assert builtins.pathExists pjs;
    importJSON' pjs;


# ---------------------------------------------------------------------------- #

  # Like `pkgJsonFromPath', except that if we don't find `package.json'
  # initially, we will check two layers of subdirectories.
  # This is intended to locate a `package.json' symlink which may exist in a
  # `linkToPath' Drv such as:
  #   /nix/store/XXXXXXXX...-source/@foo/bar/package.json
  #
  # With that use case in mind we sanity check that if we do search subdirs that
  # we find EXACTLY ONE `package.json' file.
  # This is to avoid "randomly" returning a `node_modules/baz/package.json' in
  # a project directory.
  #
  # Additionally, if `x' already appears to be the result of `importJSON' then
  # we just return `x'.
  #
  # NOTE: This does NOT handle paths to tarballs.
  # Because this is a `lib' function, we don't use any system dependent
  # derivations, because this would cause us to output a different instance of
  # `lib' for each supported system.
  # In the field, extending this function to add support for Tarballs is
  # likely a good idea.
  # XXX: You can actually do this using `builtins.fetch*' but adding additional
  # conditionals to handle "is impure allowed?" or "can we find a SHA?" is a
  # pain in the ass.
  # This function already does a ton of heavy lifting.
  getPkgJson = x: let
    inherit (builtins) isAttrs filter concatLists length head typeOf;
    inherit (lib.libfs) mapSubdirs;
    fromDrvRoot = pkgJsonFromPath x.outPath;
    pjsInSubdirs = let
      dirs1 = listSubdirs x.outPath;
      dirs2 = concatLists ( mapSubdirs listSubdirs x.outPath );
      finds = filter dirHasPackageJson ( dirs1 ++ dirs2 );
      found = pkgJsonFromPath ( head finds );
      ns    = length finds;
    in if ns == 1 then found else
       if 1 < ns  then throw "Found multiple package.json files in subdirs" else
       throw "Could not find package.json in subdirs";
    fromPath = let
      pjp = "${lib.coercePath x}/package.json";
    in if ( builtins.pathExists pjp ) then ( importJSON' pjp )
                                      else pjsInSubdirs;
  in if lib.isCoercibleToPath x then fromPath else if isAttrs x then x else
     throw "Cannot get package.json from type: ${typeOf x}";


# ---------------------------------------------------------------------------- #

  pkgJsonHasBin = x: let
    pjs = getPkgJson x;
  in pjs ? bin || pjs ? directories.bin;


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
      parted = ( partition ( x: isFunction x.value ) alist );
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
  hasInstallScript = x: let
    pjs      = getPkgJson x;
    explicit = pjs.hasInstallScript or false;  # for lock entries
    scripted = ( pjs ? scripts ) && builtins.any ( a: pjs.scripts ? a ) [
      "preinstall" "install" "postinstall"
    ];
    asPath = lib.libpath.coercePath x;
    isDir = let
      inherit (lib.libpath) isCoercibleToPath categorizePath;
    in ( pjs != x ) && ( isCoercibleToPath x ) &&
       ( ( categorizePath asPath ) == "directory" );
    hasGyp = isDir && ( builtins.pathExists "${asPath}/binding.gyp" );
  in explicit || scripted || hasGyp;


# ---------------------------------------------------------------------------- #

in {
  #inherit canonicalizePkgName unCanonicalizePkgName;
  inherit
    parsePkgJsonNameField
    normalizePkgScope
    asLocalTarballName
    asNpmRegistryTarballName
    mkPkgInfo
    workspacePackages
    readWorkspacePackages
    importJSON'
    pkgJsonForPath
    pkgJsonFromPath
    getPkgJson
    pkgJsonHasBin
    rewriteDescriptors
    hasInstallScript
    node2nixName
  ;

  inherit
    allDepFields
    depMetaFields
    allDependencies
    getDepFields
    normalizedDepFields
    normalizedDepsAll
    getNormalizedDeps
  ;

  readPkgInfo = path: mkPkgInfo ( pkgJsonFromPath path );
}

# ---------------------------------------------------------------------------- #
#
#
#
# ---------------------------------------------------------------------------- #
