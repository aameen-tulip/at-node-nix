{ pkgs       ? import <nxipkgs> {}
, stdenv     ? pkgs.stdenv
, runCommand ? pkgs.runCommand
, gnutar     ? pkgs.gnutar
}:
# Create a tar wrapper that filters all the
# 'Ignoring unknown extended header keyword' noise.
runCommand "tarWrapper" {} ''
  mkdir -p $out/bin
  cat > $out/bin/tar <<EOF
  #! ${stdenv.shell} -e
  ${gnutar}/bin/tar "\$@" --warning=no-unknown-keyword --delay-directory-restore
  EOF
  chmod +x $out/bin/tar
''
