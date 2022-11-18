# ============================================================================ #
#
# Reference data under: tests/libfetch/data/proj2/package-lock.json
#
# TODO: v1 style `dependencies' fields.
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  ur = yt.Uri;
  pi = yt.PkgInfo;
  inherit (yt) struct string list bool attrs option restrict;
  inherit (pi.Strings) identifier identifier_any version locator descriptor;
  inherit (ur.Strings) uri_ref scheme fragment;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #

  # XXX: Be careful about v1 and v2 here.
  # V1 had `from' fields and other wonky shit here, basically completely
  # rewriting the regular dependencies fields.
  #
  # "dependencies": {
  #   "lodash": {
  #     "version": "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c",
  #     "from": "lodash@github:lodash/lodash"
  #   },
  dep_field_v3 = let
    cond = x: builtins.all identifier_any.check ( builtins.attrNames x );
  in restrict "dep_descriptors" cond ( attrs descriptor );

  dep_ent_v1 = struct "deps_v1" {
    version  = locator;
    resolved = option resolved_uri;
    from     = option descriptor;
    dev      = option bool;
    optional = option bool;
    peer     = option bool;
  };

  dep_field_v1 = let
    cond = x: builtins.all identifier_any.check ( builtins.attrNames x );
  in restrict "dep_entries" cond ( attrs dep_ent_v1 );

  deps_v2 = {
    requires         = option dep_field_v3;
    dependencies     = option ( yt.either dep_field_v3 dep_field_v1 );
    devDependencies  = option dep_field_v3;
    peerDependencies = option dep_field_v3;
    # FIXME
  };

  deps_v1 = {
    dependencies = option dep_field_v1;
  };

  deps_v3 = {
    requires         = option dep_field_v3;
    dependencies     = option dep_field_v3;
    devDependencies  = option dep_field_v3;
    peerDependencies = option dep_field_v3;
    # FIXME
  };

  # FIXME
  deps = deps_v2;


# ---------------------------------------------------------------------------- #

  # FIXME: `pacote' will write absolute filepaths.
  # For `resolved' it doesn't use `file:...', but for `from' it will.
  # NOTE: the note above is useful for a "general purpose" typdef, but
  # NPM's `package-lock.json' uses the "file:" scheme to distinguish
  # between "link" and "dir" ltype, and we need to follow their usage.
  relative_file_uri = let
    cond = x: let
      m = builtins.match "file:(\\.[^:#?]*)" x;
      p = builtins.head m;
    in ( m != null ) && ( ur.Strings.path_segments.check p );
  in restrict "uri[relative]" cond string;

  git_uri = restrict "git" ( lib.test "git(\\+(ssh|https?))?://.*" )
                           uri_ref;

  tarball_uri = let
    tarballUrlCond = yt.Strings.tarball_url.check;
    # Basically the only registry that doesn't put the tarball in the URL...
    githubPkgCond = lib.test "https://npm\\.pkg\\.github\\.com/download/.*";
    cond = s: ( tarballUrlCond s ) || ( githubPkgCond s );
  in restrict "tarball" cond uri_ref;


# ---------------------------------------------------------------------------- #

  # link, dir, tarball, git
  #   "resolved": "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c",
  #   "resolved": "https://registry.npmjs.org/typescript/-/typescript-4.8.2.tgz",
  resolved_uri_types = [
    git_uri
    relative_file_uri      # dir
    tarball_uri
    yt.FS.Strings.relpath  # link
  ];

  resolved_uri = yt.eitherN resolved_uri_types;


# ---------------------------------------------------------------------------- #

  # Package Entries ( Plock v3 Only )

  # XXX: All are optional
  pkg_any_fields_v3 = ( builtins.mapAttrs ( _: option ) {
    name     = identifier;
    version  = locator;
    resolved = resolved_uri;
    license  = string;
    engines  = yt.either ( yt.attrs string ) ( yt.list string );
    bin      = yt.attrs string;
    os       = yt.list string;  # FIXME: enum
    cpu      = yt.list string;  # FIXME: enum
    # These all default to `false'
    hasInstallScript = bool;
    gypfile          = bool;
    optional         = bool;
    dev              = bool;
  } ) // deps_v3;


# ---------------------------------------------------------------------------- #

  # XXX: this form is used by fetchers, but is NOT an accurate way to detect
  # either of the real entires.
  # The real entries explicitly use the "link" field.
  pkg_path_v3 = let
    fconds = pkg_any_fields_v3 // {
      resolved =
        yt.option ( yt.either relative_file_uri yt.FS.Strings.relpath );
      link = yt.option yt.bool;
    };
    cond = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
  in restrict "package[dir]" cond ( yt.attrs yt.any );

  
  pkg_dir_v3  = let
    # Resolved may only appear with "file:" URI scheme.
    # Only "link" entries use bare relative paths.
    # "resolved": "file:../eslint-config",
    # If the field is omitted then its key in the `package.*' attrset is its
    # path ( relative to the `lockDir' ).
    cond = x: 
      ( ! ( x.link or false ) ) &&
      ( ( ! ( x ? resolved ) ) || ( relative_file_uri.check x.resolved ) );
  in restrict "dir" cond pkg_path_v3;

  # Almost never contains `pkg_any_fields' which are instead held by a `dir'
  # entry at the "resolved" field's path.
  # The only time they will is for NPM workspaces, in which case links may
  # record `version', `dependencies', `licenses', and a few others.
  # You want to STRICTLY interpret the "link" flag here.
  pkg_link_v3 = let
    # XXX: NOT a `file:' URI! Those are `dir' ltypes.
    cond = x: ( x ? resolved ) && ( yt.FS.Strings.relpath.check x.resolved ) &&
              ( ( x.link or false ) == true );
  in restrict "link" cond pkg_path_v3;


# ---------------------------------------------------------------------------- #

  pkg_git_v3 = let
    fconds = pkg_any_fields_v3 // { resolved = git_uri; };
    cond = x: let
      fs     = builtins.attrNames ( builtins.intersectAttrs fconds x );
      fields = builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    in ( x ? resolved ) && fields;
  in restrict "package[git]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #

  # NOTE: the `tarball_uri' checker sort of sucks and if you're here debugging
  # that's probably what you're looking for.
  pkg_tarball_v3 = let
    condHash = x: ( x ? integrity ) || ( x ? sha1 );
    fconds   = pkg_any_fields_v3 // {
      resolved  = tarball_uri;
      integrity = option yt.Hash.integrity;
      sha1      = option yt.Hash.Strings.sha1_hash;
    };
    condFields = x: let
      fs     = builtins.attrNames ( builtins.intersectAttrs fconds x );
      fields = builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    in ( x ? resolved ) && fields;
    cond = x: ( condHash x ) && ( condFields x );
  in restrict "package[tarball]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #

  plent_types = [pkg_git_v3 pkg_tarball_v3 pkg_link_v3 pkg_path_v3];
  package     = yt.eitherN plent_types;


# ---------------------------------------------------------------------------- #


in {
  Strings = {
    inherit
      relative_file_uri
      git_uri
      tarball_uri
      resolved_uri
    ;
  };
  Structs = {
    inherit
      pkg_path_v3  # used by fetchers, not exposed to users.
      pkg_dir_v3
      pkg_link_v3
      pkg_git_v3
      pkg_tarball_v3
      package
    ;
  };
  inherit
    resolved_uri
    resolved_uri_types
    pkg_dir_v3
    pkg_link_v3
    pkg_git_v3
    pkg_tarball_v3
    plent_types
    package
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
