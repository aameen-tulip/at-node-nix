{ lndir          ? pkgs.xorg.lndir
, runCommandNoCC ? pkgs.runCommandNoCC

# Only for fallbacks
, nixpkgs ? builtins.getFlake "nixpkgs"
, system  ? builtins.currentSystem
, pkgs    ? nixpkgs.legacyPackages.${system}
}:
let

  strConcatMap = fn: lst: builtins.concatStringsSep "" ( map fn lst );

  link1 = m: ''
    ${lndir}/bin/lndir -silent -ignorelinks ${m} $out
  '';

  # If the root of a derivation has `package.json', that tells us the caller
  # didn't run a routine to move an unpacked tarball to a subdir.
  # We'll read `package.json' and handle placing things into their
  # appropriate subdir.
  # NOTE: We do NOT handle dependencies or anything fancy.
  # If you have version clashes, you need to invoke `linkModules' multiple
  # times, and organize nested dirs before calling.


  linkedModules = { modules ? [] }: runCommandNoCC "node_modules" {
      inherit modules;
      preferLocalBuild = true;
      allowSubstitutes = false;
  } ( "mkdir -p $out\n" + ( strConcatMap link1 modules ) );

in linkedModules
