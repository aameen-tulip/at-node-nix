{ pkgs           ? import <nixpkgs> {}
, lib            ? pkgs.lib
, yarn           ? pkgs.yarn
, jq             ? pkgs.jq
, coreutils      ? pkgs.coreutils
, findutils      ? pkgs.findutils
, gnutar         ? pkgs.gnutar
, runCommandNoCC ? pkgs.runCommandNoCC
, nix-gitignore  ? pkgs.nix-gitignore
, writeText      ? pkgs.writeText
, lib-pkginfo    ? import ../../lib/pkginfo.nix {}
}:
let
  inherit (builtins)  match attrNames attrValues filter concatStringsSep;
  inherit ( import ./yml-to-json.nix { inherit pkgs runCommandNoCC; } )
    readYML2JSON writeYML2JSON;
  inherit (lib-pkginfo) pkgNameSplit mkPkgInfo readPkgInfo allDependencies;

  # FIXME
  mkEntry = {
      lockFileKey
    , version
    , resolution
    , dependencies ? []
    , checksum
    , languageName
    , linkType
    }: {};

  readYarnLock = file: removeAttrs ( readYML2JSON file ) ["__metadata"];

  resolvesWithNpm = entry: ( match ".*@npm:.*" ( entry.resolution ) ) != null;

  asNpmSpecifier = yspec: concatStringsSep "" ( match "(.*@)npm:(.*)" yspec );

  getNpmResolutions' = entries:
    map ( e: e.resolution ) ( filter resolvesWithNpm ( attrValues entries ) );

  getNpmResolutions = entries:
    map asNpmSpecifier ( getNpmResolutions' entries );

  toNameVersionList = entries:
    map ( k: { inherit (entries.${k}) version;
               name = let sname = pkgNameSplit k; in
                      if sname.scope != null
                      then "@${sname.scope}/${sname.pname}"
                      else sname.pname;
             } ) ( attrNames entries );

  yarnChecksumFromTarball = tarball:
    runCommandNoCC "yarn-checksum" {
      inherit tarball;
      PATH = lib.makeBinPath [coreutils findutils gnutar];
    } ''
      tar xz --warning=no-unknown-keyword  \
             --delay-directory-restore     \
             --no-same-owner               \
             --no-same-permissions         \
          -f $tarball
      sha512sum <(
        printf '%s' $( find package -type f -print  \
                        |sort                      \
                        |xargs sha512sum -b        \
                        |cut -d' ' -f1
                     )
      )|cut -d' ' -f1 > $out
  '';

/**
 * Example Entry:
 *
 *   "3d-view@npm:^2.0.0":
 *     version: 2.0.0
 *     resolution: "3d-view@npm:2.0.0"
 *     dependencies:
 *       matrix-camera-controller: ^2.1.1
 *       orbit-camera-controller: ^4.0.0
 *       turntable-camera-controller: ^3.0.0
 *     checksum: f62bd12683a64817a60f2999ef940d953cc71a3ca88f424d7cd30f7a60f2b2c8a6dbf4e87d1301b4ddf25244a20928b840edb517bb6782736bb55c64d98a923b
 *     languageName: node
 *     linkType: hard
 */

in {
  inherit readYarnLock resolvesWithNpm asNpmSpecifier getNpmResolutions'
          getNpmResolutions toNameVersionList;

  writeNpmResolutions = file:
    let specs = getNpmResolutions ( readYarnLock file );
    in writeText "npm-resolvers" ( concatStringsSep "\n" specs );
}
