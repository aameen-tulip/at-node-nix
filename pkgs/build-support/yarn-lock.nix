{ nixpkgs        ? builtins.getFlake "nixpkgs"
, system         ? builtins.currentSystem
, pkgs           ? nixpkgs.legacyPackages.${system}
, lib            ? import ../../lib { nixpkgs-lib = nixpkgs.lib; }
, fetchurl       ? pkgs.fetchurl
, yarn           ? pkgs.yarn
, yq             ? pkgs.yq
, runCommandNoCC ? pkgs.runCommandNoCC
, writeText      ? pkgs.writeText
, yml2json       ? import ./yml-to-json.nix { inherit yq runCommandNoCC; }
}:
let
  inherit (builtins) match attrNames attrValues filter concatStringsSep toJSON;
  inherit (yml2json) readYML2JSON writeYML2JSON;
  inherit (lib) pkgNameSplit mkPkgInfo readPkgInfo allDependencies
                readWorkspacePackages importJSON' fetchFetchurlTarballArgsNpm;

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

  # FIXME: finish up workspace pacakges
  readYarnDir = dir:
    let
      yarnLock = readYarnLock ( ( toString dir ) + "/yarn.lock" );
      pkgJson = importJSON' ( ( toString dir ) + "/package.json" );
      wsPackages = readWorkspacePackages pkgJson;
      selfPackage =
        if pkgJson ? name then ( ( toString dir ) + "/package.json" ) else [];
    in {
      inherit yarnLock;
      packagePaths = wsPackages ++ selfPackage;
    };


/* -------------------------------------------------------------------------- *
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
 *
 *--------------------------------------------------------------------------- */

  resolvesWithNpm = entry:
    ( builtins.match ".*@npm:.*" entry.resolution ) != null;

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


/* --------------------------------------------------------------------------- *
 *
 * GitHub Entry (resolution only):
 *
 *   "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#master":
 *     version: 3.3.0
 *     resolution: "eslint-plugin-babel@https://github.com/tulip/eslint-plugin-babel.git#commit=8c9530eda76357686e36ae389ed8c302486a3944"
 *
 *
 * -------------------------------------------------------------------------- */

  resolvesWithGit = entry:
    ( match ".*https://github\.com.*\.git#.*" entry.resolution ) != null;

  asGithubFlakeUri = yspec:
    let
      matches =
        match "(.+)@https://github.com/(.*)\.git#(commit=)?(.*)" yspec;
      at          = builtins.elemAt matches;
      name        = builtins.head matches;
      repo        = at 1;
      maybeCommit = at 2;
      ref         = at 3;
    in "github:${repo}?ref=${ref}";

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


/* -------------------------------------------------------------------------- *
 *
 * Workspace Entry:
 *
 *   "export-library-content@workspace:library/ci/export-library-content/tasks/export-library-content":
 *     version: 0.0.0-use.local
 *     resolution: "export-library-content@workspace:library/ci/export-library-content/tasks/export-library-content"
 *
 *
 * -------------------------------------------------------------------------- */

  resolvesWithWorkspace = entry:
    ( match ".*@workspace:.*" entry.resolution ) != null;

  # This is literally just an relative or absolute path to project folder
  # using the `file:' protocol.
  #
  # This tries to get the absolute path, but will fall back to a relative one.
  # Not crazy about this behavior though.
  asWorkspaceSpecifier = packagePaths: yspec:
    let
      subdir   = builtins.head ( match ".*@workspace:(.*)" );
      matchPkg = lib.hasSuffix ( subdir + "/package.json" );
      absPath  = lib.findFirst matchPkg packagePaths;
    in "file:" + ( if ( absPath == null ) then subdir else absPath );

  getWorkspaceResolutions' = packagePaths: entries:
    let filt = filter resolvesWithWorkspace packagePaths ( attrValues entries );
    in map ( e: e.resolution ) filt;

  getWorkspaceResolutions = packagePaths: entries:
    map asWorkspaceSpecifier ( getWorkspaceResolutions' packagePaths entries );

  getWorkspaceResolutionsAsFileUri = entries:
    let
      inherit (builtins) match head elemAt attrValues listToAttrs;
      wsToFp = e: let m = match "(.+)@workspace:(.*)" e.resolution;
                      name = head m;
                      path = elemAt m 1;
                  in { inherit name; value = "file:./" + path; };
    in listToAttrs ( map wsToFp ( attrValues entries ) );


/* -------------------------------------------------------------------------- *
 *
 * Patch Entries:
 *
 * The "builtin" patches are only relevant to PnP, and they only effect 3
 * packages: TypeScript, FSEvent, and Resolve.
 * These patches can be found in the Yarn Berry repository:
 *   `berry/packages/plugin-compat/sources/*.patch'
 *
 *   "fsevents@patch:fsevents@^1.2.2#builtin<compat/fsevents>, fsevents@patch:fsevents@^1.2.7#builtin<compat/fsevents>":
 *      version: 1.2.11
 *      resolution: "fsevents@patch:fsevents@npm%3A1.2.11#builtin<compat/fsevents>::version=1.2.11&hash=11e9ea"
 *
 *
 * This example shows how the `::locator=' field is used to reference other
 * packages in the lock file.
 * Note the "locators" refer to either the top level attribute name, or the
 * resolution field, I'm not actually sure which.
 * These seem limited to only the Electron workspace in our case.
 *
 *   "win-ca@patch:win-ca@3.4.5#./patches/win-ca-max-buffer.patch::locator=tulip-player-desktop%40workspace%3Aelectron":
 *     version: 3.4.5
 *     resolution: "win-ca@patch:win-ca@npm%3A3.4.5#./patches/win-ca-max-buffer.patch::version=3.4.5&hash=647a0a&locator=tulip-player-desktop%40workspace%3Aelectron"
 *
 *   "tulip-player-desktop@workspace:electron":
 *     version: 0.0.0-use.local
 *     resolution: "tulip-player-desktop@workspace:electron"
 *
 *
 * -------------------------------------------------------------------------- */

  resolvesWithPatch = entry: null;

  asPatchSpecifier = yspec: null;

  getPatchResolutions' = entries:
    map ( e: e.resolution ) ( filter resolvesWithPatch ( attrValues entries ) );

  getPatchResolutions = entries:
    map asPatchSpecifier ( getPatchResolutions' entries );



/* -------------------------------------------------------------------------- */

  genFetchurlForNpmResolutions = specs:
    let genFetcher = name:
          let args = fetchFetchurlTarballArgsNpm { inherit name; }; in
          { inherit name args; tarball = fetchurl args; };
    in map genFetcher specs;

  genStringFetchurlForNpmResolutions = specs:
    let
      header = ''
        { pkgs             ? import <nixpkgs> {}
        , fetchurl         ? pkgs.fetchurl
        , linkFarmFromDrvs ? pkgs.linkFarmFromDrvs
        }:
        let fetchers = {
      '';
      genFetcher = name:
        let args = fetchFetchurlTarballArgsNpm { inherit name; }; in ''
          "${name}" = {
            tarball = fetchurl {
              url  = "${args.url}";
              hash = "${args.hash}";
              sha1 = "${args.sha1}";
            };
          };
        '';
      fetchers = builtins.concatStringsSep "" ( map genFetcher specs );
      footer = ''
        };
        _tarballCache = linkFarmFromDrvs "npm-tarball-cache"
          ( mapAttrs ( _: v: v.tarball ) fetchers );
        in tarballs // { inherit _tarballCache; }
      '';
    in header + fetchers + footer;


/* -------------------------------------------------------------------------- */

in {
  inherit resolvesWithNpm asNpmSpecifier getNpmResolutions' getNpmResolutions;

  inherit resolvesWithGit asGitSpecifier getGitResolutions' getGitResolutions;
  inherit asGithubFlakeUri;

  inherit resolvesWithWorkspace asWorkspaceSpecifier getWorkspaceResolutions';
  inherit getWorkspaceResolutions;
  inherit getWorkspaceResolutionsAsFileUri;

  inherit resolvesWithPatch asPatchSpecifier getPatchResolutions';
  inherit getPatchResolutions;
  inherit genFetchurlForNpmResolutions;
  inherit genStringFetchurlForNpmResolutions;

  inherit readYarnLock toNameVersionList;
  inherit readYarnDir;

  writeNpmResolutions = lockFile:
    let specs = getNpmResolutions ( readYarnLock lockFile );
    in writeText "npm-resolvers" ( concatStringsSep "\n" specs );

  writeNpmResolutionsJSON = lockFile:
    let specs = getNpmResolutions ( readYarnLock lockFile );
    in writeText "npm-resolvers.json" ( toJSON specs );

  writeNpmFetchersJSON = lockFile:
    let
      specs = getNpmResolutions ( readYarnLock lockFile );
      fetchers = genFetchurlForNpmResolutions specs;
      asKvPairs = map ( f: { inherit (f) name; value = f.args; } ) fetchers;
      asAttrs = builtins.listToAttrs asKvPairs;
    in writeText "npm-fetchers.json" ( toJSON asAttrs );

  writeNpmFetchersNix = lockFile:
    let specs = getNpmResolutions ( readYarnLock lockFile );
    in writeText "npm-fetchers.nix"
                 ( genStringFetchurlForNpmResolutions specs );
}
