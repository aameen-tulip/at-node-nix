{ akJSONLib ? import ( builtins.fetchurl
                        ( "https://raw.githubusercontent.com/" +
                          "aakropotkin/ak-nix/main/lib/json.nix" ) )
}:
let
  inherit (akJSONLib) stripCommentsJSONStr readJSON;

  pkgNameSplit = name:
    let splitName = builtins.match "(@([^/]+)/)?(.*)" name;
    in {
      inherit name;
      pname = builtins.elemAt splitName 2;
      scope = builtins.elemAt splitName 1;
     };

  canonicalizePkgName =
    builtins.replaceStrings ["@"    "/"       "-"     "."]
                            ["_at_" "_slash_" "_bar_" "_dot_"];

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
  inherit pkgNameSplit canonicalizePkgName asTarballName mkPkgInfo;
  readPkgInfo = file: mkPkgInfo ( readJSON file );
}
