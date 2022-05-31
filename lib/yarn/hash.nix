rec {
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


/* -------------------------------------------------------------------------- */

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


/* -------------------------------------------------------------------------- */

}


/* --------------------------------------------------------------------------- *

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
