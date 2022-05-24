{ lib    ? ( import <nixpkgs> {} ).lib
, libstr ? import ./strings.nix { inherit lib; }
}:
let
  importJSON' = file: let inherit (builtins) fromJSON readFile; in
    fromJSON ( libstr.removeSlashSlashComments ( readFile file ) );

/* -------------------------------------------------------------------------- */

  # Split a `package.json' name field into "scope" ( if any ) and the
  # package name, yielding a set with the original name, "pname", and scope.
  # Ex:
  #   "@foo/bar" ==> { name = "@foo/bar"; pname = "bar"; scope = "foo" }
  #   "bar" ==> { name = "bar"; pname = "bar"; scope = null }
  isPkgJsonName = name:
    null != ( builtins.match "(@[^/@.]+/)?([^/@.]+)" name );

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
  canonicalizePkgName =
    builtins.replaceStrings ["@"      "/"         "-"       "."]
                            ["__at__" "__slash__" "__bar__" "__dot__"];

  unCanonicalizePkgName =
    builtins.replaceStrings ["__at__" "__slash__" "__bar__" "__dot__"]
                            ["@"      "/"         "-"       "."];


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
      canonicalName = canonicalizePkgName name;
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

in {
  inherit parsePkgJsonNameField;
  inherit normalizePkgScope;
  inherit canonicalizePkgName unCanonicalizePkgName;
  inherit asLocalTarballName asNpmRegistryTarballName;
  inherit mkPkgInfo;
  inherit allDependencies;

  readPkgInfo = file: mkPkgInfo ( importJSON' file );
}
