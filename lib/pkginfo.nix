{ akJSONLib ? import ( builtins.fetchurl
                        ( "https://raw.githubusercontent.com/" +
                          "aakropotkin/ak-nix/main/lib/json.nix" ) )
}:
let
  inherit (akJSONLib) readJSON;

  # Split a `package.json' name field into "scope" ( if any ) and the
  # package name, yielding a set with the original name, "pname", and scope.
  # Ex:
  #   "@foo/bar" ==> { name = "@foo/bar"; pname = "bar"; scope = "foo" }
  #   "bar" ==> { name = "bar"; pname = "bar"; scope = null }
  pkgNameSplit = name:
    # "@foo/bar" ==> [ "@foo/" "foo" "bar" ]
    let splitName = builtins.match "(@([^/]+)/)?(.*)" name;
    in {
      inherit name;
      pname = builtins.elemAt splitName 2;
      scope = builtins.elemAt splitName 1;
    };

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

  asTarballName = {
    name  ? if scope != null then "@${scope}/${pname}" else pname
  , pname ? builtins.elemAt 1 ( builtins.match "(@[^/]+/)?([^]+)" name )
  , scope ? builtins.head ( builtins.match "@([^/]+)/.*" name )
  , version
  }: if scope != null then "${scope}-${pname}-${version}.tgz"
                      else "${pname}-${version}.tgz";

  mkPkgInfo = args@{ name, version, ... }:
    let inherit ( pkgNameSplit name ) pname scope;
    in args // {
      inherit pname scope;
      tarballName = asTarballName { inherit name pname scope version; };
      scopeDir = if scope != null then "@${scope}/" else "";
      canonicalName = canonicalizePkgName name;
    };

in {
  inherit pkgNameSplit canonicalizePkgName unCanonicalizePkgName asTarballName
          mkPkgInfo;
  readPkgInfo = file: mkPkgInfo ( readJSON file );
}
