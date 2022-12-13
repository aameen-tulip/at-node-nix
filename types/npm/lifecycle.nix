# ============================================================================ #
#
# NPM Lifecycle Events and Command Hooks.
#
# ---------------------------------------------------------------------------- #
#
# WARNING: This is a rant written late at night after trying for probably the
# 12th time in as many months to decypher NPM's documentation about `event'
# scripts and the install lifecycle.
#
#
# If the rules that this file seem convoluted, and you feel like there is
# contradictory exceptions - you're fucking right but don't blame me blame
# NPM maintainers.
# In fairness to them, they pioneered this process and it grew organically into
# a mess which happens with most systems driven by committee.
#
# If you're wondering "where does NPM expect me to define my build process?"
# the answer depends on which section of their two page doc you read.
# Some sections say "use `prepublish'", and the following section says
# "`prepublish' is deprecated don't use it, use `prepare'", then when you ask
# "but `prepare' doesn't install `devDependencies', so what should I do?", they
# say "yeah use `prepublish' unless your project is hosted on `git', then
# use `prepare'", and you ask "what if my project is on `git' and I want to
# publish to NPM? or what if I'm developing on it locally in a workspace?",
# they never answer these questions but the real answer is:
# NPM was never designed to be a build tool, TypeScript and Webpack completely
# threw a wrench in the fundamentals of JavaScript being an interpreted
# scripting language, and if you are expecting NPM or Node to act like some kind
# of JIT compilation system you're shit out of luck - go learn Python, or better
# yet compile C code as God intended.
#
# For real though this event pipeline they have is an absolute mess and
# navigating it is frustrating.
# If you're writing your own package the honest truth is you're better off
# writing your build recipe inline in `buildPhase' - we only have to map this
# shit out so we can deal with the thousands of open source projects that
# expect them to work at install time.
#
# With that in mind - the goal of this file really is not to get
# "local projects" to execute a build process like NPM ( because it's ass ),
# rather its to port the install process of registry tarballs and provide
# limited support for building from an NPM `package-lock.json'
# or `shrinkwrap.json' style lockfile.
#
# Also just for the record, I want to give critical support to NPM Maintainers
# because it is absolutely not their fault that webshits insist on trying to use
# JavaScript and NPM to behave like a `Makefile' and Compiler Collection.
# My advice to them would only be to remove `npm run *', `npm test`, etc" and
# related CLI commands, and hardline against anyone requesting that NPM
# install `devDependencies' for anything outside of CWD, or add `npm build'.
# Just point to the dumpster fire that is Yarn when they ask "why not!?"
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt  = ytypes // ytypes.Core // ytypes.Prim;
  nlc = yt.Npm // yt.Npm.Enums;

# ---------------------------------------------------------------------------- #

in {

# ---------------------------------------------------------------------------- #

  # Project types recognized by NPM.
  # These are used to determine which lifecycle scripts are run.
  _source_types = ["file" "dir" "link" "git"];

  Enums.source_type =
    yt.enum "npm:lifecycle:source_type" nlc._source_types;

  Enums.ltype = yt.Npm.Enums.source_type;


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
    "publish"  # XXX: "prepublish" hook has nothing to do with this event...
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
    "prepublish"      # see note above. the name of this hook is a lie.
    "prepublishOnly"  # the "real" `prepublish' hook. see note above.
    "prepack"   # only runs for `npm pack' and `npm publish'.
    # `prepare' is the weird one. It is used for most commands, but different
    # commands run `(pre|post)pack' for `npm (pack|publish)', or
    # `(pre|post)prepare' for `npm (ci|install)', and
    # ( TODO: confirm this, usure ) /from what I can tell/ they don't run any
    # hooks for `npm (rebuild|cache_add|diff)'.
    # XXX: `git' dependencies have `devDependies' available for this hook!
    # Why? Because NPM maintainers learned absolutely nothing after deprecating
    # `prepublish' - seriously in a single page of documentation they explain
    # why installing `devDependenices' during `install' was "evil" to justify
    # dropping `prepublish', and in the next fucking paragraph they're like
    # "`prepare' is better because it doesn't install `devDependencies'...
    # by the way `prepare' nstalls `devDependencies' on every third Thursday
    # that Venus aligns with Jupiter."
    "prepare"
    "postpack"  # only runs for `npm pack' and `npm publish'.
  ];

  Enums.special_hooks = let
    cond = x: builtins.elem x nlc._special_hooks;
  in yt.restrict "special" cond nlc.Enums.hook;


  # This list is used by helper routines in `[[file:../lib/events.nix]]' to skip
  # checking for edge cases when processing events for a given `ltype'.
  # Values in this list should indicate "this event has a special condition for
  # <LTYPE> which skips or modifies the default process".
  # The `_special_hooks' list is a more appropriate place to mark
  # "general oddballs" and edge cases that don't relate to `ltype'.
  _special_events = [
    "install"  # skips `prepublish' for `git'. NOTE: applies to `ci' command too
    "rebuild"  # only runs `prepare' for `link'.

    # NOTE: this one is weird but not relevant to `ltype' processing.
    # It's not a `hook', so I'm documenting it here.
    # # Does not run `prepublish', runs `prepublishOnly' instead...
    # # Hook order is abnormal.
    # # skips `prepare' if `--dry-run' was given, but we have no equivalent.
    # "publish"
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

  # FIXME: I think you this record conflates commands and events.
  # I wrote it a long time ago and wasn't as aware of how events and commands
  # were distinct; in fairness to "past me", you try reading the NPM docs and
  # see how well you do.

  # Command hooks, listed in order.

  # Each attribute is an `npm <ATTR>' command, spaces are handled camelCase.
  _command_hooks = {

    # TODO: does `(pre|post)prepare' run?
    cache_add = ["prepare"];

    ci = [
      "preinstall"
      "install"
      "postinstall"
      "prepublish"    # Does not run for `git'. Allows `devDependencies'.
      "preprepare"
      "prepare"
      "postprepare"
    ];

    # TODO: does `(pre|post)prepare' run?
    diff = ["prepare"];

    # identical to  CI
    install = [
      "preinstall"
      "install"
      "postinstall"
      "prepublish"   # Does not run for `git'. Allows `devDependencies'.
      "preprepare"
      "prepare"
      "postprepare"
    ];

    pack = ["prepack" "prepare" /* NPM emits tarball */ "postpack"];

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
      # TODO: does `(pre|post)prepare' run?
      "prepare"      # only for `link'
    ];

    restart = ["prerestart" "restart" "postrestart"];
    start   = ["prestart"   "start"   "poststart"];
    stop    = ["prestop"    "stop"    "poststop"];
    test    = ["pretest"    "test"    "posttest"];
    version = ["preversion" "version" "postversion"];
  };

  # TODO: the not below is old and it is unclear about which "command" is being
  # discussed here.
  # Reread the docs and move the relevant info into inline comments in the maps
  # defined above.
  #
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
