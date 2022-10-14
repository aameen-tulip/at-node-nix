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
  inherit (pi.Strings) identifier version locator descriptor;
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
    cond = x: builtins.all identifier.check ( builtins.attrNames x );
  in restrict "dep_descriptors" cond ( attrs descriptor );

  deps = {
    dependencies     = option deps;
    devDependencies  = option deps;
    peerDependencies = option deps;
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

  pkg-any-fields = let
    fields = [
      "name" "version" "dependencies*" "resolved" "license" "engines" "bin"
      "os" "cpu"
    ];
  # XXX: All are optional
  in builtins.mapAttrs ( _: option ) {
    name     = identifier;
    version  = locator;
    resolved = resolved_uri;
  };


# ---------------------------------------------------------------------------- #

  pkg-path-fields = pkg-any-fields // {
    resolved = option relative_file_uri;
    link     = option bool;
  };

  pkg-path = struct "pkg[path]" pkg-path-fields;

  pkg-dir = let
    cond = x: ! ( x.link or false );
  in restrict "dir" cond pkg-path;

  pkg-link = let
    cond = x: x.link or false;
  in restrict "link" cond pkg-path;


# ---------------------------------------------------------------------------- #

  pkg-git = struct "pkg[git]" ( pkg-any-fields // {
    resolved = let
      cond = lib.test "git(\\+(ssh|https?))?://.*";
    in restrict "git" cond resolved_uri;
  } );


# ---------------------------------------------------------------------------- #

  pkg-tarball = let
    cond = x: ( x ? integrity ) || ( x ? sha1 );
  in restrict "tarball" cond ( struct "pkg" ( pkg-any-fields // {
    # FIXME: `lib.ytypes.Strings.tarball_url'
    resolved =
      restrict "tarball" ( lib.test "(file\\+)?https?://.*" ) resolved_uri;
    # FIXME: it is mandatory to have at least one
    integrity = option yt.Strings.sha512_sri;
    # FIXME: this belongs in `ak-nix'
    sha1 = option ( restrict "hash[sha1]" ( lib.test "[[:xdigit:]]+" )
                                          string );
  } ) );


# ---------------------------------------------------------------------------- #


in {
  Strings = {
    inherit
      resolved_uri
      relative_file_uri
    ;
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
