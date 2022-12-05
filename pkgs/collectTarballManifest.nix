# ============================================================================ #
#
# TODO: this can be done purely with IFD you just have to call the abstract
# form of `checkTarballPerms'' - I just don't want to fool with it now because
# I don't have a use case for this in pure mode.
#
# TODO: this relies on the same inner function as `optimizeFetchInfo', and these
# routines should likely be merged to avoid reading the report twice.
#
# ---------------------------------------------------------------------------- #

{ lib
, checkTarballPermsImpure
}: let

# ---------------------------------------------------------------------------- #

  _collectTarballManifest = { url, ... } @ fetchInfo: let
    inherit (( checkTarballPermsImpure url ).passthru) checked;
    report' = lib.splitString "\n" ( builtins.readFile checked.outPath );
    # First line is "PASS"/"FAIL", and second is a "---" separator.
    # After that we have file "stat" lines:
    #   ["-rwxr-xr-x 0/0 1985-10-26 03:15 package/bin/esbuild" ...]
    lines = builtins.tail ( builtins.tail report' );
  in lines;


# ---------------------------------------------------------------------------- #

  # Predicates to filter raw lines.

  # inode sets executable bit.
  tbmHasX = lib.test "[^ ]+x[^ ]* .*";
  # Regular file sets executable bit.
  tbmFileX = lib.test "-[^ ]+x[^ ]* .*";

  # Directory does NOT set executable bit.
  # This is already checked by first line of report, but this is useful for
  # identifying offenders.
  tbmDirNoX = lib.test "d[^x ]+ .*";

  tbmBundled = lib.test ".* package/node_modules/.*";


# ---------------------------------------------------------------------------- #

  genReport = lines: {
    fileX   = builtins.filter tbmFileX lines;
    dirNoX  = builtins.filter tbmDirNoX lines;
    bundled = builtins.filter tbmBundled lines;
  };


# ---------------------------------------------------------------------------- #

  collectTarballManifest = { url, ... } @ fetchInfo: let
    lines = _collectTarballManifest fetchInfo;
  in ( genReport lines ) // {
    all = lines;
  };


# ---------------------------------------------------------------------------- #

in {

  inherit
    _collectTarballManifest
    collectTarballManifest
  ;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
