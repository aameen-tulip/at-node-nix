{ nixpkgs ? builtins.getFlake "nixpkgs"
, system  ? builtins.currentSystem
, pacote  ? ( builtins.getFlake  ( toString ../../../pkgs/development/node-packages/pacote ) ).packages.${system}.pacote
#, pkgs    ? nixpkgs.legacyPackages.${system}
, pkgs    ? nixpkgs.legacyPackages.${system}
}: let
  inherit (builtins) elem concatStringsSep;

  # cmd ::= resolve | manifest | packument | tarball | extract
  pacotecli = cmd: flags @ { spec, dest ? null, ... }: let

    name = flags.name or
           ( if flags ? dest then baseNameOf flags.dest else "source" );

    setupCache = if flags ? cache then ''
        cp -r --reflink=auto -- ${builtins.storePath flags.cache} ./cache
        chmod -R u+w ./cache
      '' else ''
        mkdir -p ./cache
      '';

    # Don't forget `dest' for `tarball' and `extract' ( dir ) commands.
    # Also remember that `tarball' can take `-' to be `stdout', which we'll
    # probably use.
    pacoteFlags = [
      "--cache=./cache"
      "--json"
      cmd
      spec
    ] ++ ( if elem cmd ["tarball" "extract"] then ["$out"] else [] );

    stdoutTo = if elem cmd ["tarball" "extract"] then "$manifest" else "$out";

  in ( pkgs.runCommandNoCC name {
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
              ( if elem cmd ["tarball" "extract"] then ["manifest"] else [] );

    outputHashMode = if cmd == "extract" then "recursive" else "flat";
    outputHashAlgo = "sha256";


  } ( setupCache + ''
    ${pacote}/bin/pacote ${concatStringsSep " " pacoteFlags} > ${stdoutTo}
  '' ) ) // { inherit pacote spec pacoteFlags; };

in {
  inherit pacotecli;
}
