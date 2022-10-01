# ============================================================================ #

{ lib }: let

  inherit (lib.libyants)
    any attrs bool defun drv either eitherN enum float function int list option
    path restrict string struct sum type unit
  ;


# ---------------------------------------------------------------------------- #

  plns = "plock";


# ---------------------------------------------------------------------------- #

  pathlike   = either string path;
  url        = string;
  sha512_sri = string;
  sha1_h     = string;


# ---------------------------------------------------------------------------- #

  # Source Entries

  # pls-link = struct "${plns}:src:link" {
  #   resolved = pathlike;
  #   link     = bool;
  # };

  # pls-path = struct "${plns}:src:dir" {
  #   resolved = option pathlike;  # The `pkey'. Defaults to lock dir.
  # };

  # pls-git = struct "${plns}:src:git" {
  #   resolved = url;  # check for "git+" prefix
  # };

  # pls-tarball = struct "${plns}:src:tarball" {
  #   resolved = either url path;
  #   integrity = option sha512_sri;
  #   sha1      = option sha1_h;
  # };


  plsource = struct "${plns}:src" {
    resolved  = either pathlike url;  # NOTE: root entry lacks this
    link      = option bool;
    integirty = option sha512_sri;
    sha1      = option sha1_h;
  };

  # FIXME: enfoce `pathlike' on link and dir.
  pls-link = restrict "link" ( v: v.link or false ) plsource;
  pls-dir  = restrict "dir"  ( v: ! ( v.link or false ) ) plsource;
  pls-git  = restrict "git"  ( v: lib.hasPrefix "git+" v.resolved ) plsource;
  pls-tarball = let
    # I'm not 100% sure local tarballs have hashes
    hashCond = v: ( v ? sha1 ) || ( v ? integrity );
    # FIXME: more tarball extensions
    resCond = v:
      lib.test "[^#]+\\.(tgz|tar.gz|tar.xz)(#.*)?" ( v.resolved or "" );
    cond = v: ( hashCond v ) && ( resCond v );
  in restrict "tarball" cond plsource;


# ---------------------------------------------------------------------------- #

in {

  inherit
    pathlike
    url
    sha512_sri
    sha1_h
  ;

  inherit
    pls-link
    pls-dir
    pls-git
    pls-tarball
    plsource
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
