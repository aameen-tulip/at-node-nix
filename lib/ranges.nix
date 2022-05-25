{ lib ? ( import <nixpkgs> {} ).lib }:
/**
 * Range comparators:
 *   =   Used if no qualifier is stated ( "foo@1.0" is really "foo@=1.0" )
 *   <=, >=, <, > allow two version specs but do latest/min are assumed when only one is given.
 *  || separate comparator expressions.
 *
 *  x - y  "ranges" are syntactic sugar for ">=x <=y"
 *
 *  With subversions there's a special caveat:
 *  1.2.3 - 2.3  :=  >=1.2.3 <2.4.0-0
 *  1.2.3 - 2    :=  >=1.2.3 <3.0.0-0
 */

let
  sortVersions' = descending: versions:
    let
      inherit (builtins) compareVersions sort;
      cmp' = a: b: ( compareVersions a b ) >= 0;
      cmp  = if descending then cmp' else ( a: b: ! ( cmp' a b ) );
    in sort cmp versions;

  sortVersionsD = sortVersions' true;
  sortVersionsA = sortVersions' false;

  # Determine if a version string is a "release" version.
  # Release version strings must not contain a pre-release "tag", but may still
  # contain a pre-version of 0.
  # ( "X.Y.Z-0" is sometimes used to indicate a relase version explicitly )
  isRelease = v: ( builtins.match ".*(-[^0]).*" v ) == null;

  latestRelease = vs: let inherit (builtins) filter head; in
    head ( sortVersionsD ( filter isRelease vs ) );


  # Split a version string into a list of 6 components following semver spec.
  semverSplit = v:
    let
      np        = "(0|[1-9][0-9]*)";
      anum      = "[0-9a-zA-Z-]";
      anp       = "(0|[1-9][0-9]*|[0-9]*[a-zA-Z-]${anum}*)";
      corePatt  = ''${np}(\.${np}(\.${np})?)?'';
      prePatt   = ''(-${anp}(\.${anp})?)?'';
      buildPatt = ''(\+(${anum}+(\.[0-9a-zA-Z]+)*))?'';
      patt      = corePatt + prePatt + buildPatt;
      matched   = builtins.match patt v;
      # "1.0.0-beta+exp.sha.5114f85" ==>
      # [ "1" ".0.0-beta" "0" ".0-beta" "0" "-beta" "beta" null null "+exp.sha.5114f85" "exp.sha.5114f85" ".5114f85" ]
      # "1.2.3-X.4+5Y.6" ==>
      # [ "1" ".2.3-X.4" "2" ".3-X.4" "3" "-X.4" "X" ".4" "4" "+5Y.6" "5Y.6" ".6" ]
      # Keep fields [0, 2, 4, 6, 8, 10]
      keeps = map ( i: builtins.elemAt matched i ) [0 2 4 6 8 10];
    in if ( matched == null ) then [null null null null null null] else keeps;

  # Split a version string into a labeled set of subcomponents following
  # semver spec.
  parseSemver = v:
    let
      svs = semverSplit v;
      at  = builtins.elemAt svs;
    in {
      major = let p = at 0; in if ( p == null ) then "0" else p;
      minor = let p = at 1; in if ( p == null ) then "0" else p;
      patch = let p = at 2; in if ( p == null ) then "0" else p;
      preTag = at 3;
      preVer = at 4;
      buildMeta = at 5;
    };

  # Fills missing fields in versions, and strips leading "v".
  # "v1.0"            ==> "1.0.0-0"
  # "v1.2.3-X.4+5Y.6" ==> "1.2.3-X.4+5Y.6"
  normalizeVersion = v:
    let
      sv = builtins.head ( builtins.match "v?(.*)" v );
      ps = parseSemver sv;
      pre = if ( ps.preTag == null ) then "0"    else
            if ( ps.preVer == null ) then ps.preTag else
                                         ( ps.preTag + "." + ps.preVer );
      nb = "${ps.major}.${ps.minor}.${ps.patch}-${pre}";
      b  = if ( ps.buildMeta != null ) then ( "+" + ps.buildMeta ) else "";
    in nb + b;

in {
  inherit sortVersions' sortVersionsD sortVersionsA;
  sortVersions = sortVersionsA;
  inherit isRelease latestRelease;
  inherit semverSplit parseSemver normalizeVersion;
}
