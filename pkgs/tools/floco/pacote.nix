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

    stdoutTo = if elem cmd ["tarball" "extract"] then "$meta" else "$out";

  in ( pkgs.runCommandNoCC name {
    # `tarball' and `extract' dump `{ integrity, resolved, from }' to `stdout'.
    # Capturing these in `$meta' is useful for now, but once we can reliably
    # predict the `resolved' and `from' fields it would write for a URI, we
    # can eliminate that output.
    outputs = ["out"] ++
              ( if elem cmd ["tarball" "extract"] then ["meta"] else [] );

    #__impure = true;
    outputHashMode = "flat";
    outputHashAlgo = "sha256";


  } ( setupCache + ''
    ${pacote}/bin/pacote ${concatStringsSep " " pacoteFlags} > ${stdoutTo}
  '' ) ) // { inherit pacote spec pacoteFlags; };

in {
  inherit pacotecli;
}
