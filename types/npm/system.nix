# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;
  inherit (yt) struct string list attrs option restrict;
  lib.test = patt: s: ( builtins.match patt s ) != null;

# ---------------------------------------------------------------------------- #
  _npm_cpus = [
    "x64" "ia32" "arm" "arm64" "s390x" "ppc64" "mips64el" "riscv64" "loong64"
    "unknown"
  ];
  Enums.npm_cpu = yt.enum "cpu[npm]" _npm_cpus;


  _npm_oss = [
    "darwin" "freebsd" "netbsd" "linux" "openbsd" "sunos" "sunos-64" "solaris"
    "win32" "aix" "android" "unknown"
  ];
  Enums.npm_os = yt.enum "os[npm]" _npm_oss;


# ---------------------------------------------------------------------------- #

  Attrs.engines = yt.attrs yt.PkgInfo.descriptor;


# ---------------------------------------------------------------------------- #

  _sys_info_fields = {
    cpu = yt.list yt.Npm.Enums.npm_cpu;
    os  = yt.list yt.Npm.Enums.npm_os;
    inherit (yt.Npm.Attrs) engines;
  };

  Structs.sys_info =
    yt.struct "sys_info" ( builtins.mapAttrs yt.option _sys_info_fields );


# ---------------------------------------------------------------------------- #

in {
  inherit
    Enums
    Structs
    Attrs
  ;
  inherit (Structs)
    sys_info
  ;
  inherit
    _npm_cpus
    _npm_oss
    _sys_info_fields
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
