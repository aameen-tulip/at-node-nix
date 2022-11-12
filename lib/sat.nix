# ============================================================================ #
#
# Satisfies me
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # FIXME: move to `libreg'
  getVersionInfo = {
    __functionMeta.name = "getVersionInfo";
    __functionMeta.from = "at-node-nix#lib.libsat";
    __functionMeta.doc  = "Fetch version details for package from registry";

    __functionArgs = {
      ident   = true;
      version = true;
      key     = true;
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
        ident   ? dirOf x.key
      , version ? baseNameOf x.key
      , key     ? "${ident}/${key}"
      }: { inherit ident version; };
      rough = if builtins.isAttrs x then x else fromString;
    in lib.canPassStrict self.__innerFunction ( self.__thunk // rough );

    __functor = self: x: let
      args = self.__processArgs self x;
    in self.__innerFunction args;
  };


# ---------------------------------------------------------------------------- #

  mkSatCond = depIdent: descriptor: let
    semverCond = let
      try = lib.librange.parseSemver descriptor;
    in if try == null then throw "Failed to parse descriptor: ${descriptor}"
                      else try;
  in {
    __functionMeta.name = "satisfiesSemver";
    __functionMeta.from = "at-node-nix#lib.libsat";
    ident = depIdent;
    __toString = self: "${self.ident}@${descriptor}";
    __innerFunction = {
      ident   ? dirOf args.key
    , version ? baseNameOf args.key
    , key     ? "${args.ident}/${args.version}"
    } @ args: ( ident == depIdent ) && ( semverCond version );
    __processArgs = self: x:
      if builtins.isString x then { key = x; } else
      lib.canPassStrict self.__innerFunction x;
    __functor  = self: x: let
      args = self.__processArgs self x;
    in self.__innerFunction args;
    passthru = { inherit semverCond descriptor; };
  };


# ---------------------------------------------------------------------------- #

  getDepSats = {
    __functionMeta.name = "getDepSats";
    __functionMeta.from = "at-node-nix#lib.libsat";
    __functionMeta.doc =
      "Create an attrset filter to select packages which satisfies dependency " +
      "descriptors of a given package.\n" +
      "Customize this routine by overriding `__lookupMeta', and by setting " +
      "`__thunk.{dev,optional,peer,registry}' fields.";

    __functionArgs = {
      registry = true;
      ident    = true;
      version  = true;
      key      = true;
    };

    __thunk.registry = "https://registry.npmjs.org";
    __thunk.dev      = true;
    __thunk.optional = true;
    __thunk.peer     = false;

    # Fetch package metadata to read dependency info from.
    # By default we query package registries, but in practice you will likely
    # replace this method with an alternative implementation which pulls info
    # from local projects or an existing `metaSet' blob.
    __lookupMeta = { registry }: x:
      ( getVersionInfo // { inherit registry; } ) x;

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

    # If you want to get at "the real" underlying conditionals they're stashed
    # in `.conds.<IDENT>.passthru.semverCond'.
    # Feel free to replace this subroutine with an unwrapped parser, just be
    # sure you also replace `__innerFunction' to reflect that change.
    __genSemverConds = builtins.mapAttrs mkSatCond;

    # This produces a functor that does "best effort"/"do what I mean"
    # application of a set of semver conditionals onto its arguments.
    # This functory is polymorphic and you'll want to peep at the implemenations
    # below to see what's avialable.
    #
    # If you feel like this routine is too complicated, wipe out
    # `__innerFuncion' to better suit your use case.
    #
    # One applied example uses the functor as a filter over keyed fields:
    #   lib.filterAttrs ( key: ent: ( getDepSats "bunyan" "1.8.15" ) key ) {
    #     "dtrace-provider/1.8.8"     = { ... };
    #     "dtrace-provider/0.8.8"     = { ... };
    #     "moment/2.29.4"             = { ... };
    #     "moment/3.0.1"              = { ... };
    #     "mv/2.1.1"                  = { ... };
    #     "safe-json-stringify/1.2.0" = { ... };
    #     "@foo/bar/4.2.0"            = { ... };
    #     ...
    #   }
    # ==> {
    #     "dtrace-provider/0.8.8"     = { ... };
    #     "moment/2.29.4"             = { ... };
    #     "mv/2.1.1"                  = { ... };
    #     "safe-json-stringify/1.2.0" = { ... };
    #   }
    #
    # Alternatively this would also work and would read info from entries
    # rather than the keys ( may trigger network fetches in impure mode ):
    #   lib.filterAttrs ( key: ent: ( getDepSats "bunyan" "1.8.15" ) ent ) ...
    __innerFunction = conds: let
      pp = lib.generators.toPretty { allowPrettyValues = true; };
    in {
      __functionMeta.name = "satSemverCondSet";
      __functionMeta.from = "at-node-nix.lib.libsat";
      __errMsg = self: kind: let
        loc = "${self.__functionMeta.from}.${self.__functionMeta.name}";
        kinds = builtins.mapAttrs ( _: msg: "(${loc}): ${msg}" ) {
          accessor = "out of ideas for reading key from value";
        };
      in kinds.${kind} or "(${loc}): ${kind}";
      inherit conds;
      # Read the example above, the arg processor in the conditionals is working
      # a bit of magic here.
      __forKey = self: x:
        builtins.any ( c: c x ) ( builtins.attrValues self.conds );
      # Implements the example above.
      __forAttrsByKey = self: lib.filterAttrs ( self.__forKey self );

      # TODO: there's several types of possible accessors here.
      # For example "filter a packument's sub-fields", or
      # "set true/false on entries of `{ <IDENT> = <VERSION> }'".
      # You might filter a list of version numbers keyed by ident.
      # Handle these accessors as you find the need for them, just try to keep
      # it organized.
      __forAttrsByIdent = self: x: let
        die = throw "${self.__errMsg self "accessor"} for value '${pp x}'";
        common  = builtins.intersectAttrs self.conds x;
        valType =
          builtins.typeOf ( builtins.head ( builtins.attrValues common ) );
        forString = ident: str: let
          key = if yt.PkgInfo.Strings.key.check str then str else
                "${ident}/${str}";
        in self.conds.${ident} key;
        # TODO: This is a really naive assumption and needs more cases for list
        forList = ident: xs:
          builtins.filter ( forString ident ) xs;
        forAttrs = ident: y:
          if y ? key then self.conds.${ident} y.key else
          if y ? version then self.conds.${ident} "${ident}/${y.version}" else
          if y ? __toString then forString ( toString y ) else
          die;
      in if common == {} then {} else
         if valType == "string" then builtins.mapAttrs forString common else
         if valType == "list" then builtins.mapAttrs forList common else
         if valType == "set" then builtins.mapAttrs forAttrs common else
         die;

      # FIXME: naive/unchecked assumptions about inner values.
      __processArgs = self: x: let
        die = throw "${self.__errMsg self "accessor"} for values '${pp x}'";
        forAttrs = let
          keys = builtins.attrNames x;
        in if keys == [] then {} else
           if yt.PkgInfo.Strings.key.check ( builtins.head keys )
           then self.__forAttrsByKey self
           else self.__forAttrsByIdent self;
      in if builtins.isList x then {
        inner = builtins.filter ( self.__forKey self );
        args  = x;
      } else if builtins.isAttrs then {
        inner = forAttrs;
        args  = x;
      } else die;

      __functor = self: x: let
        pargs = self.__processArgs self x;
      in pargs.inner pargs.args;
    };  # End `__innerFunction'

    __functor = self: x: let
      # Fetch package metadata with dependency info.
      meta = self.__lookupMeta {
        registry = x.registry or self.__thunk.registry;
      } x;
      # Scrape out dependencies.
      deps  = self.__collectDeps ( self.__thunk // meta );
      # Convert dependency info to semver conditionals.
      conds = self.__genSemverConds deps;
      # Merge conditionals into a single predicate which includes checking
      # of `ident'.
      # This predicate is intended for processing attrsets - see example above.
    in self.__innerFunction conds;
  };  # End `getDepSats'


# ---------------------------------------------------------------------------- #

  # A REPL session running SAT over registry pulls.
  # This process should become a `genericClosure' operator:

  # wants = lib.filterAttrs ( _: getDepSats "bunyan" "1.8.15" ) metaS.__entries;
  #
  # pulls = builtins.mapAttrs ( ident: versions:
  #   let latestV = lib.librange.latestRelease ( map baseNameOf versions );
  # in fp."${ident}/${latestV}" )
  # ( builtins.groupBy ( k: dirOf k ) ( builtins.attrNames wants ) );


# ---------------------------------------------------------------------------- #

  packumentClosureInit = getDepSats // {
    inherit (lib) packumenter;
    __thunk        = getDepSats.__thunk // { dev = false; };
    __functionArgs = { ident = true; version = true; key = true; };
    __processArgs  = self: x: let
      forAttrs = {
        key     ? null
      , ident   ? dirOf key
      , version ? if args ? key then baseNameOf key else "latest"
      } @ args: {
        packumenter = self.packumenter // {
          __thunk = self.packumenter.__thunk // {
            inherit (self.__thunk) registry;
          };
        };
        inherit ident version;
      };
    in if builtins.isAttrs x then forAttrs x else
       if lib.ytypes.PkgInfo.identifier.check x then forAttrs { ident = x; }
                                                else forAttrs { key = x; };
    __lookupMeta = { packumenter, ident, version }: let
      p = lib.packumenter ident;
    in {
      packumenter = p;
      versionInfo = p.packuments.${ident}.versions.${version};
    };

    __filterVersions = self: ident: cond: let
      versions   = self.packumenter.packuments.${ident}.versions;
      dropLatest = removeAttrs versions ["latest"];
      keys       = map ( v: "${ident}/${v}" ) ( builtins.attrNames dropLatest );
      satisfies    = map baseNameOf ( builtins.filter cond keys );
      latest     = lib.latestVersion satisfies;
    in {
      inherit ident satisfies latest;
      __toString = filtered: "${filtered.ident}/${filtered.latest}";
      passthru = {
        inherit cond;
        versionInfos = let
          proc = acc: v: acc // { ${v} = versions.${v}; };
        in builtins.foldl' proc { latest = versions.${latest}; } satisfies;
      };
    };

    __functor = self: x: let
      args  = self.__processArgs self x;
      meta  = self.__lookupMeta args;
      deps  = self.__collectDeps ( self.__thunk // meta.versionInfo );
      conds = self.__genSemverConds deps;
      final = self // {
        packumenter = builtins.foldl' ( p: p ) meta.packumenter
                                               ( builtins.attrNames deps );
      };
      sats  = builtins.mapAttrs ( self.__filterVersions final ) conds;
    in {
      key = "${args.ident}/${args.version}";
      inherit (args) ident version;
      inherit  sats;
      passthru = { inherit final conds; };
    };
  };


# ---------------------------------------------------------------------------- #

  packumentClosureOp = {
    key
  , ident
  , version
  , sats
  # Contains the "final" state of the `packumentClosure' env at the
  # end of the previous run ( Use this to recycle the `packumenter' cache ).
  # Also carries `conds', being the conditionals generated by the previous run,
  # this can be used to detect if we can "follow" an ancestor's resolution.
  , passthru
  } @ prev: let
    mergePackumenters = a: b:
      a // { packuments = a.packuments // b.packuments; };
    mergeConds = a: b: a // b;  # FIXME
    proc = { passthru, runs }: satisfied: let
      key = toString satisfied;
      n   = passthru.final key;
    in {
      runs  = runs ++ [n];
      passthru = n.passthru // {
        # FIXME: handle "follows"
        conds = mergeConds passthru.conds n.passthru.conds;
        final = n.passthru.final // {
          packumenter =
            mergePackumenters prev.passthru.final.packumenter.packuments
                              n.passthru.final.packumenter;
        };
      };
    };
    nexts = builtins.foldl' proc {
      inherit passthru;
      runs = [prev];
    } ( builtins.attrValues sats );
    updateAllPackumenters = { passthru, ... } @ run: run // {
      passthru = passthru // {
        final = passthru.final // {
          inherit (nexts.passthru.final) packumenter;
        };
      };
    };
  in map updateAllPackumenters nexts.runs;



# ---------------------------------------------------------------------------- #

  packumentSemverClosure = {
    __functionMeta.name = "packumentSemverClosure";
    __functionMeta.from = "at-node-nix#lib.libsat";
    __functionArgs = packumentClosureInit.__functionArgs // {
      startSet = true;
    };
    __innerFunction = startSet: assert builtins.isList startSet;
      builtins.genericClosure {
        inherit startSet;
        operator = packumentClosureOp;
      };

    __mergePackumenterCaches = close: let
      proc = p: { passthru, ... }: p // {
        packuments = p.packuments // passthru.final.packumenter.packuments;
      };
      init = ( builtins.head close ).passthru.final.packumenter;
      merged = builtins.foldl' proc init ( builtins.tail close );
    in if ( builtins.length close ) <= 1 then init else merged;

    # NOTE: `conds' are reachable from `<ENT>.sats.<IDENT>.passthru.cond'
    __cleanEntry = {
      key
    , ident
    , version
    , sats
    , passthru  # dropped `{ final, conds }'
    } @ ent: {
      inherit key ident version sats;
      __serial = self: {
        inherit (self) ident version;
        sats = builtins.mapAttrs ( key: sat: {
          inherit (sat.passthru.cond.passthru) descriptor;
          inherit (sat) satisfies;
        } ) self.sats;
      };
    };

    __isFlat = close: let
      proc = idents: { ident, ... }:
        if ( idents == false ) || ( idents ? ${ident} ) then false else
        idents // { ${ident} = null; };
      check = builtins.foldl' proc {} close;
    in check != false;

    __functor = self: x: let
      startSet    = x.startSet or [( packumentClosureInit x )];
      close       = self.__innerFunction startSet;
      packumenter = self.__mergePackumenterCaches close;
      clean       = map self.__cleanEntry close;
      packages    = lib.listToAttrsBy "key" clean;
    in {
      inherit packages;
      roots    = map ( e: e.key ) startSet;
      isFlat   = self.__isFlat close;
      passthru = { inherit packumenter startSet; };
      __serial = self: {
        inherit (self) roots isFlat;
        packages = builtins.mapAttrs ( _: p: p.__serial p ) self.packages;
      };
    };
  };


# ---------------------------------------------------------------------------- #

  # Run a packument closure and strip the full output down to values which
  # can be written to JSON.
  # In practice this is usually the function you'll want to call when scraping
  # meta-data for a project as opposed to the full routine above.
  #
  #   packumentSemverClosureSerial { ident = "bunyan"; version = "1.8.15"; }
  #   ==>
  #   {
  #     isFlat   = true;  # true every package resolves to exactly one version.
  #     roots    = ["bunyan/1.8.15"];
  #     packages = {
  #       "glob/6.0.4" = {  # the "resolved" version's key
  #         ident = "glob"; version = "6.0.4";
  #         sats = {  # dependency resolution info.
  #           inflight = {
  #             descriptor = "^1.0.4";
  #             satisfies = ["1.0.4" "1.0.5" "1.0.6"];  # all usable versions.
  #           };
  #           inherits  = { ... };
  #           minimatch = { ... };
  #           ...
  #         };
  #       };
  #       "bunyan/1.8.15"    = { ... };
  #       "concat-map/0.0.1" = { ... };
  #       ...
  #     };
  #   }
  #
  packumentSemverClosureSerial = {
    inherit (packumentSemverClosure) __functionArgs;
    __innerFunction = packumentSemverClosure;
    __functor = self: x: let
      close = packumentSemverClosure x;
    in close.__serial close;
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    getVersionInfo
    mkSatCond
    getDepSats
    packumentClosureInit
    packumentClosureOp
    packumentSemverClosure
    packumentSemverClosureSerial
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
