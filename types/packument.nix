# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim // lib.ytypes.PkgInfo;
  inherit (yt) struct string list attrs option;

# ---------------------------------------------------------------------------- #

  # FIXME: abbreviated version info
  manifests-abbrev = attrs yt.any;

# ---------------------------------------------------------------------------- #

  Structs = {

    # Attrs starting with '_<FIELD>' are CouchDB metadata fields that are not
    # relevant to package installation.
    # These are sometimes useful for "locking though".
    # Fore example we *COULD* use `_rev' to "lock" a packument and fetch it
    # again later with `builtins.fetchTree { type = "file"; narHash = ...; }'.
    packument = struct "packument" {
      _id          = yt.Strings.identifier_any;  # couchDB metadata
      _rev         = string;  # XXX: NOT A GIT REV. This is couchDB metadata.
      name         = yt.Strings.identifier_any;
      author       = option Eithers.human;
      bugs         = option Eithers.human;
      contributors = option ( yt.either string ( list Eithers.human ) );
      description  = option string;
      dist-tags    = attrs yt.Strings.version;
      homepage     = option string;
      keywords     = option ( list string );
      license      = option string;
      maintainers  = list Eithers.human;
      # falls back to error string
      readme         = string;
      readmeFilename = option string;
      repository     = option Eithers.repository;
      time           = attrs string;
      # <USERNAME>: true  ( always true )
      users = option ( attrs yt.bool );
      # XXX: This type needs to be implemented
      versions = manifests-abbrev;
    };

# ---------------------------------------------------------------------------- #

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
    repository = yt.either string Structs.repository;
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    Structs
    Eithers
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
