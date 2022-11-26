
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
      m          = builtins.match "(@([^@/]+)/)?([^@/]+)@(.+)" str;
      scope      = builtins.elemAt m 1;
      bname      = builtins.elemAt m 2;
      descriptor = builtins.elemAt m 3;
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

  # A locator is a unique token associated with an instance of a package.
  # This is conventionally an identified + version, or a URI, which are used to
  # fetch the package from a registry or at an explicit URI path.
  # Ex:  lodash@4.17.21      ( imlies `npm:' scheme prefix )
  # Ex:  npm:lodash@4.17.21  ( explicit form of above - this is more correct )
  # Ex:  4.17.21
  # Ex:  https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz
  # Ex:  github:lodash/lodash/v4.17.21  ( `github:<OWNER>/<REPO>/<REV-OR-REF>' )
  # Ex:  file:../../@foo/bar
  #
  # NOTE: this should not be confused with a package "descriptor" which includes
  # all locators as well as semver ranges as members.
  # For clarity: `package.json' dependency fields are "descriptors", not
  # necessarily "locators".
  tryParseLocator = let
    fromNpmScheme = s: let
      vpatt = "[0-9]+\\.[0-9]+\\.[0-9]+(-[^@/]+)?";
      m     = builtins.match "(npm:)?((@[^@/]+/)?[^@/]+)@(${vpatt})" s;
    in { uri = if ( builtins.head m ) == null then "npm:" + s else s; };
    inner = str:
      if pi.Strings.id_locator.check str then fromNpmScheme str else
      if pi.Strings.version.check str then { version = str; } else
      if yt.Uri.Strings.uri_ref.check str then { uri = str; } else null;
  in defun [yt.string ( yt.option pi.Sums.locator )] inner;

  parseLocator = let
    fromT = yt.either pi.Strings.locator pi.Strings.id_locator;
  in defun [fromT pi.Sums.locator] tryParseLocator;


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
      m       = builtins.match "(@([^@/]+)/)?([^@/]+)@(.+)" str;
      scope   = builtins.elemAt m 1;
      bname   = builtins.elemAt m 2;
      locator = builtins.elemAt m 3;
    in if m == null then null else {
      identifier = { inherit bname scope; };
      inherit locator;
    };
  in defun [yt.string ( yt.option pi.Structs.id_locator )] inner;

  parseIdentLocator =
    defun [pi.Strings.id_locator pi.Structs.id_locator] tryParseIdentLocator;


# ---------------------------------------------------------------------------- #

  parseNodeNames = identish: let
    m     = builtins.match "((@([^@/]+)/)?([^@/])[^@/]+).*" identish;
    ident = builtins.head m;
    scope = builtins.elemAt m 2;
    sl    = builtins.elemAt m 3;
  in yt.PkgInfo.Structs.node_names {
    _type = "NodeNames";
    inherit ident scope;
    bname = baseNameOf ident;
    sdir  = if scope == null then "unscoped/${sl}" else scope; # shard dir
  };


# ---------------------------------------------------------------------------- #

  node2nixName = { ident ? args.name, version, ... } @ args: let
    fid = "${builtins.replaceStrings ["@" "/"] ["_at_" "_slash_"] ident
            }-${version}";
    fsb = ( if args.scope != null then "_at_${args.scope}_slash_" else "" ) +
          "${args.bname}-${version}";
  in if ( args ? bname ) && ( args ? scope ) then fsb else fid;


# ---------------------------------------------------------------------------- #

  # NPM's registry does not include `scope' in its tarball names.
  # However, running `npm pack' DOES produce tarballs with the scope as a
  # a prefix to the name as: "${scope}-${bname}-${version}.tgz".
  asLocalTarballName = { bname, scope ? null, version }:
    if scope != null then "${scope}-${bname}-${version}.tgz"
                     else "${bname}-${version}.tgz";

  asNpmRegistryTarballName = { bname, version }: "${bname}-${version}.tgz";


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

    parseNodeNames
    node2nixName
    asLocalTarballName
    asNpmRegistryTarballName
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
