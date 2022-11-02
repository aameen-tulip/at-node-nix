{ makeSetupHook
, jq, bash, nodejs, gnugrep, gnused, findutils, coreutils
}: makeSetupHook {
  name = "pjs-util";
  deps = [jq bash nodejs gnugrep gnused findutils coreutils];
  substitutions.mk_setup_hook_inject = ''
     These dependencies have been injected by `makeSetupHook'.
    : "''${CP:=${coreutils}/bin/cp}";
    : "''${LN:=${coreutils}/bin/ln}";
    : "''${MKDIR:=${coreutils}/bin/mkdir}";
    : "''${CHMOD:=${coreutils}/bin/chmod}";
    : "''${READLINK:=${coreutils}/bin/readlink}";
    : "''${REALPATH:=${coreutils}/bin/realpath}";
    : "''${JQ:=${jq}/bin/jq}";
    : "''${SED:=${gnused}/bin/sed}";
    : "''${GREP:=${gnugrep}/bin/grep}";
    : "''${FIND:=${findutils}/bin/find}";
    : "''${BASH:=${bash}/bin/bash}";
  '';
  meta = { inherit (bash.meta) platforms; };
} ./pjs-util.sh
