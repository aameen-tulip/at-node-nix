
# ============================================================================ #
#
# NOTE: These were one of the earliest set of routines written for this project.
# They were largely aimed at processing `yarn.lock(v2)' entries.
# These aren't used in newer `(meta|pkg)Set' style routines; but they
# may be useful to folks who just need some standalone Node.js
# helper routines/parsers.
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
  nameInfo' = enableStringContextDiscards: str: let
    unsafeDiscardStringContext =
      if enableStringContextDiscards
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

  nameInfo = nameInfo' false;

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
    parseDescriptor
    tryParseIdentDescriptor
    parseIdentDescriptor

    tryParseLocator
    parseLocator
    tryParseIdentLocator
    parseIdentLocator

    nameInfo'
    nameInfo
    isGitRev
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
