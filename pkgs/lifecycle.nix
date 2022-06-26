{ lib
, stdenv
, nodejs
, python2
, pkgs
# FIXME
, ...
}: let

  # Each event has a "pre<event>" and "post<event>" hook, in addition to the
  # event itself.
  # These work for ANY defined script, yes even user defined scripts.
  # The events listed here are those implicitly defined by NPM.
  events = [
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

  # Special hooks
  # NPM's docs discourage "prepublish", saying it's deprecated; they they write
  # two paragaraphs about how fucking useful it is, and neglect to mention a
  # suggested alternative...
  # It's implied that `prepare' might be recommended; but you don't have
  # `devDependencies' available in a `prepare' script.
  # Soooo if you're doing local dev, and you use `file:../<PATH>' descriptors
  # then you're probably going to use `prepublish' to run your "build" phase.
  specials = ["prepare" "prepublish" "prepublishOnly" "prepack" "postpack"];

  # Command hooks, listed in order.
  # Each attribute is an `npm <ATTR>' command, spaces are handled camelCase.
  commandHooks = {
    cacheAdd = ["prepare"];
    ci = [
      "preinstall"
      "install"
      "postinstall"
      "prepublish"
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

in {
}
