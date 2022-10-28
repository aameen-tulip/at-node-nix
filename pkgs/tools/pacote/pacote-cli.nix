# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ pacote, runCommandNoCC }: let

# ---------------------------------------------------------------------------- #

  inherit (builtins) elem concatStringsSep;

# ---------------------------------------------------------------------------- #

  # cmd ::= resolve | manifest | packument | tarball | extract
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
    ] ++ ( if elem cmd ["tarball" "extract"] then ["$out"] else [] );

    stdoutTo = if elem cmd ["tarball" "extract"] then "$dist" else "$out";

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
    outputs = ["out" "cache"] ++
              ( if elem cmd ["tarball" "extract"] then ["dist"] else [] );

    outputHashMode = if cmd == "extract" then "recursive" else "flat";
    outputHashAlgo = "sha256";

  } ( setupCache + ''
    ${pacote}/bin/pacote ${concatStringsSep " " pacoteFlags} > ${stdoutTo}
  '' ) ) // { inherit pacote spec pacoteFlags; };


# ---------------------------------------------------------------------------- #

  defaultFallbacks = {
    dependencies = {};
    devDependencies = {};
    peerDependencies = {};
    optionalDependencies = {};
    hasInstallScript = false;
    ## main = "./index.js";
    ## # NOTE: if `bin' is a filepath, rather than an attrset, you need to move
    ## # that field to `directories.bin' and probably delete this field.
    ## bin = {};
    ## # These are `to-path = "from-path";' for installs.
    ## directories = {
    ##   lib      = "lib";
    ##   bin      = "bin";  # XXX: see note above about `bin'
    ##   man      = "man";
    ##   doc      = "doc";
    ##   test     = "test";
    ##   examples = "examples";
    ## };
  };


# ---------------------------------------------------------------------------- #

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

  # NOTE: you can very easily implement this in pure Nix.
  # Pacote is just dropping fields from the registry manifest.
  # NOTE: The registry manifest are `(<scope>/)?<pkg>/<version>', I don't
  # think you leveraged that previously when writing the `packumenter'.
  # NOTE: The manifest fills default `scripts.install' fields for packages
  # with `bindings.gyp', and also has a `gypfile ::= true|false' field which
  # you could use to determine `hasInstallScript'.


# ---------------------------------------------------------------------------- #

in { inherit pacotecli pacote-manifest; }

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
