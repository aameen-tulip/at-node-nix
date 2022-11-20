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

  # Lifecycle Events

  # These /mostly/ align with the NPM CLI commands with a few exceptions.
  # Specifically `npm ci' and `npm install' both run the `install' event, and
  # `npm cache add' runs the `prepare' event.
  #
  # Each event has a "pre<event>" and "post<event>" hook, in addition to the
  # event itself.
  # These work for ANY defined script, yes even user defined scripts.
  # The events listed here are those implicitly defined by NPM.
  #
  # XXX: Read the sections below about "special hooks and events"
  _events = [
    "install"
    "prepare"  # NOTE: YES, "postprepare" is a thing.
    "pack"     # NOTE: there is no `pack' hook, which is a builtin routine.
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

  # Special hooks and events

  # Special hooks indicate that the `command -> hooks' map defined below has
  # has conditionals for certain lifecycle events.

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
  in yt.restrict "special" cond nlc.Enums.hook;

  _special_events = [
    "prepublish"
  ];


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
  #   Only `install' + `prepare' is run.
  #   `pre/post-pack' is NOT run - those only run for `npm (pack|publish)'
  #   A tarball is made "manually" by checking `plock.files', `.gitignore',
  #   `.npmignore', and NPM's default include/exclude rules.
  #   Honestly, this behavior seems like nonsense to me, but whatever.


  Enums.cache_add_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.cache_add;
  in yt.restrict "cache_add" cond nlc.Enums.hook;

  Enums.ci_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.ci;
  in yt.restrict "ci" cond nlc.Enums.hook;

  Enums.diff_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.diff;
  in yt.restrict "diff" cond nlc.Enums.hook;

  Enums.install_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.install;
  in yt.restrict "install" cond nlc.Enums.hook;

  Enums.pack_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.pack;
  in yt.restrict "pack" cond nlc.Enums.hook;

  Enums.publish_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.publish;
  in yt.restrict "publish" cond nlc.Enums.hook;

  Enums.rebuild_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.rebuild;
  in yt.restrict "rebuild" cond nlc.Enums.hook;

  Enums.restart_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.restart;
  in yt.restrict "restart" cond nlc.Enums.hook;

  Enums.start_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.start;
  in yt.restrict "start" cond nlc.Enums.hook;

  Enums.stop_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.stop;
  in yt.restrict "stop" cond nlc.Enums.hook;

  Enums.test_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.test;
  in yt.restrict "test" cond nlc.Enums.hook;

  Enums.version_hooks = let
    cond = x: builtins.elem x nlc._command_hooks.version;
  in yt.restrict "version" cond nlc.Enums.hook;


# ---------------------------------------------------------------------------- #

  _deprecated_hooks = [
    # Required `devDependencies' which NPM discourages.
    # In practice NPM aims to be an installer and publishing tool aimed at
    # prepping a RUNTIME environment for Node.js packages - it was not designed
    # to be a build tool.
    # With that in mind `devDependencies' was never a priority - the build
    # environment was historically not a concern of package registries, whose
    # goal is to distribute and install "ready to use" artifacts.
    #
    # The `prepublish' hook threw a wrench in this because it committed to
    # installing `devDependencies' and executing builds.
    # This exploded the complexity of other features like `npm link' which
    # implicitly became responsible for detecting and responding to file changes
    # like a `Makefile' or similar build tool would.
    #
    # Given the fact that this was the only CLI command that provided
    # `devDependencies', people started using to "build" their project and
    # the name "prepublish" stopped making sense.
    # This hook started to be run when NPM installed "file:" sources which is
    # when the wheels started to fall off the cart.
    # This came full circle when RFCs requested the creation of a
    # "prepublishOnly" hook described as "a hook to run after `prepublish' and
    # before `publish'"...
    #
    # The recommendation  is now to use `prepare' where you previously used
    # `prepublish', and `prepublishOnly' when you actually want to run a hook
    # before publishing ( as opposed to installing "file:" sources ).
    # `prepare' does not install `devDependencies', so this helped steer people
    # away from using NPM as a build tool as well which is another nice bonus.
    #
    # While this isn't exactly related, the context given here is useful to
    # explain why the NPM registry enforces valid `dependencies',
    # `optionalDependencies', and `peerDependencies' fields when publishing,
    # but is perfectly happy to let authors publish packages with garbage
    # entries for `devDependencies'.
    # It's because NPM doesn't ever read those fields when installing
    # distributed/registry tarballs and does not prioritize support for NPM
    # being used as a build tool - this rationale explains some treatment of
    # these fields by our framework as well and allows us to proceed with some
    # confidence when we completely skip or omit `devDependencies' during
    # certain build phases.
    "prepublish"
  ];

  Enums.deprecated_hooks = let
    cond = x: builtins.elem x nlc._deprecated_hooks.test;
  in yt.restrict "deprecated" cond nlc.Enums.hook;


# ---------------------------------------------------------------------------- #

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
