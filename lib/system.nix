# ============================================================================ #
#
# These are aimed at handling NPM's `cpu' and `os' fields for optinal deps.
#
# The spec here is:
#   If a dependency is marked as optional, the install is allowed to fail
#   ( this ain't going to fly with Nix so this is tough to replicate ).
#   A `package.json' may indicate the fields `cpu' and `os' to specify the
#   systems it is intended to support; from the consumer perspective if a dep
#   is marked optional we can assume the install will fail is the `cpu'/`os'
#   declarations tell us that our system is unsupported - this allows Nix to
#   at least skip these to align with the spec more closely.
#
# Given that Nix really can't align with the NPM spec here "perfectly" without
# performing installs in a sort of `try ... catch' type environment; these
# fields are enormously helpful.
#
# I have constructed this list of CPUs and OSs from those that I have
# encountered in the wild; and you may find the need to extend this list.
# I encourage you to PR if you find values that I haven't listed here.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  nixArchToNpmCpuMap = {
    x86_64      = "x64";
    i686        = "ia32";
    aarch       = "arm";
    aarch64     = "arm64";
    powerpc64le = "ppc64";
    mipsel      = "mipsel64";
    riscv64     = "riscv64";
    unknown     = "unknown";
  };
  nixArches = builtins.attrNames nixArchToNpmCpuMap;

  npmCpuToNixArchMap = {
    x64      = "x86_64";
    ia32     = "i686";
    arm      = "aarch";
    arm64    = "aarch64";
    s390x    = "unknown";
    ppc64    = "powerpc64le";
    mips64el = "mipsel";
    riscv64  = "riscv64";
    loong64  = "unknown";
  };
  npmCpus = builtins.attrNames npmCpuToNixArchMap;

  nixArchToNpmCpu = p: let
    msg = "Unsupported CPU: ${p}. " +
          "( If this sounds wrong add it to the list in `lib/system.nix' )";
    np = nixArchToNpmCpuMap.${p} or ( throw msg );
  in builtins.deepSeq ( lib.assertOneOf "NPM CPU" np npmCpus ) np;

  npmCpuToNixArch = p: let
    msg = "Unsupported CPU: ${p}. " +
          "( If this sounds wrong add it to the list in `lib/system.nix' )";
    na = npmCpuToNixArchMap.${p} or ( throw msg );
  in builtins.deepSeq ( lib.assertOneOf "Nix Arch" na nixArches ) na;

  # Takes a `nixpkgs.(build|host|target)Platform' attrset as an argument.
  # Returns the NPM CPU enum for that platform.
  getNpmCpuForPlatform = { uname, ... }: nixArchToNpmCpu uname.processor;

  # Takes a Nix system pair and returns the NPM CPU enum for that platform.
  getNpmCpuForSystem = system:
    nixArchToNpmCpu ( builtins.head ( builtins.split "-" system ) );


# ---------------------------------------------------------------------------- #

  # Maps `platform.parsed.kernel.name' to NPM OS.
  # These are almost always the same; but there's a few exceptions so I won't
  # be lazy.
  npmOSToNixOSMap = {
    darwin   = "darwin";
    freebsd  = "freebsd";
    netbsd   = "netbsd";
    linux    = "linux";
    openbsd  = "openbsd";
    sunos    = "sunprocess";
    sunos-64 = "sunprocess";
    solaris  = "sunprocess";
    win32    = "win32";
    # Unsupported:
    aix     = "unknown";
    android = "unknown";
    unknown = "unknown";
  };
  npmOSs = builtins.attrNames npmOSToNixOSMap;
  npmOSToNixOS= o: let
    msg = "Unsupported OS: ${o}. " +
          "( If this sounds wrong add it to the list in `lib/system.nix' )";
    no = npmOSToNixOSMap.${o} or ( throw msg );
  in builtins.deepSeq ( lib.assertOneOf "Nix OSs" no nixOSs ) no;


  nixOSToNpmOSMap = {
    darwin     = "darwin";
    freebsd    = "freebsd";
    netbsd     = "netbsd";
    linux      = "linux";
    openbsd    = "openbsd";
    sunprocess = "solaris";
    win32      = "win32";
    # Unsupported:
    unknown = "unknown";
  };
  nixOSs = builtins.attrNames nixOSToNpmOSMap;
  nixOSToNpmOS = o: let
    msg = "Unsupported OS: ${o}. " +
          "( If this sounds wrong add it to the list in `lib/system.nix' )";
    no = nixOSToNpmOSMap.${o} or ( throw msg );
  in builtins.deepSeq ( lib.assertOneOf "NPM OSs" no npmOSs ) no;

  getNpmOSForPlatform = { parsed, ... }: nixOSToNpmOS parsed.kernel.name;
  getNpmOSForSystem   = system: nixOSToNpmOS ( lib.yank "[^-]+-(.*)" system );


# ---------------------------------------------------------------------------- #

  # This is the "anything to system to OS/CPU" helper.
  # Takes "whatever you've got laying around" and tries to figure out the NPM
  # CPU and OS to be used.
  # Returns `null' if we can't figure it out, while `getNpmSys' ( no "'" ) will
  # `throw' an error instead.`
  # NOTE: It's incredibly unlikely ( seriously ) that only one of OS/CPU can be
  # discovered, the user would have to explicitly pass one without passing args
  # that allow the other to be discovered; so while this is basically never
  # going to happen we return `null' unless both can be figured out.
  #
  # You can comb through the conditionals to see the fallback behavior, but
  # the priority is:
  #   os|cpu
  #   system
  #   hostPlaform  ( from `stdenv'. `buildPlatform' is used as a fallback )
  #
  # Personally, I would pass `system' here unless you're cross-compiling, in
  # which case you'll want to pass `hostPlatform'.
  getNpmSys' = {
    system ? null
  , cpu ?
      if args ? npmSys.cpu then npmSys.cpu else
      if args ? system then getNpmCpuForSystem system else
      if hostPlatform != null then getNpmCpuForPlatform hostPlatform else
      # `system' bottoms out to `null' in pure mode.
      if system != null then getNpmCpuForSystem system else null
  , os ?
      if args ? npmSys.os then npmSys.os else
      if args ? system then getNpmOSForSystem system else
      if hostPlatform != null then getNpmOSForPlatform hostPlatform else
      # `system' bottoms out to `null' in pure mode.
      if system != null then getNpmOSForSystem system else null
  # Priority for platforms aligns with Nixpkgs' fallbacks
  , hostPlatform ? if stdenv != null then stdenv.hostPlatform else buildPlatform
  , buildPlatform ? if stdenv != null then stdenv.buildPlatform else null
  , stdenv ? args.pkgsFor.stdenv or args.pkgs.stdenv or null
  , npmSys ? throw "(getNpmSys'): UNREACHABLE"
  , ...
  } @ args: if ( os == null ) ||( cpu == null ) then null else {
    inherit cpu os;
  };

  # Same as `getNpmSys'' except `throw' an error on failure.
  # NOTE: This declares phony fallbacks to trick `builtins.functionArgs' and
  # `lib.functionArgs' - refer to the real args above.
  # I could have used `lib.setFunctionArgs' here, or just made a functor; but
  # since I think I've used `builtins.functionArgs' in other parts of the
  # codebase I'm just going to do this the ugly way so the `builtin' works.
  getNpmSys = {
    system ? null, cpu ? null, os ? null, hostPlatform ? null
  , buildPlatform ? null, stdenv ? null, npmSys ? null, ...
  } @ args: let
    rsl = getNpmSys' args;
    msg = "(getNpmSys): Failed to derive OS and/or CPU from args";
  in if rsl != null then rsl else throw msg;


# ---------------------------------------------------------------------------- #

  # Create a conditional that can be applied to a `package[-lock].json' entry to
  # determine if the package is supported by the host system.
  pkgCpuCond = { cpu ? null, ... } @ pjs: sysArgs: let
    npmSys  = getNpmSys sysArgs;
    hostCpu = if builtins.isString sysArgs then sysArgs else npmSys.cpu;
  in assert hostCpu != null;
     if cpu == null then true else builtins.elem hostCpu cpu;

  pkgOSCond = { os ? null, ... } @ pjs: sysArgs: let
    npmSys  = getNpmSys sysArgs;
    hostOS = if builtins.isString sysArgs then sysArgs else npmSys.os;
  in assert hostOS != null;
     if os == null then true else builtins.elem hostOS os;

  # Handles OS and CPU together.
  pkgSysCond = { cpu ? null, os ? null, ... } @ pjs: sysArgs: let
    npmSys  =
      if ( builtins.isAttrs sysArgs ) &&
         ( sysArgs ? os ) && ( sysArgs ? cpu ) then sysArgs else
      if builtins.isString sysArgs then getNpmSys { system = sysArgs; } else
      getNpmSys sysArgs;
    cpuCond = if cpu == null then true else builtins.elem npmSys.cpu cpu;
    osCond  = if os  == null then true else builtins.elem npmSys.os os;
  in assert npmSys.os  != null;
     assert npmSys.cpu != null;
     cpuCond && osCond;


# ---------------------------------------------------------------------------- #

  metaEntGetSysInfoFromMetaFiles = metaEnt: let
    mfs  = builtins.filter builtins.isAttrs
                           ( builtins.attrValues
                             ( lib.libmeta.getMetaFiles metaEnt ) );
    oss  = builtins.catAttrs "os"      mfs;
    cpus = builtins.catAttrs "cpu"     mfs;
    engs = builtins.catAttrs "engines" mfs;
    nos  = map npmOSToNixOS ( builtins.head oss );
    ncpu = map npmCpuToNixArch ( builtins.head cpus );
  in if mfs == [] then null else {
    os      = if ( oss == [] )  then null else nos;
    cpu     = if ( cpus == [] ) then null else ncpu;
    engines = if ( engs == [] ) then null else builtins.head engs;
  };


# ---------------------------------------------------------------------------- #

  metaEntSetSysInfoOv = final: prev: let
    try = metaEntGetSysInfoFromMetaFiles final;
  in if ( prev.sysInfo or null ) != null then prev else {
    sysInfo = ( if try == null then {} else try ) // {
      __serial = self: let
        nn = lib.filterAttrs ( _: v: v != null)
                              ( removeAttrs self ["__serial"] );
      in if nn == {} then "__DROP__" else nn;
    };
  };


# ---------------------------------------------------------------------------- #

  # FIXME: Handle `engines' particularly Node.js version.
  # Reading engine versions for NPM and Yarn may be useful indirectly to provide
  # hints to `metaEnt' functions; but I don't see any real reason to fool with
  # them until the need comes up.


# ---------------------------------------------------------------------------- #

in {

  inherit
    nixArchToNpmCpu
    npmCpuToNixArch
    nixOSToNpmOS
    npmOSToNixOS

    getNpmCpuForPlatform
    getNpmCpuForSystem
    getNpmOSForPlatform
    getNpmOSForSystem
    getNpmSys'
    getNpmSys

    pkgCpuCond
    pkgOSCond
    pkgSysCond

    metaEntGetSysInfoFromMetaFiles
    metaEntSetSysInfoOv
  ;

}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
