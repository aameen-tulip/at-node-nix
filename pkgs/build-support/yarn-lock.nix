{ pkgs           ? import <nixpkgs> {}
, lib            ? pkgs.lib
, fetchurl       ? pkgs.fetchurl
, yarn           ? pkgs.yarn
, jq             ? pkgs.jq
, coreutils      ? pkgs.coreutils
, findutils      ? pkgs.findutils
, gnutar         ? pkgs.gnutar
, runCommandNoCC ? pkgs.runCommandNoCC
, nix-gitignore  ? pkgs.nix-gitignore
, writeText      ? pkgs.writeText
, libpkginfo     ? import ../../lib/pkginfo.nix {}
, libregistry    ? import ../../lib/registry.nix
, ymlToJson      ? import ./yml-to-json.nix { inherit pkgs runCommandNoCC; }
}:
let
  inherit (builtins)  match attrNames attrValues filter concatStringsSep toJSON;
  inherit (ymlToJson) readYML2JSON writeYML2JSON;
  inherit (libpkginfo) pkgNameSplit mkPkgInfo readPkgInfo allDependencies;
  inherit (libpkginfo) readWorkspacePackages importJSON';
  inherit (libregistry) fetchFetchurlTarballArgsNpm;

/* --------------------------------------------------------------------------- *

YO!!!!
the fucking checksum field in the `yarn.lock' file matches the `.zip' files
in `.yarn/cache/' - I SHIT YOU NOT THEY USED THE NAR ALGO!


* ---------------------------------------------------------------------------- *

# The second hash of the zipfile's name matches the first 10 characters of
# the checksum.

$ nix hash file --type sha512 --base16 ./.yarn/cache/3d-view-npm-2.0.1-308cc2de85-56e46dfdfc.zip
56e46dfdfcf420bf6ed8b307792fb830285dc2be456e50c45056eeee52bec0547296bf0c42a56b7ab0529783cfce3dae632cb1637e344af985b7258eaadfaf6e

# The process used to generate the first hash is found in Yarn's repo at
# berry/packages/yarnpkg-core/sources/structUtils.ts:443,678.
# It is based on the "locator", being the "@foo/bar@npm:3.0.0" string.
# To get the first part:

nix-repl> builtins.hashString "sha512" ( ( builtins.hashString "sha512" "3d-view" ) + "npm:2.0.1" )
"308cc2de8555097d1b75cd35d70a5e36a9a97277a5903e20690a62f9b20e29ba5fe111f4cbea3c0a5ed23236cbdb4c1e0f3b7cb5263fd7a4642af5d22166ad7a"

The process is:
# REMEMBER: NO "@" characters!
mkIdentHash = { scope ? null, pname }:
  let s = if scope == null then pname else scope + pname; in
  builtins.hashString "sha512" s;
# "Reference" is "npm:<VERSION>", "workspace:<Escaped-Path>", etc
mkLocatorHash = { identHash, reference ? "unknown" }:
  builtins.hashString "sha512" ( identHash + reference )


* ---------------------------------------------------------------------------- *

# `yarn.lock' entry:
"3d-view@npm:^2.0.0":
  version: 2.0.1
  resolution: "3d-view@npm:2.0.1"
  dependencies:
    matrix-camera-controller: ^2.1.1
    orbit-camera-controller: ^4.0.0
    turntable-camera-controller: ^3.0.0
  checksum: 56e46dfdfcf420bf6ed8b307792fb830285dc2be456e50c45056eeee52bec0547296bf0c42a56b7ab0529783cfce3dae632cb1637e344af985b7258eaadfaf6e
  languageName: node
  linkType: hard

* ---------------------------------------------------------------------------- *

# The tarballs in the Yarn cache are local style tarballs without any `bin/'
# handling performed.
  $ zip -sf ./.yarn/cache/3d-view-npm-2.0.1-308cc2de85-56e46dfdfc.zip
  Archive contains:
    node_modules/
    node_modules/3d-view/
    node_modules/3d-view/LICENSE
    node_modules/3d-view/example/
    node_modules/3d-view/example/demo.js
    node_modules/3d-view/example/minimal.js
    node_modules/3d-view/test/
    node_modules/3d-view/test/test.js
    node_modules/3d-view/view.js
    node_modules/3d-view/package.json
    node_modules/3d-view/README.md
  Total 11 entries (23663 bytes)


* ---------------------------------------------------------------------------- *

# Yarn generates the first portion of the hash from this information somehow.
    {
      "descriptor": "3d-view@npm:^2.0.0",
      "locator": "3d-view@npm:2.0.1"
    }

* --------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

  # This is identical to the checksum of the `.zip' file, see top comments.
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


/* -------------------------------------------------------------------------- */

  identHash = { scope ? "", pname }:
    assert ( "@" != ( builtins.substring 0 1 scope ) );
    builtins.hashString "sha512" ( scope + pname  );

  locatorHash' = { scope ? "", pname, reference ? "unknown" }:
    assert ( "@" != ( builtins.substring 0 1 scope ) );
    assert ( "@" != ( builtins.substring 0 1 reference ) );
    let ih = identHash scope pname; in
    builtins.hashString "sha512" ( ih + reference  );

  locatorHash = {
    scope     ? ""
  , pname     ? null
  , idHash    ? identHash scope pname
  , reference ? "unknown"
  }:
  assert ( "@" != ( builtins.substring 0 1 reference ) );
  builtins.hashString "sha512" ( idHash + reference );

  yarnCachedTarballName = {
    scope     ? ""
  , pname
  , idHash    ? identHash scope pname
  , reference ? "unknown"
  , loHash    ? locatorHash idHash reference
  , checksum  # SHA512 Hex
  }:
    let
      ref = builtins.replaceString [":"] ["-"] reference;
      scope' = if scope != "" then scope + "-" else "";
      loTen = builtins.substring 0 10 loHash;
      ckTen = builtins.substring 0 10 checksum;
    in scope' + pname + "-" + ref + "-" + loTen + "-" + ckTen + ".zip";



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

  asGitFlakeUri = yspec:
    let
      matches =
        match "(.+)@https://github.com/(.*)\.git#(commit=)?(.*)" yspec;
      at          = builtins.elemAt matches;
      name        = builtins.head matches;
      repo        = at 1;
      maybeCommit = at 2;
      ref         = at 3;
    in "git@github:${repo}?ref=${ref}";

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

  inherit resolvesWithWorkspace asWorkspaceSpecifier getWorkspaceResolutions';
  inherit getWorkspaceResolutions;

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

/**
 * Creates a package ident.
 *
 * @param scope The package scope without the `@` prefix (eg. `types`)
 * @param name The name of the package
 *
export function makeIdent(scope: string | null, name: string): Ident {
  if (scope?.startsWith(`@`))
    throw new Error(`Invalid scope: don't prefix it with '@'`);

  return {identHash: hashUtils.makeHash<IdentHash>(scope, name), scope, name};
}

 **
 * Creates a package descriptor.
 *
 * @param ident The base ident (see `makeIdent`)
 * @param range The range to attach (eg. `^1.0.0`)
 *
export function makeDescriptor(ident: Ident, range: string): Descriptor {
  return {
    identHash: ident.identHash,
    scope: ident.scope,
    name: ident.name,
    descriptorHash: hashUtils.makeHash<DescriptorHash>(ident.identHash, range),
    range
  };
}

 **
 * Creates a package locator.
 *
 * @param ident The base ident (see `makeIdent`)
 * @param range The reference to attach (eg. `1.0.0`)
 *
export function makeLocator(ident: Ident, reference: string): Locator {
  return {
    identHash: ident.identHash,
    scope: ident.scope,
    name: ident.name,
    locatorHash: hashUtils.makeHash<LocatorHash>(ident.identHash, reference),
    reference
  };
}

*/
