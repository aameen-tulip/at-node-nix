# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;
  inherit (yt) struct string list attrs option;

# ---------------------------------------------------------------------------- #

  version = string;
  ident   = string;

  repository = yt.either string ( struct "repository" {
    type      = option string;  # FIXME: enum ["git"];
    url       = string;
    directory = option string;  # FIXME
    web       = option string;
    dist      = option string;
  } );

  timestamp = string;           # "2019-08-08T17:52:35.249Z"
  time      = attrs timestamp;  # <VERSION>: <TIMESTAMP>

  # FIXME:
  manifest = attrs yt.any;


# ---------------------------------------------------------------------------- #

  defContact = name: yt.either string ( struct name {
    name  = option string;
    email = option string;
    url   = option string;
    githubUsername = option string;
  } );

  author      = defContact "author";
  bugs        = defContact "bugs";
  maintainer  = defContact "maintainer";
  contributor = defContact "contributor";


# ---------------------------------------------------------------------------- #

  packument = struct "packument" {
    _id            = ident;
    _rev           = option string;
    author         = option author;
    bugs           = option bugs;
    contributors   = option ( yt.either string ( list contributor ) );
    description    = option string;
    dist-tags      = attrs version;
    homepage       = option string;
    keywords       = option ( list string );
    license        = option string;
    maintainers    = list maintainer;
    name           = string;
    # falls back to error string
    readme         = string;
    readmeFilename = option string;
    repository     = option repository;
    time           = time;
    # <USERNAME>: true  ( always true )
    users          = option ( attrs yt.bool );
    # XXX: I haven't confirmed if this is "full"
    versions       = manifest;
  };


# ---------------------------------------------------------------------------- #



# ---------------------------------------------------------------------------- #

in {
  inherit packument;
}

# ---------------------------------------------------------------------------- #
#
#  * Counted 1991 `registry.npmjs.org' `Packuments for occurence of fields.
#    {
#      _id = 1991;
#      _rev = 1984;            ***
#      author = 1471;          ***
#      bugs = 1714;            ***
#      contributors = 406;     ***
#      description = 1920;     ***
#      dist-tags = 1991;
#      homepage = 1907;        ***
#      keywords = 1415;        ***
#      license = 1971;         ***
#      maintainers = 1991;
#      name = 1991;
#      readme = 1991;
#      readmeFilename = 1984;  ***
#      repository = 1977;      ***
#      time = 1991;
#      users = 1077;           ***
#      versions = 1991;
#    }
#
#
# ---------------------------------------------------------------------------- #
#
#  * Types
#    {
#      _id = "string";
#      _rev = "string";
#      author = "set";
#      bugs = "set";
#      description = "string";
#      dist-tags = "set";
#      homepage = "string";
#      keywords = "list";
#      license = "string";
#      maintainers = "list";
#      name = "string";
#      readme = "string";
#      readmeFilename = "string";
#      repository = "set";
#      time = "set";
#      versions = "set";
#    }
#
#
# ---------------------------------------------------------------------------- #
#
# * Manifest Summary Example ( NOTE: not the same as a full manifest )
#
#   {
#     _hasShrinkwrap = false;
#     _id = "@ampproject/remapping@2.2.0";
#     _nodeVersion = "16.14.0";
#     _npmOperationalInternal = {
#       host = "s3://npm-registry-packages";
#       tmp = "tmp/remapping_2.2.0_1651031472899_0.12018851986441148";
#     };
#     _npmUser = {
#       email = "justin+npm@ridgewell.name";
#       name = "jridgewell";
#     };
#     _npmVersion = "8.7.0";
#     author = {
#       email = "jridgewell@google.com";
#       name = "Justin Ridgewell";
#     };
#     bugs = {
#       url = "https://github.com/ampproject/remapping/issues";
#     };
#     dependencies = {
#       "@jridgewell/gen-mapping" = "^0.1.0";
#       "@jridgewell/trace-mapping" = "^0.3.9";
#     };
#     description = "Remap sequential sourcemaps through transformations to point at the original source code";
#     devDependencies = {
#       "@rollup/plugin-typescript" = "8.3.2";
#       "@types/jest" = "27.4.1";
#       "@typescript-eslint/eslint-plugin" = "5.20.0";
#       "@typescript-eslint/parser" = "5.20.0";
#       eslint = "8.14.0";
#       eslint-config-prettier = "8.5.0";
#       jest = "27.5.1";
#       jest-config = "27.5.1";
#       npm-run-all = "4.1.5";
#       prettier = "2.6.2";
#       rollup = "2.70.2";
#       ts-jest = "27.1.4";
#       tslib = "2.4.0";
#       typescript = "4.6.3";
#     };
#     directories = { };
#     dist = {
#       fileCount = 12;
#       integrity = "sha512-qRmjj8nj9qmLTQXXmaR1cck3UXSRMPrbsLJAasZpF+t3riI71BXed5ebIOYwQntykeZuhjsdweEc9BxH5Jc26w==";
#       npm-signature = ''
#         -----BEGIN PGP SIGNATURE-----
#         <SNIP>
#         -----END PGP SIGNATURE-----
#       '';
#       shasum = "56c133824780de3174aed5ab6834f3026790154d";
#       signatures = [
#         {
#           keyid = "SHA256:jl3bwswu80PjjokCgh0o2w5c2U4LhQAE57gj9cz1kzA";
#           sig = "MEUCIQCUcSzEGqbqUBYd8Cucxu4adcKWXxnI5PPCg7O89NEMBwIgJDj78jDKef0MTLAWh8NyfJ3dBxUJuwmVEHZH+esBP/4=";
#         }
#       ];
#       tarball = "https://registry.npmjs.org/@ampproject/remapping/-/remapping-2.2.0.tgz";
#       unpackedSize = 55316;
#     };
#     engines = {
#       node = ">=6.0.0";
#     };
#     gitHead = "ee9a0b022cb8f739ae36bd39a2ca4bfdf1d859c1";
#     homepage = "https://github.com/ampproject/remapping#readme";
#     keywords = [
#       "source"
#       "map"
#       "remap"
#     ];
#     license = "Apache-2.0";
#     main = "dist/remapping.umd.js";
#     maintainers = [
#       {
#         email = "admin@ampproject.org";
#         name = "ampproject-admin";
#       }
#       ...
#       <SNIP>
#     ];
#     module = "dist/remapping.mjs";
#     name = "@ampproject/remapping";
#     repository = {
#       type = "git";
#       url = "git+https://github.com/ampproject/remapping.git";
#     };
#     scripts = {
#       build = "run-s -n build:*";
#       "build:rollup" = "rollup -c rollup.config.js";
#       "build:ts" = "tsc --project tsconfig.build.json";
#       lint = "run-s -n lint:*";
#       "lint:prettier" = "npm run test:lint:prettier -- --write";
#       "lint:ts" = "npm run test:lint:ts -- --fix";
#       prebuild = "rm -rf dist";
#       prepublishOnly = "npm run preversion";
#       preversion = "run-s test build";
#       test = "run-s -n test:lint test:only";
#       "test:debug" = "node --inspect-brk node_modules/.bin/jest --runInBand";
#       "test:lint" = "run-s -n test:lint:*";
#       "test:lint:prettier" = "prettier --check '{src,test}/**/*.ts'";
#       "test:lint:ts" = "eslint '{src,test}/**/*.ts'";
#       "test:only" = "jest --coverage";
#       "test:watch" = "jest --coverage --watch";
#     };
#     typings = "dist/types/remapping.d.ts";
#     version = "2.2.0";
#   }
#
#
# ---------------------------------------------------------------------------- #
#
# * Users Example
#
#   {
#     users = {
#       antixrist = true;
#       axelav = true;
#       bsdprojects = true;
#       evanlovely = true;
#       huiyifyj = true;
#       julien-f = true;
#       "programmer.severson" = true;
#       tg-z = true;
#     };
#   }
#
#
# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
