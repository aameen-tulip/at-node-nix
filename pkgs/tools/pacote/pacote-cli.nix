# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ pacote, runCommandNoCC }: let

# ---------------------------------------------------------------------------- #

  # cmd  ::= resolve | manifest | packument | tarball | extract
  # spec ::= "package locator", e.g. "lodash" or "/home/foo/bar" or "foo@1.0.0"
  pacotecli = cmd: { spec, dest ? null, ... } @ flags: let

    name = flags.name or
           ( if flags ? dest then baseNameOf flags.dest else "source" );

    setupCache = if flags ? cache then ''
        cp -r --reflink=auto -- ${builtins.storePath flags.cache} $cache
        chmod -R u+w $cache
      '' else ''
        mkdir -p $cache
      '';

    # Don't forget `dest' for `tarball' and `extract' ( dir ) commands.
    # Also remember that `tarball' can take `-' to be `stdout', which we'll
    # probably use.
    pacoteFlags = [
      "--cache=$cache"
      "--json"
      cmd
      spec
    ] ++ ( if builtins.elem cmd ["tarball" "extract"] then ["$out"] else [] );

    stdoutTo = if builtins.elem cmd ["tarball" "extract"] then "$dist" else
               "$out";

  in ( runCommandNoCC name {
    # `tarball' and `extract' dump `{ integrity, resolved, from }' to `stdout'.
    # Capturing these in `$meta' is useful for now, but once we can reliably
    # predict the `resolved' and `from' fields it would write for a URI, we
    # can eliminate that output.
    # NOTE: The hashes produced by Pacote do not match ours coming from
    #       `nix hash path ...' because the file permissions are modified.
    #       You can probably match the original in an `unpack' phase by
    #       recording the perms.
    #       The hashes "round trip" DO align as expected however in Pacote's
    #       output, which might be all that really matters.
    # Ex: The hashes in the `meta' output for both "extract" calls align here.
    #   extract lodash --> tarball "file:./result" --> extract "file:./result"
    outputs =
      ["out" "cache"] ++
      ( if builtins.elem cmd ["tarball" "extract"] then ["dist"] else [] );

    outputHashMode = if cmd == "extract" then "recursive" else "flat";
    outputHashAlgo = "sha256";

    inherit pacoteFlags;
    PACOTE = "${pacote}/bin/pacote";

  } ( setupCache + ''
    pacoteFlagsArray=( $pacoteFlags );
    $PACOTE "''${pacoteFlagsArray[@]}" > ${stdoutTo}
  '' ) ) // { inherit pacote spec pacoteFlags; };


# ---------------------------------------------------------------------------- #

  defaultFallbacks = {
    dependencies = {};
    devDependencies = {};
    peerDependencies = {};
    optionalDependencies = {};
    hasInstallScript = false;
  };

  # Fetch a manifest
  # NOTE: this is basically only useful to generate info for local builds.
  # If you want this info from a registry package use their endpoint to avoid
  # "import from derivation" headaches.
  pacote-manifest = {
    droppedFields  ? ["dist" "engines" "_signatures" "_from"]
  , fallbackFields ? defaultFallbacks
  }: spec: let
    full = pacotecli "manifest" { inherit spec; };
    scrubbed = removeAttrs full droppedFields;
  in fallbackFields // scrubbed;


# ---------------------------------------------------------------------------- #

in { inherit pacotecli pacote-manifest; }

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
