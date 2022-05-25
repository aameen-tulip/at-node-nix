{ lib ? ( import <nixpkgs> {} ).lib }:
/**
 * REGEX with named components ( for reference ):
 * ^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
 *
 * REGEX with regular capture components:
 * ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
 *
 *
 *
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

# FIXME

let
  sortVersions' = descending: versions:
    let
      inherit (builtins) compareVersions sort;
      cmp' = a: b: ( compareVersions a b ) >= 0;
      cmp  = if descending then cmp' else ( a: b: ! ( cmp' a b ) );
    in sort cmp versions;

  sortVersionsD = sortVersions' true;
  sortVersionsA = sortVersions' false;

  isRelease = v: ( builtins.match ".*(-[^0]).*" v ) == null;

  latestRelease = vs: let inherit (builtins) filter head; in
    head ( sortVersionsD ( filter isRelease vs ) );



  semverSplit = v:
    let
      np  = "(0|[1-9][0-9]*)";
      anp = "(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)";
      mc = acc: patt: "${acc}(${patt})?";
      corePatts = lib.foldr mc ''\.${anp}'' [
        np
        ''\.${np}''
        ''\.${np}''
        ''-${anp}''
      ];
      suffPatt = ''(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z]+)*))?'';
      patt = corePatts + suffPatt;
      matched = builtins.match patt v;
      # "1.0.0-beta+exp.sha.5114f85" ==>
      # [ "1" ".0.0-beta" "0" ".0-beta" "0" "-beta" "beta" null null "+exp.sha.5114f85" "exp.sha.5114f85" ".5114f85" ]
      # "1.2.3-X.4+5Y.6" ==>
      # [ "1" ".2.3-X.4" "2" ".3-X.4" "3" "-X.4" "X" ".4" "4" "+5Y.6" "5Y.6" ".6" ]
      # Keep fields [0, 2, 4, 6, 8, 10]
      keeps = map ( i: builtins.elemAt matched i ) [0 2 4 6 8 10];
    in keeps;

  parseSemver = v:
    let
      svs = semverSplit v;
      at  = builtins.elemAt svs;
      preMajor = at 3;
      preMinor = at 4;
    in {
      major = let p = at 0; in if ( p == null ) then "0" else p;
      minor = let p = at 1; in if ( p == null ) then "0" else p;
      patch = let p = at 2; in if ( p == null ) then "0" else p;
      pre = if ( preMajor == null ) then "0"      else
            if ( preMinor == null ) then preMajor else
                                         ( preMajor + "." + preMinor );
      buildMeta = at 5;
    };

  normalizeVersion = v:
    let
      sv = builtins.head ( builtins.match "v?(.*)" v );
      ps = parseSemver sv;
      nb = "${ps.major}.${ps.minor}.${ps.patch}-${ps.pre}";
      b  = if ( ps.buildMeta != null ) then ( "+" + ps.buildMeta ) else "";
    in nb + b;

in {
  inherit sortVersions' sortVersionsD sortVersionsA;
  sortVersions = sortVersionsA;
  inherit isRelease latestRelease;
  inherit semverSplit parseSemver normalizeVersion;
}
