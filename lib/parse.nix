rec {

/* -------------------------------------------------------------------------- */

/**
 * Parses a string into an ident.
 *
 * Returns `null` if the ident cannot be parsed.
 *
 * @param string The ident string (eg. `@types/lodash`)
 */
  tryParseIdent = str:
    let
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


/* -------------------------------------------------------------------------- */

/**
 * Parses a `string` into a descriptor
 *
 * Returns `null` if the descriptor cannot be parsed.
 *
 * @param string The descriptor string (eg. `lodash@^1.0.0`)
 * @param strict If `false`, the range is optional
 *               (`unknown` will be used as fallback)
 */
  tryParseDescriptor = strict: str:
    let
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


/* -------------------------------------------------------------------------- */

  /**
   * Parses a `string` into a locator.
   *
   * Returns `null` if the locator cannot be parsed.
   *
   * @param string The locator string (eg. `lodash@1.0.0`)
   * @param strict If `false`, the reference is optional
   *               (`unknown` will be used as fallback)
   */
  tryParseLocator = strict: str:
    let
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


/* -------------------------------------------------------------------------- */

  nameInfo = str:
    let
      inherit (builtins) unsafeDiscardStringContext;
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

}
