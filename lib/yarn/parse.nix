rec {

/* -------------------------------------------------------------------------- */

  /**
   * Parses a `string` into a locator.
   *
   * Returns `null` if the locator cannot be parsed.
   *
   * @param string The locator string (eg. `lodash@1.0.0`)
   * @param strict If `false`, the reference is optional (`unknown` will be used as fallback)
   */
  tryParseLocator = strict: str:
    let
      strict' = builtins.match "(@([^/]+?)\/)?([^/]+?)(@(.+))" str;
      perm = builtins.match "(@([^/]+?)\/)?([^/]+?)(@(.+))?" str;
      m = if ( strict' == null ) && ( ! strict ) then perm else strict;
      scope = builtins.elem m 1;
      pname = builtins.elem m 2;
      reference' = builtins.elem m 4;
      reference = if reference' == null then "unknown" else reference';
    in if m == null then null else { inherit scope reference pname; };

  # Not allowed to return `null'.
  parseLocator' = strict: str:
    let rsl = tryParseLocator strict str; in
    if rsl != null then rsl else throw "Invalid locator (${str})";

  parseLocator       = parseLocator' false;
  parseLocatorStrict = parseLocator' true;


/* -------------------------------------------------------------------------- */

}
