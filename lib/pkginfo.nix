{ lib }:
let

  inherit (lib) isType setType;
  inherit (lib.libfs) listSubdirs listDirsRecursive;
  inherit (lib.libpath) coercePath;
  inherit (lib.libstr) test;

/* -------------------------------------------------------------------------- */

  # This wipes out any C style comments in JSON files that were written by
  # sub-humans that cannot abide by simple file format specifications.
  # Later this function will be revised to schedule chron jobs which send
  # daily emails to offending projects' authors - recommending various
  # re-education programs they may enroll in.
  importJSON' = file: let inherit (builtins) fromJSON readFile; in
    fromJSON ( lib.libstr.removeSlashSlashComments ( readFile file ) );


/* -------------------------------------------------------------------------- */

  # Split a `package.json' name field into "scope" ( if any ) and the
  # package name, yielding a set with the original name, "pname", and scope.
  # Ex:
  #   "@foo/bar" ==> { name = "@foo/bar"; pname = "bar"; scope = "foo" }
  #   "bar" ==> { name = "bar"; pname = "bar"; scope = null }
  isPkgJsonName = test "(@[^/@.]+/)?([^/@.]+)";

  parsePkgJsonNameField = name: assert ( isPkgJsonName name ); let
    inherit (builtins) substring length stringLength elemAt head;
    sname    = lib.splitString "/" name;
    len      = length sname;
    dropStr1 = str: substring 1 ( stringLength str ) str;
  in if ( len == 1 ) then { scope = null; pname = name; inherit name; } else
     if ( len == 2 ) then {
       inherit name;
       scope = dropStr1 ( head sname );
       pname = elemAt sname 1;
       _type = "";
     } else throw "Invalid package name: ${name}";


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

  # Replace special characters in a Node.js package name to create a name which
  # is usable as a shell variable or ( unquoted ) Nix attribute name.
  # Doing this consistently is essential for organizing package sets.
  # This function may also be used to canonicalize tarball names.
  # Ex:
  #   "@foo/bar-baz"          ==> "__at__foo__slash__bar__bar__baz"
  #   "foo-bar-baz-1.0.0.tgz" ==> "foo__bar__bar__baz__bar__1__dot__0__dot__0__dot__tgz"
  #canonicalizePkgName =
  #  builtins.replaceStrings ["@"      "/"         "-"       "."]
  #                          ["__at__" "__slash__" "__bar__" "__dot__"];

  #unCanonicalizePkgName =
  #  builtins.replaceStrings ["__at__" "__slash__" "__bar__" "__dot__"]
  #                          ["@"      "/"         "-"       "."];


  # FIXME: use the style `yarn2nix' has.
  # It uses these for the tarball names as well, just adding `.tgz'
  #   "@babel-code-frame/code-frame@7.8.3"
  #     ==> "_babel_code_frame___code_frame_7.8.3"
  # To create an offline cache ( yarn v1.x style ) they literally use:
  #   linkfarm "offline" [ { name = "foo"; path = fetchurl {}; } ... ];
  # This won't work with `yarn' v2, since they use a shorted identifier, but
  # it's still a useful style for attribute names.
  #

/* -------------------------------------------------------------------------- */

  # NPM's registry does not include `scope' in its tarball names.
  # However, running `npm pack' DOES produce tarballs with the scope as a
  # a prefix to the name as: "${scope}-${pname}-${version}.tgz".
  asLocalTarballName = { pname, scope ? null, version }:
    if scope != null then "${scope}-${pname}-${version}.tgz"
                     else "${pname}-${version}.tgz";

  asNpmRegistryTarballName = { pname, version }: "${pname}-${version}.tgz";


/* -------------------------------------------------------------------------- */

  mkPkgInfo = args@{ name, version, ... }:
    let inherit ( parsePkgJsonNameField name ) pname scope;
    in args // {
      inherit pname scope;
      _type = "pkginfo";

      localTarballName =
        asLocalTarballName { inherit pname scope version; };
      registryTarballName =
        asNpmRegistryTarballName { inherit pname version; };

      scopeDir = if scope != null then "@${scope}/" else "";
      #canonicalName = canonicalizePkgName name;
    };


/* -------------------------------------------------------------------------- */

  allDependencies = x:
    ( x.optionalDependencies or {} ) // ( x.peerDependencies or {} ) //
    ( x.devDependencies      or {} ) // ( x.dependencies     or {} );


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

  pkgJsonFromPath = p: let
    pjs = pkgJsonForPath p;
  in assert builtins.pathExists pjs;
    importJSON' pjs;


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

  pkgJsonHasBin = x: ( getPkgJson x ) ? bin;


/* -------------------------------------------------------------------------- */

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



/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

in {
  #inherit canonicalizePkgName unCanonicalizePkgName;
  inherit
    parsePkgJsonNameField
    normalizePkgScope
    asLocalTarballName
    asNpmRegistryTarballName
    mkPkgInfo
    allDependencies
    workspacePackages
    readWorkspacePackages
    importJSON'
    pkgJsonForPath
    pkgJsonFromPath
    getPkgJson
    pkgJsonHasBin
    rewriteDescriptors
    hasInstallScript
  ;

  readPkgInfo = path: mkPkgInfo ( pkgJsonFromPath path );
}
