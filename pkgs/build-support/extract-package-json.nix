{ runCommandNoCC }:
let
  extractPackageJSON = tarball:
    runCommandNoCC ( ( baseNameOf tarball ) + "-package.json" ) {
      inherit tarball;
    } ''
    tar -xzq --strip 1 --to-stdout -f ${tarball} package/package.json > $out
  '';
in extractPackageJSON
