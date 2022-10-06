# ============================================================================ #
#
# Filter source trees.
# Notable filters:
#   - packCore: filter files to align with `npm pack' routine.
#   - nix:      filter out Nix related files.
#
# ---------------------------------------------------------------------------- #

#{ lib }: let
{ ... }: let

# ---------------------------------------------------------------------------- #

  npmPackCoreRules = [
    { bname = "package.json";      keep = true;  }
    { bname = "package-lock.json"; keep = false; }
    { bname = ".git";              keep = false; }
    { bname = "CVS";               keep = false; }
    { bname = ".svn";              keep = false; }
    { bname = ".hg";               keep = false; }
    { bname = ".lock-wscript";     keep = false; }
    { bname = ".wafpickle-N";      keep = false; }
    { bname = ".npm-debug.log";    keep = false; }
    { bname = ".npmrc";            keep = false; }
    { bname = "config.gypi";       keep = false; }
    #  .*.swp
    { bpatt = "\\..*\\.swp"; keep = false; }
    #  *.orig
    { bpatt = ".*\\.orig"; keep = false; }
    #  ._*
    { bpatt = "\\._.*"; keep = false; }
    #  README*  ( case insensitive )
    { bpatt = "[Rr][Ee][Aa][Dd][Mm][Ee].*"; keep = true;  }
    #  LICENSE* ( case insensitive )
    { bpatt = "[Ll][Ii][Cc][Ee][Nn][Ss][Ee].*"; keep = true;  }
  ];

  asPred = { bname ? null, bpatt ? null, ... }: name: type: let
    b = baseNameOf name;
    p = ( builtins.match bpatt b ) != null;
    n = bname == b;
  in assert bname != null -> bpatt == null;
     assert bpatt != null -> bname == null;
     if bname == null then p else n;

  # NOTE: check for bundled dependencies.
  # { bname = "node_modules"; }

  # These are always applied when `npm pack' is run.
  # Authors must explicitly list rules in `"files": [...]' to override these.
  packCore = name: type: let
    proc = rsl: { keep, bpatt ? null, bname ? null } @ rule:
      if rsl != null then rsl else
      if asPred rule name type then keep else
      null;
    checks = builtins.foldl' proc null npmPackCoreRules;
  in if checks == null then true else checks;


# ---------------------------------------------------------------------------- #




# ---------------------------------------------------------------------------- #

in {
  inherit
    packCore
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
