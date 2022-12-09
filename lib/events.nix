# ============================================================================ #
#
# Lifecycle events, hooks, and related commands.
#
# These interfaces detect which lifecycle events and hooks are available for
# a given package so that they may be used to populate arguments to builders.
#
# NPM's various CLI commands trigger these events, and this interface aims to
# standardize a set of fields and lookup routines for port those operations.
#
# This file is best read side by side with [[file:../types/lifecycle.nix]] which
# declares all of NPM's standard lifecycle events, hooks, and the commands that
# trigger each.
# The type system provides hints for which source events are sensitive to
# different types of source trees ( "file", "dir", "link", and "git" ), and this
# file implements the logic which enforces and those edge cases.
#
# TODO: This file is a working draft and currently many routines are not used
# outside of this file
# In the near future most `hasBuild', `hasPrepare', etc fields in metadata will
# be replaced by more detailed rules that can be inferred without being
# explicitly recorded.
# Frankly I had hoped to start using these routines more immediately, but the
# convoluted event system that has grown organically in NPM is clusterfuck and
# until I can verify a lot behaviors I'm hesitant to build infrastructure on top
# of these rules.
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt  = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  nlc = yt.NpmLifecycle // yt.NpmLifecycle.Enums;
  inherit (nlc)
    _source_types
    _events
    _commands
    _command_hooks
    _special_hooks
    _special_events
  ;

# ---------------------------------------------------------------------------- #

# Commands
# "cache_add" "ci" "diff" "install" "pack" "publish" "rebuild" "restart" "start"
# "stop" "test" "version"

# Events
# "install" "prepare" "pack" "publish" "restart" "start" "stop" "test" "version"

# Special Hooks
# "prepare" "prepublish" "prepublishOnly" "prepack" "postpack"



# ---------------------------------------------------------------------------- #

# "Lifecycle Type" indicating the category of `pacote'/NPM source tree
# as it relates to the execution of lifecycle scripts.
# For example, NPM will run `build', `prepare', and `prepack' scripts for
# local paths and `git' "ltypes", but only runs `install' scripts
# for tarballs.
# Because we use a variety of backends to perform fetching, it would be
# inappropriate to call these "fetcher types" or "source tree types" like
# NPM and `pacote' do - so instead we highlight that they explicitly effect
# the execution of lifecycle scripts in our builders.
#
# We do not refer to them as "source types" or "fetcher types", since this
# would be confusing to users and maintainers in relation to the flocoFetch
# "fetcher families" ( "git", "path", and "file" ), as well as Nix's
# "tree types" ( "git", "github", "path", "file", "tarball", etc ).
#
# These names and categories are all closesly related and frequently overlap,
# but the distinctions between them are important depending on their context.


# ---------------------------------------------------------------------------- #

  # Should only be "prepublish" I believe.
  isSpecialEvent' = { typecheck ? false }: let
    inner = e: builtins.elem e _special_events;
  in if ! typecheck then inner else yt.defun [nlc.event yt.bool] inner;

  isSpecialEvent = isSpecialEvent' {};


# ---------------------------------------------------------------------------- #

  # NOTE: don't forget that these are "events" not commands.
  # For example `npm ci' uses `event = "install"'.
  # See notes in [[file:../types/npm/lifecycle.nix]].
  eventHooksForLtype' = { typecheck ? false }: let
    inner = { event, ltype }: let
      ise  = isSpecialEvent' { inherit typecheck; } event;
      base = _command_hooks.${event};
      mlt  = {
        # TODO: confirm that `prepublish' runs for `file', that sounds wrong.
        # Honestly I think my note was backwards, I think this should run for
        # `git' but not `file', `link', or `dir'.
        install.git = lib.remove "prepublish";
        rebuild = {
          # `prepare' only runs for `link'.
          file = lib.remove "prepare";
          dir  = lib.remove "prepare";
          git  = lib.remove "prepare";
        };
      };
    in if ! ise then base else
       if ! ( mlt.${event} ? ${ltype} ) then base else
       mlt.${event}.${ltype} base;
  in if ! typecheck then inner else
     yt.defun [( yt.struct { inherit (nlc) event ltype; } ) yt.bool] inner;

  eventHooksForLtype = eventHooksForLtype' {};


# ---------------------------------------------------------------------------- #

  # FIXME: this needs to be organized by command
  eventsForLifecycleStrict' = ltype: ( nlc.ltype.match ltype {
    git = {
      # XXX: `git' installs `devDependencies' for `prepare' scripts!
      # This is the only case where `devDependencies' will be installed for an
      # install other than `prepublish'.
      prepare = true;   # effectively "setup"/"host-init"
      pack    = false;  # effectively "dist"
      publish = false;
      test    = false;
    };
    link = {
      prepare = true;   # Not 100% sure on this. Erring towards "yes"
      pack    = false;
      publish = false;
      test    = false;
    };
    dir = {
      prepare = true; # Runs for CWD when `npm install' is given with no args.
      pack    = true; # Runs `prepare'
      publish = true;
      test    = true; # Only test the project being build, so only for `dir'.
    };
    file = {
      prepare = false;
      pack    = false;
      publish = false;
      test    = false;
    };
  } ) // {
    install = true;   # effectively "compile"
    # For Apps
    restart = true;  # if defined
    start   = true;
    stop    = true;
    # TODO: No idea what this means.
    version = true;
  };


# ---------------------------------------------------------------------------- #

  metaEntLifecycleOverlay = final: prev: {
    lifecycle = let
      flt = ( eventsForLifecycleStrict' final.ltype ) // {
        build = final.ltype != "file";
      };
      scripts = lib.libmeta.getScripts final;
      # FIXME: `getScripts'
      ifdef = {
        build   = lib.libpkginfo.hasBuildFromScripts scripts;
        prepare = lib.libpkginfo.hasPrepareFromScripts scripts;
        pack    = lib.libpkginfo.hasPackFromScripts scripts;
        test    = lib.libpkginfo.hasTestFromScripts scripts;
        publish = lib.libpkginfo.hasPublishFromScripts scripts;
        install = lib.libpkginfo.hasInstallFromScripts scripts;
      };
      # These are special and need to be set to `null' if we aren't sure.
      hi' = if ( final.gypfile or null ) == null then { install = null; } else {
        install = flt.install && ( ifdef.install || final.gypfile );
      };
      proc = acc: event: acc // { ${event} = flt.${event} && ifdef.${event}; };
      base = builtins.foldl' proc {} ( builtins.attrNames ifdef );
    in base // hi';
  };


# ---------------------------------------------------------------------------- #

in {

  inherit
    isSpecialEvent'     isSpecialEvent
    eventHooksForLtype' eventHooksForLtype

    eventsForLifecycleStrict'
    metaEntLifecycleOverlay
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
