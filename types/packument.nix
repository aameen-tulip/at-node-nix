# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim // ytypes.PkgInfo;
  inherit (yt) struct string list attrs option;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  # FIXME: abbreviated version info
  version_abbrev = attrs yt.any;

# ---------------------------------------------------------------------------- #

  packumentFields = {
    _id          = yt.Strings.identifier_any;  # couchDB metadata
    _rev         = string;  # XXX: NOT A GIT REV. This is couchDB metadata.
    name         = yt.Strings.identifier_any;
    author       = option Eithers.human;
    bugs         = option Eithers.human;
    contributors = option Eithers.humans;
    maintainers  = list Eithers.human;
    description  = option string;
    dist-tags    = attrs yt.Strings.version;
    homepage     = option string;
    keywords     = option ( list string );
    license      = option Eithers.licenses;
    # falls back to error string in most cases but some old packages lack it.
    readme         = option string;
    readmeFilename = option string;
    repository     = option Eithers.repository;
    time           = attrs string;
    # <USERNAME>: true  ( always true )
    users = option ( attrs yt.bool );
    # XXX: This type needs to be implemented
    versions = version_abbrev;
  };


# ---------------------------------------------------------------------------- #

  Structs = {
    # Attrs starting with '_<FIELD>' are CouchDB metadata fields that are not
    # relevant to package installation.
    # These are sometimes useful for "locking though".
    # Fore example we *COULD* use `_rev' to "lock" a packument and fetch it
    # again later with `builtins.fetchTree { type = "file"; narHash = ...; }'.
    packument_full = struct "packument-full" packumentFields;

    # Faster, only checks fields we care about.
    packument = let
      cond = x: let
        common = builtins.intersectAttrs packumentFields x;
        proc   = acc: f: acc && ( packumentFields.${f}.check x.${f} );
      in builtins.foldl' proc true ( builtins.attrNames common );
    in yt.restrict "packument" cond ( attrs yt.any );


# ---------------------------------------------------------------------------- #

    license = struct "license" { type = string; url = string; };

    human = struct "human" {
      name           = option string;
      email          = option string;
      url            = option string;
      githubUsername = option string;
    };

    repository = struct "repository" {
      type      = option ( yt.enum ["git" "url"] );
      url       = string;
      directory = option string;
      web       = option string;
      dist      = option string;
    };

  };  # End Structs


# ---------------------------------------------------------------------------- #

  Eithers = {
    human      = yt.either string Structs.human;
    humans     = yt.either Eithers.human ( yt.list Eithers.human );
    repository = yt.either string Structs.repository;
    license    = yt.either string Structs.license;
    licenses   = yt.either Eithers.license ( yt.list Eithers.license );
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    Structs
    Eithers
    packumentFields
  ;
  inherit (Structs)
    packument
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
