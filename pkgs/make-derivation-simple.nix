/**
 * A minimal `mkDerivation' alternate which is nice for many of the
 * trivial "symlink some junk" or "echo warning about Yarn being
 * literal malware" that we do in most of these builders.
 *
 * In many cases we will still use `nixpkgs.stdenv.mkDerivation', but this is
 * a nice trimmed down compromise between a "raw" derivation and the entire
 * kitchen sink that `nixpkgs' provides.
 *
 * XXX: Overlays, overrides, and other junk are no good here - we avoid using
 * `stdenv' intentionally.
 *
 * Cribbed from `nix/tests/config.nix.in'
 */
{ bash
, coreutils
, system
, contentAddressedByDefault ? false
}: let
  caArgs = if contentAddressedByDefault then {
    __contentAddressed = true;
    outputHashMode     = "recursive";
    outputHashAlgo     = "sha256";
  } else {};
  # NOTE: You do not have GNU `tar' or any other compression programs here.
  # This is intentional.
  # If you need to (un)zip something do it in a separate derivation on it's own,
  # preferably by directly invoking `tar' with `ak-nix.tarutils'.
  # The rationale here is that if you unzip and move or `mkdir' or basically
  # look at the result funny - you'll cause a different CA hash and end up
  # with gazillions of redundant store paths that placed the same tarball in
  # a different subdir.
  # Instead, unzip ONCE, and symlink if you need the contents in a subdir.
  # Matching the registry tarball's integrity hash is critical!
  snapDerivation = args: derivation ( {
    inherit system;
    preferLocalBuild = true;
    builder = "${bash}/bin/bash";
    PATH    = "${coreutils}/bin";
    args = ["-e"
      ( args.builder or ( builtins.toFile "builder-${args.name}.sh" ''
          if test -e ".attrs.sh"; then
            source .attrs.sh;
          fi
          eval "$buildCommand";
        '' ) )
    ];
  } // caArgs // ( removeAttrs args ["builder" "meta" "passthru"] ) ) // {
   meta     = args.meta or {};
   passthru = args.passthru or {};
 };

in snapDerivation
