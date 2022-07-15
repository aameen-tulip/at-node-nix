mkBindir = {
  src
, name          ? ( src.meta.name or "node-pkg" ) + "-bindir"
, bindir        ? null   # if unset, we link to "$out"
, bins          ? null   # if unset, read `package.json' dynamically ( Avoid )
, patchShebangs ? false  # patch shebang lines in bins ( Avoid )
}: let
  entries = lib.mapAttrsToList ( n: p: {
    name = "${to}/${n}"; path = "${src}/${p}";
  } ) bins;
  fromMkDrv = stdenv.mkDerivation {
    inherit name src patchShebangs;
    nativeBuildInputs = [jq];
    postUnpack = ''
      if ! test -r "$sourceRoot/package.json"; then
        sourceRoot=$( find "$sourceRoot" -type f -name package.json    \
                            -exec bash -c '                             \
                              f="{}";                                   \
                              s="''${f//[^\/]}";                        \
                              echo "''${#s} ''${f%/package.json}";' \;  \
                        |sort -g -k1|head|cut -d' ' -f2; )
      fi
    '';
    dontPatch     = true;
    dontConfigure = true;
    dontBuild     = true;
    installPhase  = let
      to = if bindir == null then "\"$out\"" else "\"$out/${bindir}\"";
    in lib.withHooks "install" ''
      mkdir -p ${to}
      hasKey() { jq -Mce 'has( .'"$1"' )' package.json > /dev/null; }
      isAttrs() {
        jq -Mce "( .$1|type ) == \"object\"" package.json > /dev/null;
      }
      if hasKey bin; then
        if isAttrs bin; then
        else
          ln -s -- "$$( jq -r '.bin' )"
          # XXX: ...and it was about here that you realized this made no sense
          # because of the unpack phase you have no idea of `src' is a store
          # path - which was the entire reason the old method worked.
          # you only need to rewrite a little bit of this though, and it'll
          # be less complex.
        fi
      fi
    '';
  };
in {}
