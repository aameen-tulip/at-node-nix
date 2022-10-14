# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  inherit (yt) struct string list attrs option restrict;
  prettyPrint = lib.generators.toPretty {};

# ---------------------------------------------------------------------------- #

  # Builtin modules, these names are reserved.
  node_bt_mods_l = builtins.fromJSON ( builtins.readFile ./builtins.json );
  id_reserved_l  = node_bt_mods_l ++ ["node_modules" "favicon.ico"];

# ---------------------------------------------------------------------------- #

  # Reference: https://github.com/npm/validate-npm-package-name
  #
  # NEW:
  #  - package name length should be greater than zero
  #  - all the characters in the package name must be lowercase i.e., no
  #    uppercase or mixed case names are allowed
  #  - package name can consist of hyphens
  #  - package name must not contain any non-url-safe characters ( since name
  #    ends up being part of a URL )
  #  - package name should not start with . or _
  #  - package name should not contain any spaces
  #  - package name should not contain any of the following characters:
  #    + [~)('!*]
  #    + this group is URI's "mark" character class, except that
  #      [_.-] are permitted.
  #  - package name cannot be the same as a node.js/io.js core module nor a
  #    reserved/blacklisted name. For example, the following names are invalid:
  #    + http
  #    + stream
  #    + node_modules
  #    + favicon.ico
  #  - package name length cannot exceed 214
  #
  # LEGACY:
  #  - They could have capital letters in them.
  #  - They could be really long.
  #  - They could be the name of an existing module in node core.
  RE = {
    id_part_new_c  = "[:lower:][:digit:]_.-";
    id_part_old_c  = "[:upper:]" + RE.id_part_new_c;
    id_new_c       = "@/" + RE.id_part_new_c;
    id_old_c       = "[:upper:]" + RE.id_new_c;

    id_part_new_p1  = "[a-z0-9_.-]";
    id_part_old_p1  = "[A-Za-z0-9_.-]";
    id_new_p1       = "[@/a-z0-9_.-]";
    id_old_p1       = "[@/A-Za-z0-9_.-]";

    id_part_new_p = "[a-z0-9-]${RE.id_part_new_p1}{0,213}";
    # XXX: I'm not 100% sure that these can't start with [._]
    id_part_old_p = "[A-Za-z0-9-]${RE.id_part_old_p1}*";
    # XXX: You need to check the length again in your typecheck.
    id_new_p = "(@${RE.id_part_new_p}/)?${RE.id_part_new_p}";
    id_old_p = "(@${RE.id_part_old_p}/)?${RE.id_part_old_p}";

    # Blacklisted/reserved module names.
    node_builtins_p = "(${builtins.concatStringsSep "|" node_bt_mods_l})";
    id_reserved_p   = "(${builtins.concatStringsSep "|" id_reserved_l})";

# ---------------------------------------------------------------------------- #

    version        = lib.librange.versionRE;  # FIXME: move here.
    range_constr_c = "<>=~^,|& -";
    range_c        = "[:alnum:].+${RE.range_constr_c}";

    range_constr_p1 = "[${RE.range_constr_c}]";
    range_p1        = "[a-zA-Z0-9.+${RE.range_constr_c}]";
    locator_p1      = "[${yt.Uri.RE.uri_c}]";
    descriptor_p1   = "[<>~^,|& ${yt.Uri.RE.uri_c}]";

    # FIXME: define `range_p'/semver patterns.
    # They're currently nested in parsers for `lib/ranges.nix'.
    range_p = "${RE.range_p1}+";

    locator_p    = "(${RE.version}|${yt.Uri.RE.uri_ref_p})";
    descriptor_p = "(${yt.Uri.RE.uri_ref_p}|${RE.range_p})";

    id_locator_old_p = "${RE.id_old_p}@(${RE.version}|${yt.Uri.RE.uri_ref_p})";
    id_locator_new_p = "${RE.id_new_p}@(${RE.version}|${yt.Uri.RE.uri_ref_p})";

    id_descriptor_old_p = "${RE.id_old_p}@${RE.descriptor_p}";
    id_descriptor_new_p = "${RE.id_new_p}@${RE.descriptor_p}";


# ---------------------------------------------------------------------------- #

    key = "${RE.id_old_p}/${RE.version}";

  };  # End `re'


# ---------------------------------------------------------------------------- #

  Strings = let
    # Helper to add length restriction to "new" identifiers.
    restrict_new_s = base_t: let
      cond = builtins.test "${RE.id_new_p1}{0,214}";
    in restrict "new" cond base_t;
  in {

    # FIXME: This belongs with Semver/Range types
    version  = restrict "version" ( lib.test lib.librange.versionRE ) string;

# ---------------------------------------------------------------------------- #

    identifier_old = restrict "identifier[old]" ( lib.test RE.id_old_p ) string;
    identifier_new = let
      cond = s: ( lib.test RE.id_new_p s ) &&
                ( ( builtins.stringLength s ) <= 214 );
    in restrict "identifier[new]" cond string;

    identifier_builtin = let
      cond = s: builtins.elem s node_bt_mods_l;
    in restrict "identifier[builtin]" cond string;

    identifier_reserved = let
      cond = s: builtins.elem s id_reserved_l;
    in restrict "identifier[reserved]" cond string;

    identifier_any = let
      base = yt.either Strings.identifier_old Strings.identifier_new;
    in base // {
      checkType = v: let
        res = base.checkType v;
      in if string.check v then res // {
        err = "\"${v}\" is not a valid module identifier";
      } else res // {
        err = "expected type 'string[identifier]', but value '${prettyPrint v}'"
              + " is of type '${builtins.typeOf v}'";
      };
    };

    identifier_unreserved = let
      cond = s: ! ( Strings.identifier_reserved.check s );
      base = restrict "unreserved" cond Strings.identifier_any;
    in base // {
      checkType = v: let
        res  = base.checkType v;
      in if ! ( Strings.identifier_any.check v ) then res else res // {
        err = "\"${v}\" is a reserved module name";
      };
    };

    identifier = Strings.identifier_unreserved;

    id_part     = restrict "id_part" ( lib.test RE.id_part_old_p ) string;
    id_part_new = restrict_new_s Strings.id_part;

    scope = Strings.id_part;
    # Either "" or "@foo/", but never "@foo"
    scopedir = restrict "scopedir" ( lib.test "(@${RE.id_part_old_p1}+/)?" )
                                   string;
    scopedir_new = restrict_new_s Strings.scopedir;

# ---------------------------------------------------------------------------- #

    # "1.0.0" ( exact version ) or "file:../foo" or "https://..." URI
    locator = restrict "locator" ( lib.test RE.locator_p ) string;

    id_locator = restrict "ident+locator" ( lib.test RE.id_locator_old_p )
                                          string;
    id_locator_new = restrict "new" ( lib.test RE.id_locator_new_p )
                                    Strings.id_locator;


    # FIXME
    range = restrict "semver[range]" ( lib.test RE.range_p ) string;

    # ">=1.0.0 <2.0.0" ( semver constraint ) or locator
    descriptor = restrict "descriptor" ( lib.test RE.descriptor_p ) string;
    descriptor_new = restrict "new" ( lib.test RE.descriptor_new_p )
                                    Strings.descriptor;

    id_descriptor =
      restrict "ident+descriptor" ( lib.test RE.id_descriptor_old_p ) string;
    id_descriptor_new = restrict "new" ( lib.test RE.id_descriptor_new_p )
                                       Strings.id_descriptor;

# ---------------------------------------------------------------------------- #

    key = restrict "pkg-key" ( lib.test RE.key ) string;

  };  # End Strings


# ---------------------------------------------------------------------------- #

  Structs = {
    identifier = yt.struct "identifier" {
      bname = Strings.id_part;
      scope = option ( yt.either Strings.scope Structs.scope );
    };
    id_locator = yt.struct "identifier+locator" {
      identifier = yt.either Structs.identifier Strings.identifier_any;
      locator    = Strings.locator;
    };
    id_descriptor = yt.struct "identifier+descriptor" {
      identifier = yt.either Structs.identifier Strings.identifier_any;
      descriptor = yt.either Strings.descriptor Sums.descriptor;
    };
    scope = yt.struct "scope" {
      scope    = yt.option ( yt.either Strings.scope Structs.scope );
      scopedir = Strings.scopedir;
    };
  };  # End Structs


# ---------------------------------------------------------------------------- #

  Sums = {
    locator = yt.sum "locator" {
      uri     = yt.Uri.Strings.uri_ref;
      version = Strings.version;
    };
    descriptor = yt.sum "descriptor" {
      range   = Strings.range;
      locator = yt.either Strings.locator Sums.locator;
    };
  };  # End Sums


# ---------------------------------------------------------------------------- #

in {
  inherit
    RE
    Strings
    Structs
    Sums
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
