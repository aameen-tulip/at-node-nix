# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # FIXME: move to `libreg'
  getVersionInfo = {
    __functionMeta.name = "getVersionInfo";
    __functionMeta.from = "at-node-nix#lib";
    __functionMeta.doc = "Fetch version details for package from registry";

    __functionArgs = {
      ident = true;
      version = true;
      key = true;
    };

    __thunk.registry = "https://registry.npmjs.org";

    __innerFunction = { ident, version, registry }:
      lib.libreg.importCleanManifest registry ident version;

    __processArgs = self: x: let
      curryVersion = version: { ident = x; inherit version; };
      descKeyPatt = "((@[^@/]+/)?[^@/]+)[@/]([0-9]+\\.[0-9]+\\.[0-9]+(-.*)?)";
      descKeyMatch = builtins.match descKeyPatt x;
      fromString = assert builtins.isString x;
        if lib.ytypes.PkgInfo.identifier.check x then curryVersion else
        if descKeyMatch != null then {
          ident   = builtins.head descKeyMatch;
          version = builtins.elemAt descKeyMatch 2;
        } else throw "Invalid package locator: ${x}";
      procAttrs = {
        ident ? dirOf x.key
      , version ? baseNameOf x.key
      , key ? "${ident}/${key}"
      }: { inherit ident version; };
      rough = if builtins.isAttrs x then x else fromString;
    in lib.canPassStrict self.__innerFunction ( self.__thunk // rough );

    __functor = self: x: let
      args = self.__processArgs self x;
    in self.__innerFunction args;
  };


# ---------------------------------------------------------------------------- #

  mkSatCond = depIdent: descriptor: let
    semverCond = lib.librange.parseSemverStatement descriptor;
  in {
    __functionMeta.name = "satisfySemver";
    __functionMeta.from = "at-node-nix#lib.libsat";
    ident = depIdent;
    __processArgs = self: x:
      if builtins.isString x then { key = x; } else
      lib.canPassStrict self.__innerFunction x;
    __innerFunction = {
      ident      ? dirOf args.key
    , version    ? baseNameOf args.key
    , key        ? "${args.ident}/${args.version}"
    } @ args: ( ident == depIdent ) && ( semverCond version );
    __toString = self: "${self.ident}@${descriptor}";
    __functor  = self: x: let
      args = self.__processArgs self x;
    in self.__innerFunction args;
    passthru = { inherit descriptor; };
  };


# ---------------------------------------------------------------------------- #

  getDepSats = {
    __functionMeta.name = "getDepSats";
    __functionMeta.from = "at-node-nix#lib";
    __functionMeta.doc =
      "Fetch dependency sat conditionals for package from registry";

    __functionArgs = {
      ident = true;
      version = true;
      key = true;
    };

    __thunk.registry = "https://registry.npmjs.org";
    __thunk.dev      = true;
    __thunk.optional = true;
    __thunk.peer     = false;

    __collectDeps = {
      dependencies         ? {}
    , devDependencies      ? {}
    , optionalDependencies ? {}
    , peerDependencies     ? {}
    , dev
    , optional
    , peer
    , ...
    }: dependencies //
       ( lib.optionalAttrs dev devDependencies ) //
       ( lib.optionalAttrs optional optionalDependencies ) //
       ( lib.optionalAttrs peer peerDependencies );

    __genSemverConds = builtins.mapAttrs mkSatCond;

    # Intended for use as a filter as:
    #   lib.filterAttrs ( key: _: ( getDepSats "lodash" "4.x" ) ) {
    #     "@foo/bar/4.2.0" = ...;
    #     "lodash/4.17.21" = ...;
    #     ...
    #   };
    # ==> { "lodash/4.17.21" = ...; }
    __innerFunction = conds: x:
      builtins.any ( c: c x ) ( builtins.attrValues conds );

    __functor = self: x: let
      vinfo = ( getVersionInfo // { inherit (self.__thunk) registry; } ) x;
      deps  = self.__collectDeps ( self.__thunk // vinfo );
      conds = self.__genSemverConds deps;
    in self.__innerFunction conds;

  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    getVersionInfo
    mkSatCond
    getDepSats
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #