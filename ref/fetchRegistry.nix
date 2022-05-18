with builtins;
let
  pkgs = import <nixpkgs> {};
  rsp = readFile ( fetchurl "https://registry.npmjs.org/typescript" );
  ts = fromJSON rsp;
  getTb = { integrity ? null, tarball, ... }: { inherit integrity tarball; };
  allTarballs = map ( v: ( getTb v.dist ) ) ( attrValues ts.versions );
  itarballs = filter ( v: v.integrity != null ) allTarballs;
  target = head itarballs;
  tb = pkgs.fetchurl { url = target.tarball; sha512 = target.integrity; };
  pkgj = pkgs.runCommandNoCC "package.json" {} ''
      tar -xz --strip 1 --to-stdout -f ${tb} package/package.json > $out
    '';
in fromJSON ( readFile pkgj )
