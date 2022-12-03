# ============================================================================ #
#
# General tests for `libsys' routines.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (lib.libsys)
    getNpmCpuForPlatform
    getNpmCpuForSystem
    getNpmOSForPlatform
    getNpmOSForSystem
    getNpmSys'
    getNpmSys
    pkgCpuCond
    pkgOSCond
    pkgSysCond
  ;

# ---------------------------------------------------------------------------- #

  systems = [
    "x86_64-linux"  "aarch64-linux"
    "x86_64-darwin" "aarch64-darwin"
  ];

  plats = map lib.systems.elaborate systems;


# ---------------------------------------------------------------------------- #

  tests = {

    # Basics
    testGetNpmCpuForPlatform = {
      expr = map getNpmCpuForPlatform plats;
      expected = ["x64" "arm64" "x64" "arm64"];
    };
    testGetNpmCpuForSystem = {
      expr = map getNpmCpuForSystem systems;
      expected = ["x64" "arm64" "x64" "arm64"];
    };
    testGetNpmOSForPlatform = {
      expr = map getNpmOSForPlatform plats;
      expected = ["linux" "linux" "darwin" "darwin"];
    };
    testGetNpmOSForSystem = {
      expr = map getNpmOSForSystem systems;
      expected = ["linux" "linux" "darwin" "darwin"];
    };


# ---------------------------------------------------------------------------- #

    testGetNpmSys'_system = {
      expr = getNpmSys' { system = "x86_64-linux"; };
      expected = { os = "linux"; cpu = "x64"; };
    };

    testGetNpmSys'_cpuOs = {
      expr = getNpmSys' { os = "linux"; cpu = "x64"; };
      expected = { os = "linux"; cpu = "x64"; };
    };

    testGetNpmSys'_plat = {
      expr = getNpmSys' {
        buildPlatform = lib.systems.elaborate "x86_64-linux";
      };
      expected = { os = "linux"; cpu = "x64"; };
    };

    testGetNpmSys'_stdenv = {
      expr = getNpmSys' {
        stdenv.buildPlatform  = lib.systems.elaborate "x86_64-linux";
        stdenv.hostPlatform   = lib.systems.elaborate "x86_64-linux";
        stdenv.targetPlatform = lib.systems.elaborate "x86_64-linux";
      };
      expected = { os = "linux"; cpu = "x64"; };
    };

    testGetNpmSys'_npmSys = {
      expr = getNpmSys' { npmSys = { os = "linux"; cpu = "x64"; }; };
      expected = { os = "linux"; cpu = "x64"; };
    };

    # We really just care that the `(builtins|lib).functionArgs' align.
    testGetNpmSys = {
      expr = [
        ( builtins.functionArgs getNpmSys )
        ( lib.functionArgs getNpmSys )
      ];
      expected = [
        ( builtins.functionArgs getNpmSys' )
        ( lib.functionArgs getNpmSys' )
      ];
    };


# ---------------------------------------------------------------------------- #

    testPkgCpuCond = {
      expr = let
        checkSys = pjs: pkgCpuCond pjs { system = "x86_64-linux"; };
      in map checkSys [
        { cpu = ["x64" "arm64"]; }
        {}
        { cpu = ["arm64"]; }
      ];
      expected = [
        true
        true
        false
      ];
    };

    testPkgOSCond = {
      expr = let
        checkSys = pjs: pkgOSCond pjs { system = "x86_64-linux"; };
      in map checkSys [
        { os = ["linux" "darwin"]; }
        {}
        { os = ["darwin"]; }
      ];
      expected = [
        true
        true
        false
      ];
    };

    testPkgSysCond = {
      expr = let
        checkSys = pjs: pkgSysCond pjs { system = "x86_64-linux"; };
      in map checkSys [
        { cpu = ["x64" "arm64"]; }
        { os = ["linux" "darwin"]; }
        {}
        { cpu = ["arm64"]; }
        { os = ["darwin"]; }
        { cpu = ["x64" "arm64"]; os = ["linux"]; }
        { cpu = ["x64" "arm64"]; os = ["darwin"]; }
        { cpu = ["arm64"]; os = ["linux"]; }
        { cpu = []; os = ["linux"]; }
      ];
      expected = [
        true
        true
        true
        false
        false
        true
        false
        false
        false
      ];
    };

  };  # End Tests


# ---------------------------------------------------------------------------- #

in tests


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
