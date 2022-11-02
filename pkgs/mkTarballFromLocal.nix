# ============================================================================ #
#
# Create an NPM registry tarball from a local project.
# The main purpose of this routine, aside from archiving is to unpatch shebang
# lines is scripts so that they align with the checksums expected by
# non-Nix tarballs.
# We use `pacote' to archive for us to avoid fussing with things like
# `.npmignore' and alignment with NPM's file permission fixup.
#
# NOTE: I suspect that I may need to deal with aligning file permissions as well
# because Nix sets files to read-only; I am not sure if `pacote' will
# "magically" handle this for us when archiving though.
#
# I have tested this on several builds as of <2022-08-19 Fri> and the hashes
# here match those we get from `npm pack'/`npm publish'.
# If we get a mismatch the ones to pay attention to are shebangs and any files
# which may contain logs or pathnames which point to the Nix store; Gyp for
# example might be a headache ( luckily we don't use `binding.gyp' today ).
#
# ---------------------------------------------------------------------------- #

{
  name  ? meta.names.tarball
, meta  ? throw "I need 'meta' if 'name' is unspecified"
, source   # Original source code with unpatched shebangs. # XXX: See note below
, prepared # Final "built"/"prepared" tree. `src' clobbers common files.
, pacote
, snapDerivation
, coreutils
}:

# NOTE: (source) Using `source' here relies on the fact that we use
# `builtins.path' to create that store path, meaning the scripts here are
# not patched.
# This may or may not be true for other types of fetchers depending on how
# they are configured; specifically: most Nixpkgs fetchers will patch shebangs
# during `patchPhase' ( after `unpackPhase' and before `configurePhase' ).
#
# NOTE: Pacote should take care of removing `package-lock.json' so we aren't
# particularly concerned about whether `plockFilt' was applied; we DO care about
# `nodeFilt' though - because if it were skipped we may accidentally pull
# "dirty" source tree files built outside of Nix into the tarball.
snapDerivation {
  inherit name;
  PATH = "${coreutils}/bin:${pacote}/bin";
  buildCommand = ''
    mkdir -p  cache
    PACOTE_CACHE="$PWD/cache"
    cp -r --reflink=auto -- ${source} ./package
    chmod -R +rw ./package
    cp -r --reflink=auto --no-clobber -t ./package ${prepared}/*
    chmod -R +rw ./package
    pacote --cache="$PACOTE_CACHE" tarball ./package "$out"
  '';
}
