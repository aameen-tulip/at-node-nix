{ pkgs           ? import <nixpkgs> {}
, yarn           ? pkgs.yarn
, jq             ? pkgs.jq
, runCommandNoCC ? pkgs.runCommandNoCC
, nix-gitignore  ? pkgs.nix-gitignore
}:
let
  inherit ( import ./yml-to-json.nix { inherit pkgs runCommandNoCC; } )
    readYML2JSON writeYML2JSON;

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

  readYarnLock = readYML2JSON;


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
}
