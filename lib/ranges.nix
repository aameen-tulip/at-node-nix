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

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  inherit (yt.PkgInfo) RE;

  inherit (lib.libsemver)
    semverConst
    semverConstsEq
    semverConstRange
    semverConstExact
    semverConstTilde
    semverConstCaret
    semverConstGt
    semverConstGe
    semverConstLt
    semverConstLe
    semverConstAnd
    semverConstOr
    semverConstAny
    semverConstFail

    semverConstRangeEq
  ;

# ---------------------------------------------------------------------------- #

  tryYankVersionCore = str: let
    m = builtins.match "([^-+]+)(-[^+]+)?(\\+.*)?" str;
  in if m == null then null else builtins.head m;

  yankVersionCore =
    yt.defun [yt.PkgInfo.Strings.version yt.PkgInfo.Strings.version_core]
             tryYankVersionCore;


# ---------------------------------------------------------------------------- #

  tryYankPreTag = str: let
    m = builtins.match "[^-+]+-([^+]+)(\\+.*)?" str;
  in if m == null then null else builtins.head m;

  yankPreTag = yt.defun [yt.PkgInfo.Strings.version yt.PkgInfo.Strings.pre_tag]
                        tryYankPreTag;


# ---------------------------------------------------------------------------- #

  tryYankBuildMeta = str: let
    m = builtins.match "[^-+]+(-[^+]+)?\\+(.*)" str;
  in if m == null then null else builtins.elemAt m 1;

  yankBuildMeta =
    yt.defun [yt.PkgInfo.Strings.version yt.PkgInfo.Strings.build_meta]
             tryYankBuildMeta;


# ---------------------------------------------------------------------------- #

  parseVersionConstraint' = str: let
    inherit (builtins) head elemAt match length;
    ws         = "[ \t\n\r]";
    mods       = "[~^]";
    cmpPatt    = "([<>]=?|=?[<>]|=)";
    betPatt    = "(${ws}-|-${ws})";
    modPatt    = "(${mods})?(${RE.version_p})";
    cmpVerPatt = "(${cmpPatt}${ws}*(${RE.version_p})|(${RE.version_p})${ws}*${cmpPatt})";
    rangePatt  = "(${RE.version_p})${ws}*${betPatt}${ws}*(${RE.version_p})";
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
    ops   = [/*","*/ "&&" "||"];
    #sp    = builtins.split " ?(,|[|][|]|&&) ?" str;
    sp    = builtins.split " ?([|][|]|&&) ?" str;
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

  tryParseSemverStrict = v: let
    core = tryYankVersionCore v;
    cm   = builtins.match "${RE.num_p}(\\.${RE.num_p}(\\.${RE.num_p})?)?" core;
  in if cm == null then null else {
    major     = builtins.head cm;
    minor     = builtins.elemAt cm 2;
    patch     = builtins.elemAt cm 4;
    preTag    = tryYankPreTag v;
    buildMeta = tryYankBuildMeta v;
  };

  parseSemverStrict = v:
    yt.defun [yt.PkgInfo.Strings.version ( yt.attrs yt.any )]
             tryParseSemverStrict;



# ---------------------------------------------------------------------------- #

  # Split a version string into a labeled set of subcomponents following
  # semver spec.
  tryParseSemverRoundDown = v: let
    strict = tryParseSemverStrict v;
    fno    = field: if strict.${field} == null then "0" else strict.${field};
  in if strict == null then null else {
    major  = fno "major";
    minor  = fno "minor";
    patch  = fno "patch";
    preTag =
      if strict.preTag != null then strict.preTag else
      if ( strict.minor == null ) || ( strict.patch == null ) then null else
      tryYankPreTag v;
    buildMeta = tryYankBuildMeta v;
  };

  # FIXME: define struct
  parseSemverRoundDown =
    yt.defun [yt.PkgInfo.Strings.version ( yt.attrs yt.any )]
             tryParseSemverRoundDown;


# ---------------------------------------------------------------------------- #

  # Used to bump loose version numbers when they used in comparators/ranges.
  # These are also used to normalize "1.x" strings.
  #   1     -> 2.0.0-0
  #   1.0   -> 1.1.0-0
  #   1.0.0 -> 1.0.0
  tryParseSemverRoundUp = v: let
    strict = tryParseSemverStrict v;
    incs   = s: toString ( ( builtins.fromJSON s ) + 1 );
    loose  = parseSemverRoundDown v;
  in if strict == null then null else loose // {
    major =
      if strict.major == null then "0" else
      if strict.minor == null then incs strict.major else
      strict.major;
    minor =
      if strict.minor == null then "0" else
      if strict.patch == null then incs strict.minor else
      strict.minor;
    preTag = let
      tag  = if strict.preTag != null then [strict.preTag] else [];
      preV = if ( strict.minor == null ) || ( strict.patch == null )
             then ["0"]
             else [];
      parts = tag ++ preV;
    in if parts == [] then null else
       builtins.concatStringsSep "." ( tag ++ preV );
  };

  parseSemverRoundUp = yt.defun [yt.PkgInfo.Strings.version ( yt.attrs yt.any )]
                                tryParseSemverRoundUp;


# ---------------------------------------------------------------------------- #

  cleanVersion = v: let
    sv   = builtins.head ( builtins.match "v?(.*)" v );
    m    = builtins.match "([^-+]+)(-[^+]+(\\+.*)?)?" sv;
    core = builtins.head m;
    post = builtins.elemAt m 1;
    sx   = builtins.replaceStrings [".x" ".X" ".*"] ["" "" ""] core;
  in if m == null then sv else
     if post == null then sx else
     "${sx}${post}";


# ---------------------------------------------------------------------------- #

  # Fills missing fields in versions, and strips leading "v".
  # "v1.0"            ==> "1.0.0-0"
  # "v1.2.3-X.4+5Y.6" ==> "1.2.3-X.4+5Y.6"
  # NOTE: this is effective a `toString' for the parsed semver object.
  normalizeVersion' = parser: v: let
    clean = cleanVersion v;
    ps    = parser clean;
    np    = "${ps.major}.${ps.minor}.${ps.patch}";
    nb    = if ps.preTag == null then "" else "-${ps.preTag}";
    b     = if ps.buildMeta == null then "" else "+${ps.buildMeta}";
  in if ps == null then null else np + nb + b;

  normalizeVersionRoundDown = normalizeVersion' parseSemverRoundDown;
  normalizeVersionRoundUp   = normalizeVersion' parseSemverRoundUp;
  tryNormalizeVersionRoundDown = normalizeVersion' tryParseSemverRoundDown;
  tryNormalizeVersionRoundUp   = normalizeVersion' tryParseSemverRoundUp;

# ---------------------------------------------------------------------------- #

  tryParseSemverX = v: let
    from = tryNormalizeVersionRoundDown v;
    to   = tryNormalizeVersionRoundUp   v;
  in if ( from == null ) || ( to == null ) then null
                                           else semverConstRange from to;

  parseSemverX = let
    argt = yt.PkgInfo.Strings.descriptor;
  in yt.defun [argt yt.any] tryParseSemverX;


# ---------------------------------------------------------------------------- #

  # TODO: legacy parseVersionConstraint' deprecation.
  # The X parsing wasn't a part of my first draft of the regexes.
  # the regex pattern is a clusterfuck though so rather than fooling with it
  # I'm going to split that thing up as I run into edge cases or fixes that
  # need to be applied.
  parseSemverStatement = v: let
    parsed   = parseVersionConstraint' ( cleanVersion v );
    forMod   = semverConst { op = parsed.mod; arg1 = parsed.version; };
    forRange = semverConstRange parsed.from parsed.to;
    forCmp = let
      inherit (parsed) left right;
      const1 = semverConst { inherit (left) op; arg1 = left.version; };
      const2 = semverConst { inherit (right) op; arg1 = right.version; };
    in if right.op == null then const1 else semverConstAnd const1 const2;
    isPartial =
      ( lib.test "[^-]+\\.[xX*].*" v ) ||
      ( ( ( parsed.mod or null ) == "=" ) &&
        ( ! ( lib.test "[^0-9]+\\.[^0-9]+\\.[0-9]+(-.*)?" v ) ) );
  in if builtins.elem v ["" "*"] then semverConstAny else
     if isPartial then parseSemverX v else
     if parsed.type == "cmp" then forCmp else
     if parsed.type == "range" then forRange else
     if parsed.type == "mod" then forMod else
     throw "Unrecognized semver type: ${parsed.type}";

  parseSemver = v: let
    sp     = builtins.split " ?[|][|] ?" v;
    parsed = map parseSemverStatement ( builtins.filter builtins.isString sp );
  in builtins.foldl' semverConstOr ( builtins.head parsed )
                                   ( builtins.tail parsed );


# ---------------------------------------------------------------------------- #

in {
  inherit
    sortVersions'
    sortVersionsD
    sortVersionsA
    sortVersions

    isRelease
    latestRelease

    tryYankVersionCore yankVersionCore
    tryYankPreTag      yankPreTag
    tryYankBuildMeta   yankBuildMeta

    parseVersionConstraint'

    tryParseSemverStrict    parseSemverStrict
    tryParseSemverRoundDown parseSemverRoundDown
    tryParseSemverRoundUp   parseSemverRoundUp

    cleanVersion

    tryNormalizeVersionRoundDown
    tryNormalizeVersionRoundUp
    normalizeVersionRoundDown
    normalizeVersionRoundUp

    tryParseSemverX
    parseSemverX

    parseSemverStatement
    parseSemver
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
