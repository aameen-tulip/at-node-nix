# ============================================================================ #
#
# NPM Lifecycle Events and Command Hooks
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt  = ytypes // ytypes.Core // ytypes.Prim;
  nlc = yt.NpmLifecycle // yt.NpmLifecycle.Enums;

# ---------------------------------------------------------------------------- #

in {

# ---------------------------------------------------------------------------- #

  # Project types recognized by NPM.
  # These are used to determine which lifecycle scripts are run.
  _source_types = ["file" "dir" "link" "git"];

  Enums.source_type =
    yt.enum "npm:lifecycle:source_type" nlc._source_types;


# ---------------------------------------------------------------------------- #

  # Each event has a "pre<event>" and "post<event>" hook, in addition to the
  # event itself.
  # These work for ANY defined script, yes even user defined scripts.
  # The events listed here are those implicitly defined by NPM.
  _events = [
    "install"
    "prepare"  # NOTE: YES, "postprepare" is a thing.
    "pack"
    "publish"
    "restart"
    "start"
    "stop"
    "test"
    "version"
  ];

  Enums.event = yt.enum "npm:lifecycle:event" nlc._events;


# ---------------------------------------------------------------------------- #

  _hooks = [
    "preinstall" "install" "postinstall"
    "preprepare" "prepare" "postprepare"
    "prepack"               "postpack"   # see note below about "pack"/"prepare"
    "prepublish" "prepublishOnly" "publish" "postpublish"
    "prerestart" "restart" "postrestart"
    "prestart"   "start"   "poststart"
    "prestop"    "stop"    "poststop"
    "pretest"    "test"    "posttest"
    "preversion" "version" "postversion"
  ];

  Enums.hook = yt.enum "npm:lifecycle:hook" nlc._hooks;


# ---------------------------------------------------------------------------- #

  # Special hooks

  # NPM's docs discourage "prepublish", saying it's deprecated; they they write
  # two paragaraphs about how fucking useful it is, and neglect to mention a
  # suggested alternative...
  # It's implied that `prepare' might be recommended; but you don't have
  # `devDependencies' available in a `prepare' script.
  # Soooo if you're doing local dev, and you use `file:../<PATH>' descriptors
  # then you're probably going to use `prepublish' to run your "build" phase.
  _special_hooks = [
    "prepare" "prepublish" "prepublishOnly" "prepack" "postpack"
  ];

  Enums.special_hooks = let
    cond = x: builtins.elem x nlc._special_hooks;
  in yt.restrict "special" cond nlc.hook;


# ---------------------------------------------------------------------------- #

  # NPM CLI Commands

  # These trigger hooks which are mapped out in the next section.
  _commands = [
    "cache_add"
    "ci"
    "diff"
    "install"
    "pack"
    "publish"
    "rebuild"
    "restart"
    "start"
    "stop"
    "test"
    "version"
  ];

  Enums.command = yt.enum "npm:cli:command" nlc._commands;


# ---------------------------------------------------------------------------- #

  # Command hooks, listed in order.

  # Each attribute is an `npm <ATTR>' command, spaces are handled camelCase.
  _command_hooks = {
    cache_add = ["prepare"];
    ci = [
      "preinstall"
      "install"
      "postinstall"
      "prepublish"    # has `devDependencies' available. This is legacy nonsense
      "preprepare"
      "prepare"
      "postprepare"
    ];
    diff = ["prepare"];
    # identical to  CI
    install = [
      "preinstall"
      "install"
      "postinstall"
      "prepublish"
      "preprepare"
      "prepare"
      "postprepare"
    ];
    pack = ["prepack" "prepare" "postpack"];
    # XXX: `publish' doesn't run `prepublish' ... because "reasons".
    # No but seriously it doesn't.
    # NPM says it's about legacy support or something but from where I'm
    # standing this seems like madness.
    publish = [
      "prepublishOnly"
      "prepack"
      "prepare"         # skipped if `--dry-run' was indicated
      "postpack"
      "publish"
      "postpublish"
    ];
    rebuild = [
      "preinstall"
      "install"
      "postinstall"
      "prepare"      # Only run if CWD is a symlink
    ];
    restart = ["prerestart" "restart" "postrestart"];
    start   = ["prestart"   "start"   "poststart"];
    stop    = ["prestop"    "stop"    "poststop"];
    test    = ["pretest"    "test"    "posttest"];
    version = ["preversion" "version" "postversion"];
  };

  # For Git Deps ( based on `pacote' and `npm' implementation ):
  #   Only `prepare' is run.
  #   `pre/post-pack' is NOT run - those only run for `npm (pack|publish)'
  #   A tarball is made "manually" by checking `plock.files', `.gitignore',
  #   `.npmignore', and NPM's default include/exclude rules.
  #   Honestly, this behavior seems like nonsense to me, but whatever.


  Enums.cache_add_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.cache_add;
  in yt.restrict "cache_add" cond nlc.hooks;

  Enums.ci_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.ci;
  in yt.restrict "ci" cond nlc.hooks;

  Enums.diff_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.diff;
  in yt.restrict "diff" cond nlc.hooks;

  Enums.install_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.install;
  in yt.restrict "install" cond nlc.hooks;

  Enums.pack_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.pack;
  in yt.restrict "pack" cond nlc.hooks;

  Enums.publish_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.publish;
  in yt.restrict "publish" cond nlc.hooks;

  Enums.rebuild_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.rebuild;
  in yt.restrict "rebuild" cond nlc.hooks;

  Enums.restart_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.restart;
  in yt.restrict "restart" cond nlc.hooks;

  Enums.start_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.start;
  in yt.restrict "start" cond nlc.hooks;

  Enums.stop_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.stop;
  in yt.restrict "stop" cond nlc.hooks;

  Enums.test_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.test;
  in yt.restrict "test" cond nlc.hooks;

  Enums.version_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.version;
  in yt.restrict "version" cond nlc.hooks;


# ---------------------------------------------------------------------------- #

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
