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

  relative_file_uri = let
    cond = x: let
      m = builtins.match "(file:)?(\\.[^:#?]*)" x;
      p = builtins.elemAt m 1;
    in ( m != null ) && ( ur.Strings.path_segments.check p );
  in restrict "uri[relative]" cond string;

  git_uri = restrict "git" ( lib.test "git(\\+(ssh|https?))?://.*" )
                           uri_ref;

  tarball_uri = restrict "tarball" yt.Strings.tarball_url.check uri_ref;

  # link, dir, tarball, git
  #   "resolved": "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c",
  #   "resolved": "https://registry.npmjs.org/typescript/-/typescript-4.8.2.tgz",
  resolved_uri = yt.eitherN [relative_file_uri git_uri tarball_uri];


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

  pkg_path_v3 = let
    fconds = pkg_any_fields_v3 // {
      resolved = option relative_file_uri;
      link     = option bool;
    };
    cond = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
  in restrict "package[path]" cond ( yt.attrs yt.any );
  
  pkg_dir_v3  = restrict "dir"  ( x: ! ( x.link or false) ) pkg_path_v3;
  pkg_link_v3 = restrict "link" ( x: x.link or false ) pkg_path_v3;


# ---------------------------------------------------------------------------- #

  pkg_git_v3 = let
    fconds = pkg_any_fields_v3 // { resolved = git_uri; };
    cond = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
  in restrict "package[git]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #

  pkg_tarball_v3 = let
    condHash = x: ( x ? integrity ) || ( x ? sha1 );
    fconds   = pkg_any_fields_v3 // {
      resolved  = tarball_uri;
      integrity = option yt.Strings.sha512_sri;
      sha1      = option yt.Strings.sha1_hash;
    };
    condFields = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    cond = x: ( condHash x ) && ( condFields x );
  in restrict "package[tarball]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #

  package = yt.eitherN [pkg_dir_v3 pkg_link_v3 pkg_git_v3 pkg_tarball_v3];


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
    pkg_dir_v3
    pkg_link_v3
    pkg_git_v3
    pkg_tarball_v3
    package
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
