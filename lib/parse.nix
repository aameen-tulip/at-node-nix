# ============================================================================ #
#
# NOTE: These were one of the earliest set of routines written for this project.
# They were largely aimed at processing `yarn.lock(v2)' entries.
# These aren't used in newer `(meta|pkg)Set' style routines; but they
# may be useful to folks who just need some standalone Node.js
# helper routines/parsers.
#
# XXX: The `nameInfo' function is sensitive to `enableStringContextDiscards'.
#
# ---------------------------------------------------------------------------- #

{ lib
, config ? {
    # You better know what you're doing if you change this setting.
    enableStringContextDiscards = false;
  }
, ...
} @ globalAttrs: let

# ---------------------------------------------------------------------------- #

/**
 * Parses a string into an ident.
 *
 * Returns `null` if the ident cannot be parsed.
 *
 * @param string The ident string (eg. `@types/lodash`)
 */
  tryParseIdent = str: let
    # NOTE: The original patterns use `[^/]+?' ( non-greedy match ), which
    #       is currently broken in Nix or Darwin because LLVM is garbage.
    #       Cross your fingers that these patterns work without it.
    m = builtins.match "(@([^/]+)/)?([^/]+)" str;
    scope = builtins.elemAt m 1;
    pname = builtins.elemAt m 2;
  in if m == null then null else { inherit scope pname; };

  /* Not Allowed to return `null' */
  parseIdent = str:
    let rsl = tryParseIdent str; in
    if rsl != null then rsl else throw "Invalid ident (${str})";


# ---------------------------------------------------------------------------- #

/**
 * Parses a `string` into a descriptor
 *
 * Returns `null` if the descriptor cannot be parsed.
 *
 * @param string The descriptor string (eg. `lodash@^1.0.0`)
 * @param strict If `false`, the range is optional
 *               (`unknown` will be used as fallback)
 */
  tryParseDescriptor = strict: str: let
    # NOTE: The original patterns use `[^/]+?' ( non-greedy match ), which
    #       is currently broken in Nix or Darwin because LLVM is garbage.
    #       This has been worked around by using "[^@/]+" instead.
    strictMatch = builtins.match "(@([^@/]+)/)?([^@/]+)(@(.+))" str;
    permMatch   = builtins.match "(@([^@/]+)/)?([^@/]+)(@(.+))?" str;
    m           = if strict then strictMatch else permMatch;
    scope       = builtins.elemAt m 1;
    pname       = builtins.elemAt m 2;
    range' = builtins.elemAt m 4;
    range  = if range' == null then "unknown" else range';
  in if m == null then null else { inherit scope range pname; };

  /* Not allowed to return `null'. */
  parseDescriptor' = strict: str:
    let rsl = tryParseDescriptor strict str; in
    if rsl != null then rsl else throw "Invalid descriptor (${str})";

  parseDescriptor       = parseDescriptor' false;
  parseDescriptorStrict = parseDescriptor' true;


# ---------------------------------------------------------------------------- #

  /**
   * Parses a `string` into a locator.
   *
   * Returns `null` if the locator cannot be parsed.
   *
   * @param string The locator string (eg. `lodash@1.0.0`)
   * @param strict If `false`, the reference is optional
   *               (`unknown` will be used as fallback)
   */
  tryParseLocator = strict: str: let
    inherit (builtins) match elemAt;
    # NOTE: The original patterns use `[^/]+?' ( non-greedy match ), which
    #       is currently broken in Nix or Darwin because LLVM is garbage.
    #       This has been worked around by using "[^@/]+" instead.
    strictMatch = match "(@([^@/]+)/)?([^@/]+)(@([^<>=~^@]+))" str;
    permMatch   = match "(@([^@/]+)/)?([^@/]+)(@([^<>=~^@ ]+))?" str;
    # This was too permissive, it works even for non-locators.
    #permMatch   = match "(@([^@/]+)/)?([^@/]+)(@([^<>=~^@ ]+))?.*" str;
    m           = if strict then strictMatch else permMatch;
    scope       = elemAt m 1;
    pname       = elemAt m 2;
    reference'  = elemAt m 4;
    reference   = if reference' == null then "unknown" else reference';
  in if m == null then null else { inherit scope reference pname; };

  /* Not allowed to return `null'. */
  parseLocator' = strict: str:
    let rsl = tryParseLocator strict str; in
    if rsl != null then rsl else throw "Invalid locator (${str})";

  parseLocator       = parseLocator' false;
  parseLocatorStrict = parseLocator' true;


# ---------------------------------------------------------------------------- #

  # Collects various forms of name/ident info into a single attrset.
  # XXX: When `enableStringContextDiscards = true', this functions performs
  #      unsafe discards.
  #      This routine is meant for parsing lockfiles and other forms of
  #      "static" metadata when running in that mode.
  # If you strip string contexts for bogus package entries, for example
  # "I have this local project that I work on and don't update the version
  # number between rebuilds", you may find that Nix isn't rebuilding your
  # derivations "as expected".
  # If you use this on anything other than a lockfile containing "static"
  # registry tarballs or otherwise "pure" source references - you're
  # fucking it up and you should stop doing that.
  # If you aren't sure if you can safely strip string contexts, consult the
  # wall of text at the top of `lib/meta.nix' that covers this topic in
  # more detail.
  nameInfo = str: let
    unsafeDiscardStringContext =
      if ( config.enableStringContextDiscards or false )
      then builtins.unsafeDiscardStringContext
      else x: x;  # `id' op.
    pi' = tryParseIdent ( unsafeDiscardStringContext str );
    pd' = tryParseDescriptor true ( unsafeDiscardStringContext str );
    pl' = tryParseLocator true ( unsafeDiscardStringContext str );
    ids = ( if ( pi' != null ) then pi' // { type = "identifier"; } else {} ) //
          ( if ( pd' != null ) then pd' // { type = "descriptor";} else {} ) //
          ( if ( pl' != null ) then pl' // { type = "locator";} else {} );
    scopeDir = if ( ( ids ? scope ) && ( ids.scope != null ) )
               then "@" + ids.scope + "/" else "";
    name = scopeDir + ids.pname;
  in { inherit name scopeDir; } // ids;


# ---------------------------------------------------------------------------- #

  # Matches any 16bit SHA256 hash.
  isGitRev = str: ( builtins.match "[0-9a-f]{40}" str ) != null;


# ---------------------------------------------------------------------------- #

  getPjScopeDir = x: let
    inherit (builtins) isPath isString isAttrs match head pathExists tryEval;
    fromScope = scope: if scope == null then "" else "@${scope}/";
    fromName  = name: fromScope ( parseIdent name ).scope;
    fromAttrs = x.scopeDir or
      ( if ( x ? scope ) then ( fromScope x.scope ) else
        if ( x ? name )  then ( fromName x.name )   else
        throw "Cannot get scopeDir from available attrs." );
    m = match "(@([^/]+)/)?([^/]+)(@.+)?" x;
    ms = let s = head m; in if s == null then "" else s;
    fromMatch = if m != null then ms else
      throw "Cannot parse scopeDir from string: ${x}";
    fromRead = let
      pjs = lib.libpkginfo.pkgJsonForPath x;
      fromPi = fromName ( lib.libpkginfo.importJSON' pjs ).name;
    in if pathExists pjs then fromPi else  # XXX: We can't unzip tarballs here.
      throw "Cannot read scopeDir from path ${pjs}.";
    fromString = let tm = tryEval fromMatch;
                 in if tm.success then tm.value else fromRead;
  in if isAttrs  x then fromAttrs  else
     if isPath   x then fromRead   else # XXX: You could guess from subdir name?
     if isString x then fromString else
        throw "Cannot get scopeDir from type: ${builtins.typeOf x}";


# ---------------------------------------------------------------------------- #

in {
  inherit
    tryParseIdent
    parseIdent

    tryParseDescriptor
    parseDescriptor'
    parseDescriptor
    parseDescriptorStrict

    tryParseLocator
    parseLocator'
    parseLocator
    parseLocatorStrict

    nameInfo
    isGitRev
    getPjsScopeDir
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
