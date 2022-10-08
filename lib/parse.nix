
# ============================================================================ #
#
# Parsers for things like package identifiers/names,
# locators ( version or URI ), and descriptors ( semver or URI ).
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  pi = yt.PkgInfo;
  inherit (yt) defun;

# ---------------------------------------------------------------------------- #

 /**
  * Parses a string into an ident.
  *
  * Returns `null` if the ident cannot be parsed.
  *
  * @param string The ident string (eg. `@types/lodash`)
  */
  tryParseIdent = let
    inner = str: let
      # NOTE: The original patterns use `[^/]+?' ( non-greedy match ), which
      #       is currently broken in Nix or Darwin because LLVM is garbage.
      #       Cross your fingers that these patterns work without it.
      m = builtins.match "(@([^/]+)/)?([^/]+)" str;
      scope = builtins.elemAt m 1;
      bname = builtins.elemAt m 2;
    in if m == null then null else { inherit scope bname; };
  in defun [yt.string ( yt.option pi.Structs.identifier )] inner;

  # Not Allowed to return `null'
  parseIdent = defun [pi.Strings.identifier_any pi.Structs.identifier]
                     tryParseIdent;

# ---------------------------------------------------------------------------- #

  tryParseDescriptor = let
    inner = str:
      if pi.Strings.locator.check str then { locator = str; } else
      if pi.Strings.range.check str then { range = str; } else null;
  in defun [yt.string ( yt.option pi.Sums.descriptor )] inner;

  parseDescriptor = defun [pi.Strings.descriptor pi.Sums.descriptor]
                          tryParseDescriptor;


# ---------------------------------------------------------------------------- #

  /**
   * Parses a `string' into a identifier + descriptor
   *
   * Returns `null' if the descriptor cannot be parsed.
   *
   * @param string The descriptor string ( "lodash@^1.0.0" )
   */
  tryParseIdentDescriptor = let
    inner = str: let
      m          = builtins.match "(@([^@/]+)/)?([^@/]+)(@(.+))" str;
      scope      = builtins.elemAt m 1;
      bname      = builtins.elemAt m 2;
      descriptor = builtins.elemAt m 4;
    in if m == null then null else {
      identifier = { inherit bname scope; };
      inherit descriptor;
    };
  in defun [yt.string ( yt.option pi.Structs.id_descriptor )] inner;

  /* Not allowed to return `null'. */
  parseIdentDescriptor =
    defun [pi.Strings.id_descriptor pi.Structs.id_descriptor]
          tryParseIdentDescriptor;


# ---------------------------------------------------------------------------- #

  tryParseLocator = let
    inner = str:
      if pi.Strings.version.check str then { version = str; } else
      if yt.Uri.Strings.uri_ref.check str then { uri = str; } else null;
  in defun [yt.string ( yt.option pi.Sums.locator )] inner;

  parseLocator = defun [pi.Strings.locator pi.Sums.locator] tryParseLocator;


# ---------------------------------------------------------------------------- #

  /**
   * Parses a `string' into a identifier + locator
   *
   * Returns `null' if the locator cannot be parsed.
   *
   * @param string The descriptor string ( "lodash@1.0.0" )
   */
  tryParseIdentLocator = let
    inner = str: let
      m          = builtins.match "(@([^@/]+)/)?([^@/]+)(@(.+))" str;
      scope      = builtins.elemAt m 1;
      bname      = builtins.elemAt m 2;
      locator    = builtins.elemAt m 4;
    in if m == null then null else {
      identifier = { inherit bname scope; };
      inherit locator;
    };
  in defun [yt.string ( yt.option pi.Structs.id_locator )] inner;

  parseIdentLocator =
    defun [pi.Strings.id_locator pi.Structs.id_locator] tryParseIdentLocator;


# ---------------------------------------------------------------------------- #

in {
  inherit
    tryParseIdent
    parseIdent

    tryParseDescriptor
    parseDescriptor
    tryParseIdentDescriptor
    parseIdentDescriptor

    tryParseLocator
    parseLocator
    tryParseIdentLocator
    parseIdentLocator
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
