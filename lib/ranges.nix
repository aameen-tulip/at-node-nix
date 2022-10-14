# ============================================================================ #
#
# Range comparators:
#   =   Used if no qualifier is stated ( "foo@1.0" is really "foo@=1.0" )
#   <=, >=, <, > allow two version specs but do latest/min are assumed when only
#                one is given.
#  || separate comparator expressions.
#
#  x - y  "ranges" are syntactic sugar for ">=x <=y"
#
#  With subversions there's a special caveat:
#  1.2.3 - 2.3  :=  >=1.2.3 <2.4.0-0
#  1.2.3 - 2    :=  >=1.2.3 <3.0.0-0
#
# ---------------------------------------------------------------------------- #
#
# TODO: handle `&&', `||', whitespace, and call evaluator from `ak-nix'.
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #


  versionRE = let
    np        = "(0|[1-9][0-9]*)";
    anum      = "[0-9a-zA-Z-]";
    anp       = "(0|[1-9][0-9]*|[0-9]*[a-zA-Z-]${anum}*)";
    corePatt  = ''${np}(\.${np}(\.${np})?)?'';
    prePatt   = ''(-${anp}(\.${anp})?)?'';
    buildPatt = ''(\+(${anum}+(\.[0-9a-zA-Z]+)*))?'';
  in corePatt + prePatt + buildPatt;

  parseVersionConstraint' = str: let
    inherit (builtins) head elemAt match length;
    ws         = "[ \t\n\r]";
    mods       = "[~^]";
    cmpPatt    = "([<>]=?|=?[<>]|=)";
    betPatt    = "(${ws}-|-${ws})";
    modPatt    = "(${mods})?(${versionRE})";
    cmpVerPatt = "(${cmpPatt}${ws}*(${versionRE})|(${versionRE})${ws}*${cmpPatt})";
    rangePatt  = "(${versionRE})${ws}*${betPatt}${ws}*(${versionRE})";
    termPatt   = "${ws}*(${cmpVerPatt}(${ws}*${cmpVerPatt})?|${rangePatt}|${modPatt})${ws}*";
    # We have to escape "|" using "[|]", NOT "\|".
    stPatt     = "${termPatt}([|][|]${termPatt})*";
    matched = match stPatt str;
    # FIXME: This indexing is Nightmarish.
    term        = head matched;
    restTerms   = elemAt matched ( ( length matched ) / 2 );
    matchRange  = match rangePatt term;
    matchMod    = match modPatt term;
    matchCmpVer = match "${cmpVerPatt}(${ws}*${cmpVerPatt})?" term;

    fromRange = let
      left   = head matchRange;
      right  = elemAt matchRange ( ( ( length matchRange ) / 2 ) + 1 );
      sorted = sortVersionsA [left right];
    in { from = head sorted; to = elemAt sorted 1; type = "range"; };

    fromMod = let
      m' = head matchMod;
    in {
      mod     = if ( m' == null ) then "=" else m';
      version = elemAt matchMod 1;
      type    = "mod";
    };

    fromCmp = let
      left  = head matchCmpVer;
      right = elemAt matchCmpVer ( ( ( length matchCmpVer ) / 2 ) + 1 );
      getOp = e: if e == null then null else
                 head ( match "[^<>=]*([<>=]+)[^<>=]*" e );
      getVer = e: if e == null then null else
                    head ( match "[<>= \t\n\r]*([^<>= \t\n\r]+)[<>= \t\n\r]*" e );
      parseCmp = e: { op = getOp e; version = getVer e; };
    in { left = parseCmp left; right = parseCmp right; type = "cmp"; };

    rest = if ( restTerms != null ) then ( parseVersionConstraint' restTerms )
                                    else null;
  in if ( matchRange != null )  then ( fromRange // { inherit rest; } ) else
     if ( matchMod != null )    then ( fromMod   // { inherit rest; } ) else
     if ( matchCmpVer != null ) then ( fromCmp   // { inherit rest; } ) else
     throw "Could not parse version constraint: ${str}";


# ---------------------------------------------------------------------------- #

  # NOTE: `ak-nix' added robust range and comparator objects and predicates.
  # For any complex expressions which `&&', `||', or ranges defer to those.

  _verCmp = o: a: b: o ( builtins.compareVersions a b ) 0;
  vg      = _verCmp ( a: b: a > b );
  vge     = _verCmp ( a: b: a >= b );
  vl      = _verCmp ( a: b: a < b );
  vle     = _verCmp ( a: b: a <= b );
  ve      = _verCmp ( a: b: a == b );


  # TODO: you extended the version parser recently to support the FIXME issue.
  # But you still need to implement this parser.
  parseVersionConstraint = str: let
    inherit (builtins) head compareVersions;
    parsed = parseVersionConstraint str;
    # FIXME: this needs to round up partials like "1.2.3 - 1.3" ==> "1.2.3 - 1.4.0"
    fromRange = { from, to }: v: ( vge from v ) && ( vle to v );
    fromCmp   = null;
    fromMod   = null;
  in null;


  parseSemverStatements = str: let
    ops   = ["," "&&" "||"];
    sp    = builtins.split " ?(,|[|][|]|&&) ?" str;
    len   = builtins.length sp;
    # FIXME
    tok = { left, op, right }: {
      left = builtins.head sp;
      op   = builtins.elemAt sp 1;
    };
  in if len <= 1 then str else null;


# ---------------------------------------------------------------------------- #

  sortVersions' = descending: versions: let
    inherit (builtins) compareVersions sort;
    cmp' = a: b: ( compareVersions a b ) >= 0;
    cmp  = if descending then cmp' else ( a: b: ! ( cmp' a b ) );
  in sort cmp versions;

  sortVersionsD = sortVersions' true;
  sortVersionsA = sortVersions' false;
  sortVersions  = sortVersionsA;


# ---------------------------------------------------------------------------- #

  # Determine if a version string is a "release" version.
  # Release version strings must not contain a pre-release "tag", but may still
  # contain a pre-version of 0.
  # ( "X.Y.Z-0" is sometimes used to indicate a relase version explicitly )
  isRelease = v: ( builtins.match ".*(-[^0]).*" v ) == null;

  latestRelease = vs:
    builtins.head ( sortVersionsD ( builtins.filter isRelease vs ) );


# ---------------------------------------------------------------------------- #

  # Split a version string into a list of 6 components following semver spec.
  semverSplit = v: let
    matched = builtins.match versionRE v;
    # "1.0.0-beta+exp.sha.5114f85" ==>
    # [ "1" ".0.0-beta" "0" ".0-beta" "0" "-beta" "beta" null null "+exp.sha.5114f85" "exp.sha.5114f85" ".5114f85" ]
    # "1.2.3-X.4+5Y.6" ==>
    # [ "1" ".2.3-X.4" "2" ".3-X.4" "3" "-X.4" "X" ".4" "4" "+5Y.6" "5Y.6" ".6" ]
    # Keep fields [0, 2, 4, 6, 8, 10]
    keeps = map ( builtins.elemAt matched ) [0 2 4 6 8 10];
  in if ( matched == null ) then [null null null null null null] else keeps;


# ---------------------------------------------------------------------------- #

  # Split a version string into a labeled set of subcomponents following
  # semver spec.
  parseSemver = v: let
    svs = semverSplit v;
    at  = builtins.elemAt svs;
  in {
    major  = let p = at 0; in if ( p == null ) then "0" else p;
    minor  = let p = at 1; in if ( p == null ) then "0" else p;
    patch  = let p = at 2; in if ( p == null ) then "0" else p;
    preTag = let p = at 3; in if ( ( at 1 ) == null ) || ( ( at 2 ) == null )
                              then "0" else p;
    preVer    = at 4;
    buildMeta = at 5;
  };

  # Used to bump loose version numbers when they used in comparators/ranges.
  # These are also used to normalize "1.x" strings.
  #   1     -> 2.0.0-0
  #   1.0   -> 1.1.0-0
  #   1.0.0 -> 1.0.0
  parseSemverRoundUp = v: let
    svs  = semverSplit v;
    at   = builtins.elemAt svs;
    majM = at 0;
    minM = at 1;
    patM = at 2;
  in {
    major =
      if ( majM == null ) then "0" else
      if minM == null then toString ( ( builtins.fromJSON majM ) + 1 ) else
      majM;
    minor =
      if ( minM == null ) then "0" else
      if patM == null then toString ( ( builtins.fromJSON minM ) + 1 ) else
      minM;
    patch     = let p = at 2; in if ( p == null ) then "0" else p;
    preTag    = if ( minM == null ) || ( patM == null ) then "0" else ( at 3 );
    preVer    = at 4;
    buildMeta = at 5;
  };


# ---------------------------------------------------------------------------- #

  # Fills missing fields in versions, and strips leading "v".
  # "v1.0"            ==> "1.0.0-0"
  # "v1.2.3-X.4+5Y.6" ==> "1.2.3-X.4+5Y.6"
  # NOTE: this is effective a `toString' for the parsed semver object.
  normalizeVersion' = parser: v: let
    sv  = builtins.head ( builtins.match "v?(.*)" v );
    ps  = parser sv;
    pre = if ( ps.preTag == null ) then null else
          if ( ps.preVer == null ) then ps.preTag else
          ( ps.preTag + "." + ps.preVer );
    np  = "${ps.major}.${ps.minor}.${ps.patch}";
    nb  = if pre == null then "" else "-${pre}";
    b   = if ( ps.buildMeta != null ) then ( "+" + ps.buildMeta ) else "";
  in np + nb + b;

  normalizeVersion        = normalizeVersion' parseSemver;
  normalizeVersionRoundUp = normalizeVersion' parseSemverRoundUp;


# ---------------------------------------------------------------------------- #

in {
  inherit
    versionRE

    sortVersions'
    sortVersionsD
    sortVersionsA
    sortVersions

    isRelease
    latestRelease

    parseVersionConstraint'
    semverSplit
    parseSemver
    parseSemverRoundUp

    normalizeVersion
    normalizeVersionRoundUp
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
