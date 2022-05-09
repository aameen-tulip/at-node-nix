# Helper functions used in `installPhase' routines throughout `node2nix'.
# NOTE: Do not add a shebang, this file is only sourced by other scripts.
# FIXME: The author of `node2nix' is uses the term "install" in the way that
#        Node.js does; this function is more accurately an `unpackPhase' routine
#        and various parts of `node2nix' should really be modified to adhere to
#        the appropriate Nix phases.
installNodePackage() {
  local packageName="$1" src="$2" DIR="$PWD" strippedName=
  cd "$TMPDIR"

  # FIXME: This belongs in an `unpackPhase'.
  unpackFile "$src"

  # Make the base dir in which the target dependency resides first
  mkdir -p "${packageName##*/}"

  if test -f "$src"; then
    # Figure out what directory has been unpacked
    packageDir="$( find . -maxdepth 1 -type d | tail -1; )"

    # Restore write permissions to make building work
    find "$packageDir" -type d -exec chmod u+x {} \;
    chmod -R u+w "$packageDir"

    # Move the extracted tarball into the output folder
    mv -f -- "$packageDir" "$DIR/$packageName"
  elif test -d "$src"; then
    # Get a stripped name (without hash) of the source directory.
    # On old nixpkgs it's already set internally.
    : "${strippedName:-$( stripHash $src; )}"

    # Restore write permissions to make building work
    chmod -R u+w "$strippedName"

    # Move the extracted directory into the output folder
    mv -f -- "$strippedName" "$DIR/$packageName"
  fi

  # Change to the package directory to install dependencies
  # FIXME: Set `sourceRoot'.
  cd "$DIR/$packageName"
}
