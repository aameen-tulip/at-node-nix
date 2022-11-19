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

  lock_uris = import ./npm/lock/uri.nix { inherit ytypes; };

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
    resolved = option lock_uris.resolved_uri;
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

  # Package Entries ( Plock v3 Only )

  # XXX: All are optional
  pkg_any_fields_v3 = ( builtins.mapAttrs ( _: option ) {
    name     = identifier;
    version  = locator;
    resolved = lock_uris.resolved_uri;
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
      resolved = yt.option lock_uris.Strings.path_uri;
      link     = yt.option yt.bool;
    };
    cond = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
      fieldsCond = builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    in ( builtins.isAttrs x ) && fieldsCond;
  in lib.libtypes.typedef "npm:lock:package:path" cond;

  
  pkg_dir_v3  = let
    # Resolved may only appear with "file:" URI scheme.
    # Only "link" entries use bare relative paths.
    # "resolved": "file:../eslint-config",
    # If the field is omitted then its key in the `package.*' attrset is its
    # path ( relative to the `lockDir' ).
    cond = x: 
      ( ! ( x.link or false ) ) &&
      ( ( ! ( x ? resolved ) ) || ( lock_uris.dir_uri.check x.resolved ) );
  in restrict "dir" cond pkg_path_v3;

  # Almost never contains `pkg_any_fields' which are instead held by a `dir'
  # entry at the "resolved" field's path.
  # The only time they will is for NPM workspaces, in which case links may
  # record `version', `dependencies', `licenses', and a few others.
  # You want to STRICTLY interpret the "link" flag here.
  pkg_link_v3 = let
    # XXX: NOT a `file:' URI! Those are `dir' ltypes.
    cond = x: ( x ? resolved ) && ( lock_uris.link_uri.check x.resolved ) &&
              ( ( x.link or false ) == true );
  in restrict "link" cond pkg_path_v3;


# ---------------------------------------------------------------------------- #

  pkg_git_v3 = let
    fconds = pkg_any_fields_v3 // { resolved = lock_uris.git_uri; };
    cond = x: let
      fs     = builtins.attrNames ( builtins.intersectAttrs fconds x );
      fields = builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    in ( builtins.isAttrs x ) && ( x ? resolved ) && fields;
  in lib.libtypes.typedef "npm:lock:package[git]" cond;


# ---------------------------------------------------------------------------- #

  # NOTE: the `tarball_uri' checker sort of sucks and if you're here debugging
  # that's probably what you're looking for.
  pkg_file_v3 = let
    condHash = x:
      ( x ? integrity ) || ( x ? sha1 ) ||
      ( lock_uris.Strings.path_uri.check x );  # Local paths don't need hash.
    fconds   = pkg_any_fields_v3 // {
      resolved  = lock_uris.file_uri;
      integrity = option yt.Hash.integrity;
      sha1      = option yt.Hash.Strings.sha1_hash;
    };
    condFields = x: let
      fs     = builtins.attrNames ( builtins.intersectAttrs fconds x );
      fields = builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    in ( x ? resolved ) && fields;
    cond = x: ( builtins.isAttrs x ) && ( condHash x ) && ( condFields x );
  in lib.libtypes.typedef "npm:lock:package[file]" cond;


# ---------------------------------------------------------------------------- #

  plent_types = [pkg_git_v3 pkg_file_v3 pkg_link_v3 pkg_dir_v3];
  package     = yt.eitherN plent_types;

  plock_pkey = yt.either yt.FS.Strings.relpath ( yt.enum [""] );


# ---------------------------------------------------------------------------- #


in {
  Strings = lock_uris.Strings // {
    # Add some
  };
  Structs = {
    inherit
      pkg_path_v3  # used by fetchers, not exposed to users.
      pkg_dir_v3
      pkg_link_v3
      pkg_git_v3
      pkg_file_v3
      package
    ;
  };
  inherit
    pkg_any_fields_v3
    pkg_dir_v3
    pkg_link_v3
    pkg_git_v3
    pkg_file_v3
    plent_types
    package
    plock_pkey
  ;

  inherit (lock_uris)
    file_uri
    link_uri
    git_uri
    dir_uri
    resolved_uri
    _resolved_uri_types
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
