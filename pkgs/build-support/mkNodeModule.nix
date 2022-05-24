{ stdenv, nodejs }:

# FIXME: Allow dependencies to be pulled from a global package set
{ src, buildInputs ? [] }:
let
  srcIsArchive = let bname = baseNameOf src; in
    ( builtins.match ".*\.(zip|tar|tar\..*|tgz|txz|tbz2|tbz)$" bname ) != null;

  srcUnpacked =
    let unpacked = stdenv.mkDerivation {
      name = "unpacked-src";
      inherit src;
      dontPath = true;
      dontConfigure = true;
      dontBuild = true;
      installPhase = "cp -pr --reflink=auto -- . $out";
      dontFixup = true;
    };
  in if srcIsArchive then unpacked else src;

  pkgInfo =
    builtins.fromJSON ( builtins.readFile "${srcUnpacked}/package.json" );
  # "@tulip/foo" ==> [ "@tulip/" "tulip" "foo" ]
  splitName = builtins.match "(@([^/]+)/)?(.*)" pkgInfo.name;
  pname = builtins.elemAt splitName 2;
  scope = builtins.elemAt splitName 1;
  tarballName =
    if scope != null then "${scope}-${pname}-${version}.tgz"
                     else "${pname}-${version}.tgz";
  inherit (pkgInfo) version;

  # A setup-hook
  symlinkNodeModuleHook =
    let
      fnName = let rawName = if scope != null
                             then "linkNodeModule_at_${scope}_slash_${pname}"
                             else "linkNodeModule_${pname}";
        in builtins.replaceStrings ["-"] ["_"] rawName;
      scopeDir = if scope != null then "/@${scope}" else "";
    in ''
      symlinkNodeModulesHooks+=( ${fnName} )
      ${fnName}() {
        test -n "$dontLinkNodeModules" && return
        if test -z "$NODE_MODULES_DIR"; then
          if test -z "$sourceRoot"; then
            NODE_MODULES_DIR="$PWD/node_modules"
          else
            NODE_MODULES_DIR="$TMP/$sourceRoot/node_modules"
          fi
        fi
        if test ! -e "$NODE_MODULES_DIR/${pkgInfo.name}"; then
          mkdir -p "$NODE_MODULES_DIR${scopeDir}"
          ln -s "@out@/lib/node_modules/${pkgInfo.name}"  \
                "$NODE_MODULES_DIR/${pkgInfo.name}"
        fi
      '' + ( if pkgInfo ? bin then ''
        mkdir -p "$NODE_MODULES_DIR/.bin"
        find @out@/lib/node_modules/.bin -type f -o -type l  \
              -exec ln -sf {} "$NODE_MODULES_DIR/.bin/" \;
      '' else "" ) +
      "\n}\n";

in stdenv.mkDerivation {
  inherit pname version scope tarballName src buildInputs;

  nativeBuildInputs = [nodejs];

  # FIXME: Mock the config more better.
  # Suppresses complaints from `npm' about missing config files.
  postUnpack = ''HOME="$TMP"'';

  buildPhase = if srcIsArchive then ''
    cp ${src} ./${tarballName}
    # FIXME:
    touch ./tarinfo.json
  '' else ''
    runHook symlinkNodeModules
    runHook preBuild

    npm pack --json > tarinfo.json

    runHook postBuild
  '';

  # We output four things here.
  # 1) A tarball which is equivalent to those served by a registry.
  #    This only contains `package.json' and `tsconfig-base.json'.
  # 2) A "pre-installed"/unpacked `node_modules/' folder.
  # 3) The `package-lock.json' file, which is useful for Nix when working with
  #    package sets, and auto-updating.
  # 4) JSON data produced by `npm pack' which indicates sha and checksum info
  #    that aligns with `package-lock.json' entries.
  installPhase =
    let inherit (builtins) concatStringsSep attrValues mapAttrs; in ''
      mkdir -p "$out/lib/node_modules/${pkgInfo.name}"
      mkdir -p "$out/nix-support" "$out/tarballs"

      tar xzf ./${tarballName}                         \
          -C "$out/lib/node_modules/${pkgInfo.name}/"  \
          --strip 1
    '' + ( /* Handle bins */ if pkgInfo ? bin then ''
      mkdir -p "$out/bin" "$out/lib/node_modules/.bin"
    '' + ( concatStringsSep "\n" ( attrValues ( mapAttrs ( k: v: ''
      ln -s "$out/lib/node_modules/${pkgInfo.name}/${v}" "$out/bin/${k}"
      ln -s "$out/lib/node_modules/${pkgInfo.name}/${v}"  \
            "$out/lib/node_modules/.bin/${k}"
      # FIXME: This doesn't properly handle cross-compilatio
      sed -i 's,#!.*node$,#!${nodejs}/bin/node,'            \
              "$out/lib/node_modules/${pkgInfo.name}/${v}"
      chmod +x "$out/lib/node_modules/${pkgInfo.name}/${v}"
    '' ) pkgInfo.bin ) ) ) else "" ) + ''

      cp ./${tarballName} "$out/tarballs/"
      if test -e ./package-lock.json; then
        cp ./package-lock.json ./tarinfo.json "$out/nix-support/"
      fi

      cat <<'EOF' > "$out/nix-support/setup-hook"
      ${symlinkNodeModuleHook}
      EOF
      substituteInPlace "$out/nix-support/setup-hook" --subst-var out
    '';

  dontConfigure = true;
  dontCheck = true;
  dontFixup = true;
}
