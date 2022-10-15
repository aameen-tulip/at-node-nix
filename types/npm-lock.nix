# ============================================================================ #
#
# Reference data under: tests/libfetch/data/proj2/package-lock.json
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  prettyPrint = lib.generators.toPretty {};
  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  ur = yt.Uri;
  pi = yt.PkgInfo;
  inherit (yt) struct string list bool attrs option restrict;
  inherit (pi.Strings) identifier identifier_any version locator descriptor;
  inherit (ur.Strings) uri_ref scheme fragment;

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
  dep_field = let
    cond = x: builtins.all identifier_any.check ( builtins.attrNames x );
  in restrict "dep_descriptors" cond ( attrs descriptor );

  deps = {
    dependencies     = option dep_field;
    devDependencies  = option dep_field;
    peerDependencies = option dep_field;
    # FIXME
  };


# ---------------------------------------------------------------------------- #

  # link, dir, tarball, git
  #   "resolved": "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c",
  #   "resolved": "https://registry.npmjs.org/typescript/-/typescript-4.8.2.tgz",
  resolved_uri = let
    cond = x: true;
  # FIXME: I think `uri_ref' is too strict
  in restrict "resolved" cond uri_ref;

  relative_file_uri = let
    cond = x: let
      m = builtins.match "(file:)?(\\.[^:#?]*)" x;
      p = builtins.elemAt m 1;
    in ( m != null ) && ( ur.Strings.path_segments.check p );
  in restrict "uri[relative]" cond string;


# ---------------------------------------------------------------------------- #

  git_uri = restrict "git" ( lib.test "git(\\+(ssh|https?))?://.*" )
                           resolved_uri;


# ---------------------------------------------------------------------------- #

  identifyResolvedType = r: let
    isPath = ( ! ( lib.liburi.Url.isType r ) ) && ( relative_file_uri.check r );
    isGit  = let
      data = ( lib.liburi.Url.fromString r ).scheme.data or null;
    in ( lib.liburi.Url.isType r ) && ( data == "git" );
    isFile = lib.libstr.isTarballUrl r;
  in if isPath then { path = r; } else
     if isGit  then { git = r; } else
     if isFile then { file = r; } else
     throw "(identifyResolvedType) unable to determine type of ${r}";


# ---------------------------------------------------------------------------- #

  # Package Entries ( Plock v3 Only )

  # XXX: All are optional
  pkg-any-fields = ( builtins.mapAttrs ( _: option ) {
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
  } ) // deps;


# ---------------------------------------------------------------------------- #

  pkg-path = let
    fconds = pkg-any-fields // {
      resolved = option relative_file_uri;
      link     = option bool;
    };
    condFields  = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    cond = x: ( condHash x ) && ( condFields x );
  in restrict "pkg[path]" cond ( yt.attrs yt.any );
  
  pkg-dir  = restrict "dir"  ( x: ! ( x.link or false) ) pkg-path;
  pkg-link = restrict "link" ( x: x.link or false ) pkg-path;


# ---------------------------------------------------------------------------- #

  pkg-git = let
    fconds = pkg-any-fields // { resolved = git_uri; };
    condFields  = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    cond = x: ( condHash x ) && ( condFields x );
  in restrict "pkg[git]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #

  pkg-tarball = let
    condHash = x: ( x ? integrity ) || ( x ? sha1 );
    fconds = pkg-any-fields // {
      resolved  = restrict "tarball" yt.Strings.tarball_url.check resolved_uri;
      integrity = option yt.Strings.sha512_sri;
      sha1      = option yt.Strings.sha1_hash;
    };
    condFields  = x: let
      fs = builtins.attrNames ( builtins.intersectAttrs fconds x );
    in builtins.all ( k: fconds.${k}.check x.${k} ) fs;
    cond = x: ( condHash x ) && ( condFields x );
  in restrict "pkg[tarball]" cond ( yt.attrs yt.any );


# ---------------------------------------------------------------------------- #


in {
  Strings = {
    inherit
      resolved_uri
      relative_file_uri
      git_uri
    ;
    tarball_uri = yt.Strings.tarball_url;
  };
  Structs = {
    inherit
      pkg-dir
      pkg-link
      pkg-git
      pkg-tarball
    ;
  };
  inherit
    identifyResolvedType
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
