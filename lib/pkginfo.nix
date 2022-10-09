# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  inherit (lib) isType setType;
  inherit (lib.libfs) listSubdirs listDirsRecursive;
  inherit (lib.libpath) coercePath;
  inherit (lib.libstr) test;

# ---------------------------------------------------------------------------- #

  # Typeclass for Package/Module "Scope" name.
  Scope = {
    name   = "Scope";
    isType = Scope.ytype.check;
    ytype  = yt.either yt.PkgInfo.Strings.id_part yt.PkgInfo.Structs.scope;
    fromString = let
      inner = str: let
        m     = builtins.match "(@([^@/]+)(/.*)?)" str;
        scope = if m != null then builtins.elemAt m 1 else
                if str == "" then null else str;
      in {
        inherit scope;
        scopedir = if scope == null then "" else "@${scope}/";
      };
    in yt.defun [yt.string yt.PkgInfo.Structs.scope] inner;
    # Writer
    toString = let
      inner = x:
        if builtins.isString x then "@${x}" else
        if x.scope == null then "" else "@${x.scope}";
    in yt.defun [Scope.ytype yt.string] inner;
    # Parser
    fromAttrs = { scope ? null, scopedir ? "@${x.scope}/", ... } @ x:
      if x ? scope then { inherit scope scopedir; } else
      Scope.fromString ( x.ident or x.name );
    # Serializer
    toAttrs = x: { inherit (Scope.coerce x) scope; };
    # Maker
    coerce = let
      inner = x: let
        stringable = ( builtins.isString x ) || ( x ? __toString );
        asStr = if builtins.isAttrs x then x.__toString x else x;
      in if stringable then Scope.fromString asStr else Scope.fromAttrs x;
      ft = yt.either yt.string ( yt.attrs yt.any );
    in yt.defun [ft yt.PkgInfo.Structs.scope] inner;
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

  parsePkgJsonNameField = name: let
    inherit (builtins) substring stringLength;
    dropStr1 = str: substring 1 ( stringLength str ) str;
  in {
    ident = yt.PkgInfo.Strings.identifier name;
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
  normalizePkgScope = str: let
    smatch = builtins.match "@?([^/@]+)(/[^/@0-9][^/@]*(/[1-9][^/@]*)?)?" ( lib.toLower str );
    scope  = builtins.head smatch;
  in if ( ( str == null ) || ( str == "" ) )
     then { scope = null; scopeDir = ""; }
     else if ( smatch == null ) then ( throw "Invalid scope string: ${str}" )
     else { inherit scope; scopeDir = "@${scope}/"; };


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

  # Expand globs in workspace paths for a `package.json' file.
  # XXX: This only supports globs at the end of paths.
  processWorkspacePath = p: let
    dirs = if ( hasSingleGlob p ) then ( listSubdirs ( dirOf p ) )
           else if ( hasDoubleGlob p ) then ( listDirsRecursive ( dirOf p ) )
           else [p];
    process = dirs: builtins.filter ( x: x != null ) dirs;
    msg = "processGlobEnd: Only globs at the end of paths arg handled: ${p}";
  in if ( hasGlob ( dirOf p ) ) then throw msg else ( process dirs );

  # Looks up workspace paths ( if any ) in a `package.json'.
  # This supports either NPM or Yarn style workspace fields
  workspacePackages = dir: pkgInfo: let
    packages = pkgInfo.workspaces.packages or pkgInfo.workspaces or [];
    processPath = p: processWorkspacePath "${toString dir}/${p}";
  in builtins.concatLists ( map processPath packages );

  # Given a path to a project dir or `package.json', return list of ws paths.
  readWorkspacePackages = p: let pjp = pkgJsonForPath p; in
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
  pkgJsonForPath = p: let
    p' = builtins.unsafeDiscardStringContext ( toString p );
    m = builtins.match "(.*)/" p';
    s = if ( m == null ) then p' else ( builtins.head m );
  in if ( p' == "" ) then "package.json" else
    if ( ( baseNameOf p ) == "package.json" ) then s else "${s}/package.json";

  # Reads a `package.json' after `pkgJsonForPath' ( see docs above ).
  pkgJsonFromPath = p: let
    pjs = pkgJsonForPath p;
  in assert builtins.pathExists pjs;
     lib.importJSON' pjs;


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
    in if ( builtins.pathExists pjp ) then ( lib.importJSON' pjp )
                                      else pjsInSubdirs;
  in if lib.isCoercibleToPath x then fromPath else if isAttrs x then x else
     throw "Cannot get package.json from type: ${typeOf x}";


# ---------------------------------------------------------------------------- #

  # `packge.json' files can indicate that they have bins using either the
  # `bin' field ( a string or attrs ), or by specifying a relative path to
  # a directory filled with executables using the `directories.bin' field.
  # This predicate lets us know if we need to handle "any sort of bin stuff"
  # for a `package.json'.
  pkgJsonHasBin = x: let
    pjs = getPkgJson x;
  in ( pjs ? bin ) || ( pjs ? directories.bin );


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

  inherit
    Scope
  ;

  inherit
    mkPkgInfo
    pkgJsonHasBin
    rewriteDescriptors
    hasInstallScript
  ;

  # `package.json' locators
  inherit
    pkgJsonForPath
    pkgJsonFromPath
    getPkgJson
  ;

  # Names
  inherit
    parsePkgJsonNameField
    node2nixName
    normalizePkgScope
    asLocalTarballName
    asNpmRegistryTarballName
  ;

  # Workspaces
  inherit
    workspacePackages
    readWorkspacePackages
    normalizeWorkspaces
  ;

  readPkgInfo = path: mkPkgInfo ( pkgJsonFromPath path );
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
