{ lib }:
let

  importJSON' = file: let inherit (builtins) fromJSON readFile; in
    fromJSON ( lib.libstr.removeSlashSlashComments ( readFile file ) );

/* -------------------------------------------------------------------------- */

  # Split a `package.json' name field into "scope" ( if any ) and the
  # package name, yielding a set with the original name, "pname", and scope.
  # Ex:
  #   "@foo/bar" ==> { name = "@foo/bar"; pname = "bar"; scope = "foo" }
  #   "bar" ==> { name = "bar"; pname = "bar"; scope = null }
  isPkgJsonName = name: null != ( builtins.match "(@[^/@.]+/)?([^/@.]+)" name );

  parsePkgJsonNameField = name:
    assert ( isPkgJsonName name );
    let
      inherit (builtins) substring length stringLength elemAt head;
      sname  = lib.splitString "/" name;
      len    = length sname;
      dropStr1  = str: substring 1 ( stringLength str ) str;
    in if ( len == 1 ) then { scope = null; pname = name; inherit name; }
       else if ( len == 2 ) then {
         scope = dropStr1 ( head sname );
         pname = elemAt sname 1;
         inherit name;
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

  asLocalTarballName = { pname, scope ? null, version }:
    if scope != null then "${scope}-${pname}-${version}.tgz"
                     else "${pname}-${version}.tgz";

  asNpmRegistryTarballName = { pname, version }: "${pname}-${version}.tgz";


/* -------------------------------------------------------------------------- */

  mkPkgInfo = args@{ name, version, ... }:
    let inherit ( parsePkgJsonNameField name ) pname scope;
    in args // {
      inherit pname scope;

      localTarballName =
        asLocalTarballName { inherit name pname scope version; };
      registryTarballName =
        asNpmRegistryTarballName { inherit name pname version; };

      scopeDir = if scope != null then "@${scope}/" else "";
      #canonicalName = canonicalizePkgName name;
    };


/* -------------------------------------------------------------------------- */

  allDependencies =
    { dependencies         ? {}
    , devDependencies      ? {}
    , peerDependencies     ? {}
    , optionalDependencies ? {}
    , ...
    }: optionalDependencies //
       peerDependencies     //
       devDependencies      //
       dependencies;


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
  dirHasPackageJson = p: let
    nodes = builtins.readDir p;
    isPkgJson = name: type:
      ( name == "package.json" ) && ( type != "directory" );
    tested = builtins.mapAttrs isPkgJson nodes;
  in builtins.any ( x: x ) ( builtins.attrValues tested );


/* -------------------------------------------------------------------------- */

  listDirsRecursive = dir: lib.flatten ( lib.mapAttrsToList ( name: type:
    if ( ( type == "directory" ) && ( ignoreNodeModulesDir name type ) ) then
      listDirsRecursive ( dir + "/${name}" )
    else
      dir + "/${name}" ) ( builtins.readDir dir ) );

  listSubdirs = dir: let
    processDir = name: type:
      if ( type == "directory" ) then dir + "/${name}" else null;
    processed = lib.mapAttrsToList processDir ( builtins.readDir dir );
  in builtins.filter ( x: x != null ) processed;


/* -------------------------------------------------------------------------- */

  processWorkspacePath = p: let
    reportDir = d:
      if ( dirHasPackageJson d ) then "${d}/package.json" else null;

    dirs = if ( hasSingleGlob p ) then ( listSubdirs ( dirOf p ) )
           else if ( hasDoubleGlob p ) then ( listDirsRecursive ( dirOf p ) )
           else [p];

    process = dirs: builtins.filter ( x: x != null ) ( map reportDir dirs );
  in if ( hasGlob ( dirOf p ) )
     then throw ( "processGlobEnd: Only globs at the end of paths are " +
                  "handled! Cannot process: ${p}" )
     else process dirs;

  workspacePackages = dir: pkgInfo:
    if ! ( pkgInfo ? workspaces.packages ) then [] else
      let processPath = p: processWorkspacePath ( ( toString dir ) + "/${p}" );
      in builtins.concatLists ( map processPath pkgInfo.workspaces.packages );


/* -------------------------------------------------------------------------- */

  pkgJsonForPath = p:
    if ( ( baseNameOf p ) == "package.json" )
    then ( toString p )
    else ( ( toString p ) + "/package.json" );


/* -------------------------------------------------------------------------- */

  readWorkspacePackages = p: let pjp = pkgJsonForPath p; in
    workspacePackages ( dirOf pjp ) ( importJSON' pjp );


/* -------------------------------------------------------------------------- */




/* -------------------------------------------------------------------------- */

in {
  inherit parsePkgJsonNameField;
  inherit normalizePkgScope;
  #inherit canonicalizePkgName unCanonicalizePkgName;
  inherit asLocalTarballName asNpmRegistryTarballName;
  inherit mkPkgInfo;
  inherit allDependencies;
  inherit workspacePackages readWorkspacePackages;
  inherit importJSON';

  readPkgInfo = file: mkPkgInfo ( importJSON' file );
}
