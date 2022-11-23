# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  inherit (yt) struct string list attrs option;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  # FIXME: abbreviated version info
  version_abbrev = attrs yt.any;

# ---------------------------------------------------------------------------- #

  # Abstract info about `version_abbrev'.
  # This wraps the actual `vinfo' data indicating how it can be fetched, whether
  # the integrity of the data has been audited, etc.
  #
  # We need a "lens" over this metadata because the NPM registry does not
  # validate any of the information it serves aside from author signatures and
  # the `integrity' field of a tarball.
  # So I can literally `PUT' whatever the fuck I want as registry fields, and
  # upload a tarball with a symlink bomb without them ever attempting to check
  # its contents before they ship it out to be used in the software that
  # protects your credit card information, your identity, critical
  # infrastructure, etc.
  #   "mOvE fAsT aNd BrEaK tHiNgS." - Webshits
  #   "We'll address the security concerns in phase two." - Every P.M.
  #   "We've left content moderation up to the community." - Malware Host
  _vinfoMetaFields = {
    _type    = yt.enum ["vinfoMeta"];
    registry = yt.Uri.Strings.uri_ref;  # FIXME: no path, frag, or query
    narHash  = yt.Hash.nar_hash;
    trust    = yt.bool;
    ident    = yt.PkgInfo.Strings.identifier_any;
    version  = yt.PkgInfo.Strings.version;
    url      = yt.Uri.Strings.uri_ref;
    vinfo    = yt.attrs yt.any;
  };


# ---------------------------------------------------------------------------- #

  _packumentFields = {
    _id          = yt.PkgInfo.Strings.identifier_any;  # couchDB metadata
    _rev         = string;  # XXX: NOT A GIT REV. This is couchDB metadata.
    name         = yt.PkgInfo.Strings.identifier_any;
    author       = option Eithers.human;
    bugs         = option Eithers.human;
    contributors = option Eithers.humans;
    maintainers  = list Eithers.human;
    description  = option string;
    dist-tags    = attrs yt.PkgInfo.Strings.version;
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
    # These are sometimes useful for "locking" though.
    # Fore example we *COULD* use `_rev' to "lock" a packument and purify it
    # again later with `builtins.fetchTree { type = "file"; narHash = ...; }'.
    # The reason we can't is that NPM eliminated the "full fat db" servers, so
    # we would have to rely on mirrors or Nix store caches to fetch archives.
    packument_full = struct "packument-full" _packumentFields;

    # Faster, only checks fields we care about.
    packument = let
      cond = x: let
        common = builtins.intersectAttrs _packumentFields x;
        proc   = acc: f: acc && ( _packumentFields.${f}.check x.${f} );
      in builtins.foldl' proc true ( builtins.attrNames common );
    in yt.restrict "packument" cond ( attrs yt.any );


# ---------------------------------------------------------------------------- #

    vinfo_meta = let
      core = yt.struct {
        inherit (_vinfoMetaFields)
          _type
          trust
          ident
          version
          vinfo
        ;
        url      = yt.option _vinfoMetaFields.url;
        registry = yt.option _vinfoMetaFields.registry;
        narHash  = yt.option _vinfoMetaFields.narHash;
      };
      urlOrReg = x: ( x.registry or x.url or null ) != null;
      sident   = x: x.ident == x.vinfo.name;
      sv       = x: x.version == x.vinfo.version;
      # This field is optional, but if it does appear it must match the
      # other declarations.
      sid = x:
        ( ! ( x.vinfo ? _id ) ) || ( "${x.ident}@${x.version}" == x.vinfo._id );
      cond = x: ( urlOrReg x ) && ( sident x ) && ( sv x ) && ( sid x );
    in yt.restrict "vinfoMeta" cond core;

    vinfo_meta_locked =
      yt.restrict "locked" ( x: ( x.narHash or null ) != null )
                           Structs.vinfo_meta;

    vinfo_meta_unlocked =
      yt.restrict "unlocked" ( x: ( x.narHash or null ) == null )
                          Structs.vinfo_meta;


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
    _packumentFields
    _vinfoMetaFields
  ;
  inherit
    Structs
    Eithers
    version_abbrev  # FIXME
  ;
  inherit (Structs)
    packument
    vinfo_meta
    vinfo_meta_locked
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
