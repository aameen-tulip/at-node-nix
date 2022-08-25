# ============================================================================ #

{ lib }: let

# ---------------------------------------------------------------------------- #

  # These are aimed at handling NPM's `cpu' and `os' fields for optinal deps.
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
  npmCpus = [
    "x64"
    "ia32"
    "arm"
    "arm64"
    "s390x"  # No clue
    "ppc64"
    "mips64el"
  ];

  npmProcessorMap = {
    x86_64   = "x64";
    aarch64  = "arm64";
  };

  npmLookupProc = p: let
    msg = "Unsupported CPU: ${p}. " +
          "( If this sounds wrong add it to the list in `lib/pkginfo.nix' )";
    np = npmProcessorMap.${p} or ( throw msg );
  in lib.assertOneOf "NPM CPU" np npmCpus;

  # Takes a `nixpkgs.(build|host|target)Platform' attrset as an argument.
  # Returns the NPM CPU enum for that platform.
  getNpmCpuForPlatform = { uname, ... }: npmLookupProc uname.processor;

  # Takes a Nix system pair and returns the NPM CPU enum for that platform.
  getNpmCpuForSystem = system:
    npmLookupProc ( builtins.head ( builtins.split "-" system ) );


# ---------------------------------------------------------------------------- #

  npmOSs = [
    "darwin"
    "freebsd"
    "linux"
    "openbsd"
    "sunprocess"
    "win32"
    "aix"
    "android"
  ];

  # Maps `platform.parsed.kernel.name' to NPM OS.
  # These are almost always the same; but there's a few exceptions so I won't
  # be lazy.
  npmOSMap = {
    darwin  = "darwin";
    freebsd = "freebsd";
    linux   = "linux";
    openbsd = "openbsd";
    solaris = "sunprocess";  # The oddball
    win32   = "win32";
    # Unsupported:
    #  aix
    #  android
  };

  npmLookupOS = o: let
    msg = "Unsupported OS: ${o}. " +
          "( If this sounds wrong add it to the list in `lib/pkginfo.nix' )";
    no = npmOSMap.${o} or ( throw msg );
  in lib.assertOneOf "NPM OSs" no npmOSs;

  getNpmOSForPlatform = { parsed, ... }: npmLookupOS parsed.kernel.name;
  getNpmOSForSystem   = system: npmLookupOS ( lib.yank "[^-]+-(.*)" system );


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
  #   os|cpu       ( if passed `flocoConfig.npmSys' can supply these  )
  #   system
  #   hostPlaform  ( from `stdenv'. `buildPlatform' is used as a fallback )
  #   builtins.currentSystem ( iff flocoConfig.enableImpureMeta = true ).
  #
  # Personally, I would pass `system' here unless you're cross-compiling, in
  # which case you'll want to pass `hostPlatform'.
  getNpmSys' = {
    system ? if enableImpureMeta then builtins.currentSystem else null
  , cpu ?
      if args ? flocoConfig.npmSys.cpu then flocoConfig.npmSys.cpu else
      if args ? system then lib.getNpmCpuForSystem system else
      if hostPlatform != null then lib.getNpmCpuForPlatform hostPlatform else
      # `system' bottoms out to `null' in pure mode.
      if system != null then lib.getNpmCpuForSystem system else null
  , os ?
      if args ? flocoConfig.npmSys.os then flocoConfig.npmSys.os else
      if args ? system then lib.getNpmOSForSystem system else
      if hostPlatform != null then lib.getNpmOSForPlatform hostPlatform else
      # `system' bottoms out to `null' in pure mode.
      if system != null then lib.getNpmOSForSystem system else null
  # Priority for platforms aligns with Nixpkgs' fallbacks
  , hostPlatform     ? if stdenv != null then stdenv.hostPlatform else
                       args.flocoConfig.hostPlatform or buildPlatform
  , buildPlatform    ? if stdenv != null then stdenv.buildPlatform else
                       args.flocoConfig.buildPlatform or null
  , enableImpureMeta ? args.flocoConfig.enableImpureMeta or
                       lib.libcfg.defaultFlocoConfig.enableImpureMeta # (false)
  , stdenv      ? args.pkgsFor.stdenv or args.pkgs.stdenv or null
  , npmSys      ? throw "(getNpmSys'): UNREACHABLE"
  , flocoConfig ? throw "(getNpmSys'): UNREACHABLE"
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
  , buildPlatform ? null, enableImpureMeta ? null, stdenv ? null
  , flocoConfig ? null, npmSys ? null, ...
  } @ args: let
    rsl = getNpmSys' args;
    msg = "(getNpmSys): Failed to derive OS and/or CPU from args";
  in if rsl != null then rsl else throw msg;


# ---------------------------------------------------------------------------- #

  # FIXME: Handle `engines' particularly Node.js version.
  # Reading engine versions for NPM and Yarn may be useful indirectly to provide
  # hints to `metaEnt' functions; but I don't see any real reason to fool with
  # them until the need comes up.


# ---------------------------------------------------------------------------- #

in {

  inherit
    getNpmCpuForPlatform
    getNpmCpuForSystem
    getNpmOSForPlatform
    getNpmOSForSystem
    getNpmSys'
    getNpmSys
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
