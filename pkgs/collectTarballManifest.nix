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
    # Last line is empty so we drop that too.
    # After that we have file "stat" lines:
    #   ["-rwxr-xr-x 0/0 1985-10-26 03:15 package/bin/esbuild" ...]
    nlines  = builtins.length report';
    sublist = builtins.genList ( i: builtins.elemAt report' ( i + 2 ) )
                               ( nlines - 3 );
  in sublist;


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

  # Detect any bundled dependencies in `node_modules/'.
  tbmBundled = lib.test ".* package/node_modules/.*";

  # Detect "too many files" at the top level.
  # Package tarballs must unpack to a single directory - this is not only a
  # requirement of Nix but also of NPM.
  # Roughly 1/5,000 packages break this rule, generally these are followed
  # immediately by a release that fixes the issue but sometimes authors don't
  # delete the broken releases from the registry.
  # We don't support these, despite the fact that they technically could be.
  # ( 05 fuck-em mix-tape vol. 10: developer is a fuck, 1,000 dead webshits ).
  # We do want to detect these broken tarballs to produce useful error messages.
  tbmTopNodes = lines: let
    top = lib.yank ".* ([^/]+)(/[^ ]*)?";
  in lib.unique ( map top lines );


# ---------------------------------------------------------------------------- #

  genReport = lines: {
    fileX    = builtins.filter tbmFileX lines;
    dirNoX   = builtins.filter tbmDirNoX lines;
    bundled  = builtins.filter tbmBundled lines;
    topNodes = tbmTopNodes lines;
  };


# ---------------------------------------------------------------------------- #




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
