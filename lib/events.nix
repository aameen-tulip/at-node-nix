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

in {

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
