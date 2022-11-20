# ============================================================================ #
#
# Resolved URI Types
#
# NOTE: These do not necessarily imply which fetcher will be used and the
# names of these types aim to align with the names used by NPM/Pacote rather
# than Nix - this can trip you up on "file" and "path" URIs if you conflate
# the Nix and NPM/Pacote names so be careful.
#
# NPM and Pacote ( the NPM "fetcher" utility ) recognize 4 types of source trees
# and each type implies that certain "lifecycle" scripts will be run after
# extracting a package when `npm install' is run.
#
# - file: Implies that a tree is "prepared".
#         Only `scripts.install' will run.
#         This is the type used for registry tarballs, and path dirs when the
#         `--install-links' flag is active.
# - dir:  Implies that a tree is a path directory.
#         `prepare', and `install' scripts will be run.
#         In the `floco' framework we also run `build' scripts for this type.
# - link: A symlink to a `dir' tree.
#         `prepare', `prepack', and `install' scripts will be run.
#         In the `floco' framework we also run `build' scripts for this type.
# - git:  A checkout of a `git' repository.
#         NPM only runs `prepare' and `install' but not `prepack'.
#
# See [[file:../lifecycle.nix]] for details.
#
# Reference data under: tests/libfetch/data/proj2/package-lock.json
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

  # NPM/Pacote URI Types
  # These refer to "lifecycle" types as opposed to fetchers.

  # Used for tarballs, and paths when `--install-links' was set.
  file_uri = let
    prefixCond     = lib.test "file:.*";  # used by `npm i --install-links'
    tarballUrlCond = yt.Strings.tarball_url.check;
    # Basically the only registry that doesn't put the tarball in the URL...
    githubPkgCond = lib.test "https://npm\\.pkg\\.github\\.com/download/.*";
    cond = x:
      ( yt.Uri.Strings.uri_ref.check x ) &&
      ( ( tarballUrlCond x ) || ( githubPkgCond x ) || ( prefixCond x ) );
  in ytypes.__internal.typedef "npm:uri[file]" cond;

  # Must not have a "file:" prefix.
  link_uri = let
    cond = x: ( builtins.isString x ) && ( ! ( lib.test "file:.*" x ) ) &&
              ( yt.FS.Strings.relpath.check x );
  in ytypes.__internal.typedef "npm:uri[link]" cond;

  git_uri = let
    cond = lib.test "git(\\+(ssh|https?))?://.*";
  in ytypes.__internal.typedef "npm:uri[git]" cond;

  # "path" ltype, but if I export the name "path_uri" from this file I'd
  # absolutely shoot myself in the foot later - so its getting a gross name.
  dir_uri = let
    cond = x:
      ( x == "" ) ||
      ( ( builtins.isString x ) && ( ! ( lib.test "file:.*" x ) ) &&
        ( yt.FS.Strings.relpath.check x ) );
  in ytypes.__internal.typedef "npm:uri[dir]" cond;


# ---------------------------------------------------------------------------- #

  # These URIs aren't NPM/Pacote fetcher types, they are for convenience when
  # typechecking fetchers.

  # Unless "file:" is given, absolute paths are disallowed.
  # Pacote will return absolute paths, but NPM won't and we won't see those
  # in `package-lock.json'.
  path_uri = let
    cond = x:
      ( builtins.isString x ) &&
      ( ( lib.test "file:.*" x ) || ( x == "" ) ||
        ( yt.FS.Strings.relpath.check x ) );
  in ytypes.__internal.typedef "npm:uri:phony[path]" cond;

  remote_uri = let
    cond = x:
      ( builtins.isString x ) &&
      ( lib.test "(git(\\+ssh)?|(git\\+)?https?)://.*" x );
  in ytypes.__internal.typedef "npm:uri:phony[remote]" cond;

  # Tells us we need to convert to abspath.
  relative_file_uri =
    yt.restrict "relative" ( lib.test "file:\\..*" ) file_uri;


# ---------------------------------------------------------------------------- #

  # link, dir, file, git
  #   "resolved": "git+ssh://git@github.com/lodash/lodash.git#2da024c3b4f9947a48517639de7560457cd4ec6c",
  #   "resolved": "https://registry.npmjs.org/typescript/-/typescript-4.8.2.tgz",
  _resolved_uri_types = [git_uri dir_uri file_uri link_uri];
  resolved_uri        = yt.eitherN _resolved_uri_types;


# ---------------------------------------------------------------------------- #

in {
  Strings = {
    inherit
      file_uri
      link_uri
      git_uri
      dir_uri

      path_uri
      remote_uri
      relative_file_uri
    ;
  };
  Eithers = {
    inherit
      resolved_uri
    ;
  };
  inherit
    file_uri
    link_uri
    git_uri
    dir_uri
    resolved_uri
  ;
  inherit
    _resolved_uri_types
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
