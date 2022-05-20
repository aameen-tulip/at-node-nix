{ runCommandNoCC }:
let
  extractPackageJSON = tarball:
    let outName = "${baseNameOf tarball}-package.json"; in
    runCommandNoCC outName { inherit tarball; } ''
      tar -xz --strip 1 --to-stdout -f ${tarball} package/package.json > $out
    '';
in extractPackageJSON
