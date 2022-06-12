# Adds sane defaults for building misc derivations 'round these parts.
# These defaults are largely aimed for the convenience of local/iterative dev.
# These are NOT what you want a `flake.nix' to fall-back onto - because you
# will not get the advantage of Nix's eval cache.
#
# From a `flake.nix' you want to explicitly pass in every argument to ensure
# no "impure" procedures like `currentSystem', `getEnv', `getFlake', etc run.
{ nixpkgs ? builtins.getFlake "nixpkgs"
, system  ? builtins.currentSystem
, pkgs    ? import nixpkgs { inherit system config; }
, config  ? { contentAddressedByDefault = false; }
, ak-nix  ? builtins.getFlake "github:aakropotkin/ak-nix/main"
, lib     ? import ../lib { inherit (ak-nix) lib; }
, ...
}: let
  # This is placed outside of scope to prevent overrides.
  # Don't override it.
  # Don't override bash.
  # Don't override coreutils.
  # Do not pass "go".
  # Do not trigger a rebuild for literally hundreds of thousands of drvs because
  # a single byte changed in a single file connected to `stdenv'.
  # XXX: Are we clear? About not overriding these inputs? Are we?
  snapDerivation = import ./make-derivation-simple.nix {
    inherit (pkgs) bash coreutils;
    inherit (config) contentAddressedByDefault;
    inherit system;
  };

  # Similar to `snapDerivation', these are minimal derivations used to do things
  # like "make symlink", (un)zip a tarball, etc.
  # Don't override them.
  trivial = ak-nix.trivial.${system};
  # This inherit block is largely for the benefit of the reader.
  inherit (trivial) runLn linkOut linkToPath runTar untar tar;

in {

}
