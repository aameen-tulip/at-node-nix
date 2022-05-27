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


/* -------------------------------------------------------------------------- */

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

/* -------------------------------------------------------------------------- */

  resolvesWithNpm = entry: ( match ".*@npm:.*" .resolution ) != null;

  # Produces an NPM `pacote' style resolver from a Yarn resolver.
  asNpmSpecifier = yspec: concatStringsSep "" ( match "(.*@)npm:(.*)" yspec );

  getNpmResolutions' = entries:
    map ( e: e.resolution ) ( filter resolvesWithNpm ( attrValues entries ) );

  getNpmResolutions = entries:
    map asNpmSpecifier ( getNpmResolutions' entries );


/* -------------------------------------------------------------------------- */

  toNameVersionList = entries:
    map ( k: { inherit (entries.${k}) version;
               name = let sname = pkgNameSplit k; in
                      if sname.scope != null
                      then "@${sname.scope}/${sname.pname}"
                      else sname.pname;
             } ) ( attrNames entries );


/* -------------------------------------------------------------------------- */

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

/* --------------------------------------------------------------------------- *
 *
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
 *
 * --------------------------------------------------------------------------- *
 *
 * GitHub Entry (resolution only):
 *
 *   "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#master":
 *     version: 3.3.0
 *     resolution: "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#commit=8c9530eda76357686e36ae389ed8c302486a3944"
 * # Strip `commit=', and remove everything before the `@'
 *
 *
 * --------------------------------------------------------------------------- *
 *
 * Workspace Entry:
 *
 *   "export-library-content@workspace:library/ci/export-library-content/tasks/export-library-content":
 *     version: 0.0.0-use.local
 *     resolution: "export-library-content@workspace:library/ci/export-library-content/tasks/export-library-content"
 *
 *
 * Patch Entries:
 *   "fsevents@patch:fsevents@^1.2.2#builtin<compat/fsevents>, fsevents@patch:fsevents@^1.2.7#builtin<compat/fsevents>":
 *      version: 1.2.11
 *      resolution: "fsevents@patch:fsevents@npm%3A1.2.11#builtin<compat/fsevents>::version=1.2.11&hash=11e9ea"
 *
 *   "win-ca@patch:win-ca@3.4.5#./patches/win-ca-max-buffer.patch::locator=tulip-player-desktop%40workspace%3Aelectron":
 *     version: 3.4.5
 *     resolution: "win-ca@patch:win-ca@npm%3A3.4.5#./patches/win-ca-max-buffer.patch::version=3.4.5&hash=647a0a&locator=tulip-player-desktop%40workspace%3Aelectron"
 *
 *
 * -------------------------------------------------------------------------- */

  resolvesWithGit = entry:
    ( match ".*https://github\.com.*\.git#.*" entry.resolution ) != null;

  #asGitSpecifier = yspec:
  #  let
  #    matches =
  #      match "(.+)@https://github.com/(.*)\.git#(commit=)?(.*)" yspec;
  #    at          = builtins.elemAt matches;
  #    name        = head matches;
  #    repo        = at 1;
  #    maybeCommit = at 2;
  #    ref         = at 3;
  #  in "${name}@https://github"

  # Produces an NPM `pacote' style resolver from a Yarn resolver.
  asGitSpecifier = yspec:
    let split = match "(.*#)commit=(.*)" yspec;
    in if split == null then yspec else concatStringsSep "" split;

/**
 * PACOTE CALL:
 *   This can VERY easily be turned into a `flake' URI.
 *
 *   > pacote resolve --long --json 'eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#8c9530eda76357686e36ae389ed8c302486a3944'
 *   http fetch GET 200 https://codeload.github.com/tulip/eslint-plugin-babel/tar.gz/8c9530eda76357686e36ae389ed8c302486a3944 298ms (cache revalidated)
 *   {
 *     "resolved": "git+ssh://git@github.com/tulip/eslint-plugin-babel.git#8c9530eda76357686e36ae389ed8c302486a3944",
 *     "integrity": "sha512-vzo8zhs0rACZCDvfWo+7vH++f397de4TqygawVO9A6JcwRcDH12T2oXQqJUlDeMcwLf/9yZdxptn7H1PlRG6jQ==",
 *     "from": "github:tulip/eslint-plugin-babel#8c9530eda76357686e36ae389ed8c302486a3944"
 *   }
 */

  getGitResolutions' = entries:
    map ( e: e.resolution ) ( filter resolvesWithGit ( attrValues entries ) );

  getGitResolutions = entries:
    map asGitSpecifier ( getGitResolutions' entries );


/* -------------------------------------------------------------------------- */


in {
  inherit readYarnLock resolvesWithNpm asNpmSpecifier getNpmResolutions';
  inherit getNpmResolutions toNameVersionList;
  inherit resolvesWithGit asGitSpecifier getGitResolutions' getGitResolutions;

  writeNpmResolutions = file:
    let specs = getNpmResolutions ( readYarnLock file );
    in writeText "npm-resolvers" ( concatStringsSep "\n" specs );
}
