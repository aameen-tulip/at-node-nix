/**
 * There's a ton of old `dO-a-TuRbAlL.nix' files already.
 * This is going to take the cream of the crop, and then
 * the old ones will be deleted.
 */
{ lib, linkToPath, linkFarm, untar, pacotecli, /* tar, */ ... }: let

  inherit (lib.libpkginfo) readPkgInfo;
  inherit (builtins) mapAttrs attrValues attrNames filter;

  # FIXME: This needs to get split up.
  # The processes here are good; but "as is" these routines lack a clear way
  # to integrate packages that have an `npm (pre|post)install' or build routine.
  #
  # Additionally, the handling for the `tarball' output isn't friendly to
  # flakes or raw source directories.
  # The `tarball' output could be created from a raw source tree, but it's a bit
  # redundant since we'll never actually reference it.
  # Plus you'll want to make a clear distinction about those tarballs to ensure
  # that they align with the norms of the NPM registry - so ensure that they
  # don't run an `install' script if they're a Git or local tree.
  #
  # In any case, as stated above, this file isn't set up very well to build
  # anyway, because there isn't a clear way for anyone to pass in dependencies,
  # and we aren't going to fetch them here.
  #
  # "As is" these routines are perfect for processing NPM registry tarballs
  # which lack an `npm install' routine.


/* -------------------------------------------------------------------------- */

  # derivation types and passthru attrs
  #   tarball     registry style tarball.
  #   unpacked    *built* tree ready for consumption.
  #   bindir      linked bindir ( only when `package.json' has `bins' field ).
  #   module      `node_modules/' style tree, including `.bin/' if any.
  #   global      global style tree, including `bin/' if any'.


/* -------------------------------------------------------------------------- */

  # FIXME: This doesn't match `pacote'.
  # For the time being - use `pacote tarball <path>' to create tarballs.
  #
  # Pack a tarball from a directory without attempting to build.
  # Tarball will be named using the NPM registry style, being
  # "${pname}-${version}.tgz" without a scope prefix.
  # FIXME: This is an ideal place to add `pkgInfo' as `meta'.
  # FIXME: Read `files' and ignores hints from `package.json'.
  packNodeTarballAsIs = {
    src
  , pjs  ? readPkgInfo src
  , name ? pjs.registryTarballName
  }: let
    #tarball  = tar {
    #  inherit name;
    #  tarFlagsLate = [
    #    "-C" src.outPath
    #    "--transform=s,^\./,package/,"
    #    "--warning=no-unknown-keyword"
    #    "--delay-directory-restore"
    #  ];
    #  src = ".";
    #};
    tarball = pacotecli "tarball" {
      dest = name;
      spec = toString src;
    };
    meta = ( src.meta or {} ) // {
      inherit (pjs) version;
      inherit pjs;
      # FIXME: You're note scraping the `manifest' data.
      # SHA512 is the one you may need.
      # Other manifest data contains store paths, so it would belong
      # in passthru.
      manifest = { integrity = ""; };
    };
    passthru = { inherit src tarball; } // ( tarball.passthru or {} );
  in tarball // { inherit meta passthru; };


/* -------------------------------------------------------------------------- */

  # XXX: This expects that the tarball is a `package/{package.json,...}' tarball
  # You shouldn't
  unpackNodeTarball = { tarball }: let
    unpacked = untar {
      inherit tarball;
      tarFlagsLate = ["--strip-components=1"];
    };
    importedPjs = readPkgInfo "${unpacked}/package.json";
    pjs         = tarball.meta.pjs or importedPjs;
    meta        = ( tarball.meta or {} ) // { inherit pjs; };
    passthru    = { inherit tarball unpacked; } // ( tarball.passthru or {} );
  in unpacked // { inherit meta passthru; };


/* -------------------------------------------------------------------------- */

  # This form does not link `.bin/'
  linkAsNodeModule' = { unpacked, name ? unpacked.name + "-module-strict" }:
    linkToPath { inherit name; src = unpacked; to = unpacked.meta.pjs.name; };


/* -------------------------------------------------------------------------- */

  binEntries = to: unpacked:
    assert lib.libpkginfo.pkgJsonHasBin unpacked.meta.pjs;
    # XXX: this assertion was causing IFD.
    #assert builtins.pathExists "${unpacked}/package.json"; let
    let
      entries = lib.mapAttrsToList ( n: p: {
        name = "${to}/${n}"; path = "${unpacked}/${p}";
      } ) unpacked.meta.pjs.bin;
    in entries;


/* -------------------------------------------------------------------------- */

  # XXX: These are not patched.
  # AGAIN: These have not bee processed by `patchShebangs'
  #
  # By default we link to regular `bin/' for the convenience of making tools.
  # Setting `to = "";' will give put them in the root of the output.
  linkBins = { src, name ? src.name + "-bindir", to ? "bin" }: let
    inherit (src.meta) pjs;
    unpacked' = src.passthru.unpacked or src;
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked'}/package.json"; } //
             ( unpacked'.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked' // { inherit meta passthru; };
    unpacked = if unpacked' ? meta.pjs then unpacked' else withMetaPass;
    bindir = linkFarm name ( binEntries to unpacked );
    passthru = { inherit unpacked bindir; } // ( src.passthru or {} );
  in bindir // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # This links `.bin/' "hidden" in the `node_modules' folder.
  linkAsNodeModule = { unpacked, name ? unpacked.name + "-module" }: let
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked}/package.json"; } //
             ( unpacked.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked // { inherit meta passthru; };
    unpacked' = if unpacked ? meta.pjs then unpacked else withMetaPass;
    linked = linkFarm name ( ( binEntries ".bin" unpacked' ) ++ [
      { name = unpacked'.meta.pjs.name; path = unpacked'.outPath; }
    ] );
    bindir = if lib.libpkginfo.pkgJsonHasBin ( unpacked.meta.pjs or unpacked'.meta.pjs ) then
      "${linked}/.bin" else null;
    module = if bindir != null then linked else linkAsNodeModule' {
      unpacked = unpacked';
    };
    passthru = {
      inherit module;
      unpacked = unpacked';
    } // ( unpacked'.passthru or {} ) // ( if bindir == null then {} else {
      inherit bindir;
    } );
  in module // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # This links `.bin/' "hidden" in the `node_modules' folder.
  linkAsGlobal = { unpacked, name ? unpacked.name + "-global" }: let
    withMetaPass = let
      meta = { pjs = readPkgInfo "${unpacked}/package.json"; } //
             ( unpacked.meta or {} );
      passthru = { unpacked = unpacked'; } // ( unpacked.passthru or {} );
    in unpacked // { inherit meta passthru; };
    unpacked' = if unpacked ? meta.pjs then unpacked else withMetaPass;
    linked = linkFarm name ( ( binEntries "bin" unpacked' ) ++ [
      {
        name = "lib/node_modules/" + unpacked'.meta.pjs.name;
        path = unpacked'.outPath;
      }
    ] );
    bindir = if lib.libpkginfo.pkgJsonHasBin unpacked'.meta.pjs then
      "${linked}/bin" else null;
    global = if bindir != null then linked else linkAsNodeModule' {
      unpacked = unpacked';
    };
    passthru = {
      inherit global;
      unpacked = unpacked';
    } // ( unpacked'.passthru or {} ) // ( if bindir == null then {} else {
      inherit bindir;
    } );
  in global // { inherit passthru; };


/* -------------------------------------------------------------------------- */

  # NOTE: Replaced with function below which consolidates the functions above
  #       to share several intermediate values, and sync passthru fields.
  #mkNodeTarball = src: let
  #  # FIXME: You really need to build
  #  tarball  = packNodeTarballAsIs { inherit src; };
  #  unpacked = unpackNodeTarball { inherit tarball; };
  #in {
  #  inherit tarball unpacked;
  #  module = linkAsNodeModule { inherit unpacked; };
  #  global = linkAsGlobal { inherit unpacked; };
  #};


/* -------------------------------------------------------------------------- */

  # `src' may be an unpacked tree with meta/passthru, a "raw" source tree from
  # a builtin fetcher, or a derivation of `nixpkgs.fetchurl' which needs to
  # be unpacked here.
  #
  # Outputs: `tarball', `unpacked', `bindir', `module', `global', and `_src'.
  #
  # The `passthru' will be synchronized forall outputs; and the `meta.pjs' will
  # /mostly/ align - but certain `scripts' may be removed intentionally to
  # prevent `npm' from attempting to rerun things like `prepare' or `rebuild'.
  #
  # The `_src' field is the original input; this is equivalent to `__unfix__'
  # but renamed because nobody is going to know what the fuck `__unfix__' means.
  mkNodeTarball = src: let
    meta' = src.meta or {};
    passthru' = src.passthru or {};
    #pjs' = meta'.pjs or ( readPkgInfo "${toString unpacked'}/package.json" );
    pjs' = meta'.pjs or ( lib.libpkginfo.pkgJsonFromPath unpacked' );

    # builtins.fetchTree    --> { narHash, outPath }                :: attrs
    # builtins.fetchurl     --> "/nix/store/XXXX-name-version.tgz"  :: swc
    # builtins.fetchTarball --> "/nix/store/XXXX-source"            :: swc
    # builtins.path         --> "/nix/store/XXXX-dir-name"          :: swc
    # pkgs.fetchurl         --> <derivation /nix/store/XXXX-*.tgz>  :: drv
    # pkgs.fetchTarball     --> <derivation /nix/store/XXXX-source> :: drv
    #
    # In the case of "string with context ( swc )" or derivations, use
    # `toString' and check the name for a `.tgz' suffix,
    # or use `builtins.pathExists "${src}/package.json"'
    #
    # For our purposes, we care about "${source}/package.json" working
    srcIsDir = builtins.pathExists "${src}/package.json";

    tarball' = passthru'.tarball or ( if ( ! srcIsDir ) then src else {
      type = "path";
      # FIXME: built and zip
      outPath = throw ''"Filth is my politics! Filth is my life!" - B.J.'';
    } );

    unpacked' = passthru'.unpacked or ( if srcIsDir then src else ( untar {
      tarball = tarball';
      tarFlagsLate = ["--strip-components=1"];
    } ) );

    toPathStr = x: if builtins.isAttrs x then toString x else lib.coercePath x;

    mkBin = to: let
      ftPair = n: p: {
        name = "${to}/${n}";
        path = "${toPathStr unpacked'}/${p}";
      };
      binAttr = pjs'.bin or {};
      bins =
        if builtins.isAttrs binAttr then lib.mapAttrsToList ftPair binAttr else
        if builtins.isString binAttr then [{  # Single bin, adopt package name.
          name = "${to}/${baseNameOf ( pjs'.name )}";
          path = "${toPathStr unpacked'}/${binAttr}";
        }] else builtins.trace
          "Unrecognized bin attr type: ${builtins.typeOf binAttr}" [];
    in bins;

    bindir' = linkFarm "${baseNameOf pjs'.name}-bindir" ( mkBin "bin" );

    # FIXME: This needs to get "built"
    module' = let
      nmdir = [{ inherit (pjs') name; path = toPathStr unpacked'; }];
    in linkFarm "${baseNameOf pjs'.name}-module" ( ( mkBin ".bin" ) ++ nmdir );

    # FIXME: This needs to get "built"
    global' = linkFarm "${baseNameOf pjs'.name}" ( ( mkBin "bin" ) ++ [{
      name = "lib/node_modules/${pjs'.name}";
      path = toPathStr unpacked';
    }] );

    # FIXME: once you've got build phases being processed, drop `pjs' scripts
    # where appropriate.
    # For now, use the same `meta' for everything.
    metaFor = drv: { pjs = pjs'; } // meta' // ( drv.meta or {} );
    asSet = x: if builtins.isAttrs x then x else {
      type = if srcIsDir then "path" else "tarball";
      path = x;
    };

    tarball_  = ( asSet tarball' )  // { meta = metaFor tarball'; };
    unpacked_ = ( asSet unpacked' ) // { meta = metaFor unpacked'; };
    bindir_   = bindir'             // { meta = metaFor bindir'; };
    module_   = module'             // { meta = metaFor module'; };
    global_   = global'             // { meta = metaFor global'; };

    fPassthru = self: {
      tarball = tarball_ // ( passthru' // { passthru = {
        inherit (self) unpacked bindir module global;
      }; } );
      unpacked = unpacked_ // ( passthru' // { passthru = {
        inherit (self) tarball bindir module global;
      }; } );
      bindir = bindir_ // ( passthru' // { passthru = {
        inherit (self) tarball unpacked module global;
      }; } );
      module = module_ // ( passthru' // { passthru = {
        inherit (self) tarball unpacked bindir global;
      }; } );
      global = global_ // ( passthru' // { passthru = {
        inherit (self) tarball unpacked bindir module;
      }; } );
    };
  in lib.fix fPassthru;


/* -------------------------------------------------------------------------- */

in {
  inherit
    packNodeTarballAsIs  # FIXME: see note at top
    unpackNodeTarball
    linkAsNodeModule'
    linkAsNodeModule
    linkBins
    linkAsGlobal
    mkNodeTarball
  ;
}
