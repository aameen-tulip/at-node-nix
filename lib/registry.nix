# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim;

# ---------------------------------------------------------------------------- #

  # Given a scope, return the registry URL we should use.
  # Uses thunked dictionary to map scopes to registries. 
  _registryForScope = {
    scope          ? meta.scope or ( lib.yank "@([^/]+)" ( dirOf ident ) )
  , ident          ? meta.ident or name
  , name           ? meta.name  or ( dirOf key )
  , key            ? meta.key
  , meta           ? {}
  , registryScopes ? { _default = lib.getDefaultRegistry; }
  , ...
  } @ args: let
    stripped = lib.yank "@?([^/]+)/?" scope;
    sc = if ( scope == "." ) || ( scope == null ) then "_default" else stripped;
  in registryScopes.${sc} or registryScopes._default;

  # See `tests/libreg/tests.nix' for more examples.
  registryForScope = {
    __functionMeta = {
      argTypes     = yt.either yt.string ( yt.attrs yt.any );
      open         = true;
      terminalArgs = { scope = yt.string; };
      thunkMembers = { registryScopes = yt.attrs yt.string; };
      keywords = [
        "functor" "configured" "thunk" "polymorphic" "wrapper"
        "registry" "scope"
      ];
      doc = ''
  registryForScope :: (String:<key|ident|scope> | Attrs) -> String

  Ex:  registryForScope "foo"                                  ==> "https://registry.npmjs.org"
  Ex:  registryForScope { ident = "@foo/bar"; }                ==> "https://registry.npmjs.org"

  Recommended Attr Args: { scope, registryScopes }
  Fallback Attr Args:    { scope <- ident|name|key|meta, registryScopes }  ;;  `meta' may provide (ident|name|key) fallbacks

  You may also set `__thunk.registryScopes' to specialize this functor to use alternate scope settings.

  When a string argument is passed, the default registry scope list is used, and the string is parsed using `lib.libpkginfo.normalizePkgScope'.
  NOTE: this means that passing "@foo/bar" OR "foo" uses "foo" as the scope - which might not be what you expect.

  KEYWORDS: functor, configured, thunk, polymorphic, registry, scope
'';
    };
    __functor = self: arg:
      self.__innerFunction ( self.__processArgs self arg );
    __functionArgs = ( lib.functionArgs _registryForScope ) // {
      name = true;
      key  = true;
    };

    __processArgs = self: x: let
      scopeFromString =
        if ! ( lib.libpkginfo.Scope.isCoercible x ) then { scope = null; }
        else { inherit (lib.libpkginfo.Scope.fromString x) scope; };
      arg = if builtins.isString x then scopeFromString else
      if builtins.isAttrs x then x else
      if x == null then { scope = null; } else
      throw "registryForScope: x must be a string (scope) or attrset";
    in self.__thunk // arg;

    __thunk.registryScopes._default = lib.getDefaultRegistry;
    __innerFunction = _registryForScope;
  };

# ---------------------------------------------------------------------------- #

  # Fetch a packument from the registry.
  # String string contexts to ensure that the fetched result doesn't root its
  # hash from any arguments.
  # NOTE: I honestly don't know if it would do this, but I'm not going to dig
  #       through the Nix source code to find out right now.
  _fetchPackument = { registry, ident, ... }: let
    url = builtins.unsafeDiscardStringContext "${registry}/${ident}";
  in builtins.readFile ( builtins.fetchTree { inherit url; type = "file"; } );

  fetchPackument = {
    __functionMeta = {
      argTypes     = yt.either yt.string ( yt.attrs yt.any );
      open         = true;
      terminalArgs = { registry = yt.string; ident = yt.string; };
      thunkMembers = { registryScopes = yt.attrs yt.string; };
    };
    __functor = self: arg:
      self.__innerFunction ( self.__processArgs self arg );
    __functionArgs = {
      registryScopes = true;
      registry       = true;
      name           = true;
      ident          = true;
      meta           = true;
      key            = true;
    };
    __thunk.registryScopes._default = lib.getDefaultRegistry;
    __processArgs = self: arg: let
      regArgs = if builtins.isAttrs arg then self.__thunk // arg else
        self.__thunk // {
          scope = lib.yank "@([^/]+).*" arg;
          ident = lib.yank "((@[^@/]+/)?[^@/]+).*" arg;
        };
      registry = registryForScope regArgs;
      ident =
        regArgs.ident or regArgs.meta.ident or regArgs.name or regArgs.meta.name
        or ( dirOf ( regArgs.key or regArgs.meta.key ) );
    in { inherit ident registry; } // regArgs;
    __innerFunction = _fetchPackument;
  };

  # Tail calls `builtins.fromJSON' after fetching.
  importFetchPackument = fetchPackument // {
    __cleanVersionInfo = normalizeVInfo;
    __functor = self: arg: let
      wrapFP = fetchPackument // { inherit (self) __thunk; };
      json   = builtins.fromJSON ( wrapFP arg );
    in json // {
      versions = builtins.mapAttrs ( _: self.__cleanVersionInfo ) json.versions;
    };
  };


# ---------------------------------------------------------------------------- #

  addPackumentExtras = packument: let
    nid' = lib.libparse.parseIdent packument._id;
    scopeDir = if ( nid'.scope != null ) then "@${nid'.scope}/" else "";
    nid = nid' // { inherit scopeDir; };
    addNiVers = vers: val: val // nid // { reference = vers; };
    addTarInfoVers = val: let
      fetchTarballArgs = ( { tarball, integrity ? "", shasum ? "", ... }: {
        url  = tarball;
        hash = integrity;
        sha1 = shasum;
      } ) val.dist;
      fetchWith = {
        fetchurl ? ( { url, ... }: builtins.fetchTree {
          inherit url; type = "file";
        } )
      }: builtins.fetchurl fetchTarballArgs;
    in val // {
      inherit fetchTarballArgs fetchWith;
      inherit (val.dist) tarball;
    };
    addAllDeps = val: val // {
      allDependencies = lib.libpkginfo.allDependencies val;
    };
    # FIXME:
    versions = builtins.mapAttrs addNiVers ( packument.versions or {} );
    packument' = packument // nid // { inherit versions; };
    latest = packumentLatestVersion' packument';
  in packument' // {
    latest = if versions != {} then latest else null;
    versions = packument'.versions // { inherit latest; };
  };


# ---------------------------------------------------------------------------- #

  # Determine the latest version of a package from its packument info.
  # First we check for `.dist-tags.latest' for a version number, otherwise we
  # use the last element of the list.
  # Nix sorts keys such that the highest version number will be last.
  packumentLatestVersion' = packument: let
    vlist = builtins.attrValues packument.versions;
    len   = builtins.length vlist;
    last  = builtins.elemAt vlist ( len -1 );
    maybeLast = if 0 < len then last else
                throw "Package ${packument._id} lacks a version list";
    # NOTE: this list is already sorted by the registry
    lver  = packument.dist-tags.latest or maybeLast;
  in packument.versions.${lver};

  # Return the latest `<packument>.versions' member if one exists.
  # Accepts either a packument, or args accepted by `fetchPackument' in which
  # case it will perform a fetch.
  # "Is arg a packument" is determined by `lib.ytypes.Packument' helpers.
  # You can override `importFetchPackument' in the thunk with a custom
  # fetcher, and you man also specialize the thunk member's `registryScopes'
  # field just as you would for the `lib.importFetchPackument' functor.
  packumentLatestVersion = {
    __functionMeta = {
      argTypes     = yt.either yt.string yt.Packument.Structs.packument;
      open         = true;
      terminalArgs = { inherit (yt.Packument.Structs) packument; };
      thunkMembers = { importFetchPackument = yt.function; };
    };
    __functor = self: arg:
      self.__innerFunction ( self.__processArgs self arg );
    __thunk = { inherit (lib.libreg) importFetchPackument; };
    __functionArgs = fetchPackument.__functionArgs // {
      importFetchPackument = true;
      packument = true;
    };
    __processArgs = self: arg: let
      ifp  = arg.importFetchPackument or self.__thunk.importFetchPackument;
      ifpT = if ! ( builtins.isAttrs ifp ) then ifp else
             ifp // { __thunk = ifp.__thunk // self.__thunk; };
      ifpArgs  = removeAttrs ( self.__thunk // arg ) ["importFetchPackument"];
      fallback = if builtins.isString arg then ifpT arg else
                 if yt.Packument.packument.check arg then arg else ifp ifpArgs;
    in arg.packument or fallback;
    __innerFunction = packumentLatestVersion';
  };


# ---------------------------------------------------------------------------- #

  /**
   */
  packumenter = {
    __functionMeta.name = "packumenter";
    __functionMeta.from = "at-node-nix#lib.libreg";
    __functionMeta.doc  = ''
A lazily evaluated extensible packument database.
Packuments will not be fetched twice.
  let
    pr0 = packumenter;
    pr1 = pr0.__cache ( pr0.__lookup {
      ident = "lodash";
      registry = "https://registry.npmjs.org";
    } );
    pr2 = pr1.__cache ( pr1.__lookup {
      ident = "3d-view";
      registry = "https://registry.npmjs.org";
    } );
  in pr2.packuments

Or use the packumenter itself as a function:
  let
    pr0 = packumenter;
    pr1 = pr0 "lodash";
    pr2 = pr1 "3d-view";
  in pr2.packuments;

This is particularly useful with builtins.foldl':
  ( builtins.foldl' ( x: x ) packumenter ["lodash" "3d-view"] ).packuments

SEE ALSO:
  lib.libreg.importFetchPackument
  lib.libreg.flakeRegistryFromPackument
  lib.libsat.packumentSemverClosure
    '';

    packuments = {};

    __thunk.registry = lib.getDefaultRegistry;

    # Create an override extending a packumenter with a packument
    __lookup = self: { registry, ident }: let
      raw   = importFetchPackument { inherit registry ident; };
      extra = addPackumentExtras raw;
    in self.${ident} or extra;

    __processArgs = self: x: let
      pp  = lib.generators.toPretty { allowPrettyValues = true; };
      loc = "${self.__functionMeta.from}.${self.__functionMeta.name}";
      pi  = lib.ytypes.PkgInfo;
      lp  = lib.libparse;
      str =
        if builtins.isString x then x else
        x.ident or x.name or (
          if x ? key then dirOf x.key else
          if x ? scope then ( if x.scope == null
                              then x.bname
                              else "@${x.scope}/${x.bname}" ) else
          throw "(${loc}): No idea how to use '${pp x}' as an ident."
        );
      ident = if pi.Strings.identifier.check x then x else
              lib.yank "((@[^/@]+/)?[^@/]+).*" str;
    in self.__thunk // { inherit ident; };

    __cache = self: packument: self // {
      packuments = { ${packument._id} = packument; } // self.packuments;
    };

    __functor = self: x: let
      args      = self.__processArgs self x;
      packument = self.__lookup self args;
    in self.__cache self packument;
  };


  # TODO: deprecate in favor of `libsat'?
  # FIXME: you only collect `dependencies' here and likely want to collect
  # more than that. ( `libsat' fixes this )
  extendWithLatestDeps' = pr: let
    inherit (builtins) mapAttrs attrNames attrValues foldl' filter;
    depsFor = x: x.latest.dependencies or {};
    dropKnown = lib.filterAttrs ( k: _: ! ( pr.packuments ? ${k} ) );
    merge = set: k: if set ? ${k} then set else set // { ${k} = null; };
    collectDeps = xs: let
      skip = x: ( x ? _finished ) && x._finished;
      ad = x:
        if ( skip x ) then [] else ( attrNames ( dropKnown ( depsFor x ) ) );
    in foldl' merge {} ( ad xs );
    allDeps = map collectDeps ( attrValues pr.packuments );
    deduped = attrNames ( foldl' ( a: b: a // b ) {} allDeps );
    pr' =
      foldl' ( acc: x: builtins.traceVerbose "looking up ${x}" ( acc x ) ) pr
             deduped;
    mark = k: v: v // { _finished = true; };
    marked = let
      updatep = k: v: ( ! ( v ? _finished ) ) || ( ! v._finished );
      needUpdate = lib.filterAttrs updatep pr.packuments;
      updated = pr' // {
        packuments = pr'.packuments // ( mapAttrs mark needUpdate );
      };
    in updated;
  in marked;


# ---------------------------------------------------------------------------- #

  # TODO: deprecate in favor of `libsat'
  packumentClosure' = prev: packages: let
    pr = builtins.foldl' ( x: x ) prev ( lib.toList packages );
  in lib.converge extendWithLatestDeps' pr;

  packumentClosure = packumentClosure' packumenter;


# ---------------------------------------------------------------------------- #

  # XXX: YOU STILL NEED TO SET `inputs.<ID>.flake = false' in your `flake.nix'!
  # NOTE: `ak-nix' carries a flake registry generator routine which may be
  # preferable here since it can use a common record to output flake inputs,
  # flake registries, and a custom "fetchTree registry" which is effectively
  # a `flake.lock' with some added fields.
  flakeRegistryFromPackument = {
    ident       ? assert args ? packument; packument.name
  , registry    ? null
  , versionCond ? version: lib.test "[^a-zA-Z+-]*" version  # Only keep releases
  , treelock    ? false
  , existing    ? {}
  , type        ? "file"  # Some archives fail as `type = "tarball";'
  , minimizeFetchInfo ? false
  , packument         ? assert args ? ident; importFetchPackument args
  } @ args: assert ( args ? minimizeFetchInfo ) -> treelock; let
    registerVersion = version: let
      realVersion = if version == "latest"
                    then ( packumentLatestVersion' packument ).version
                    else version;
      id_v' = v:
        if v == "latest" then "latest" else
        ( builtins.replaceStrings ["@" "."] ["_" "_"] v );
      id_v = id_v' version;
      id_sb = let
        sb = lib.libparse.parseIdent ident;
      in if sb.scope == null then sb.bname else "${sb.scope}--${sb.bname}";
      fetchInfoUnlocked = {
        inherit type;
        url = packument.versions.${realVersion}.dist.tarball;
      };
      fetchInfo' =
        if treelock && ( version != "latest" ) && ( ! lib.inPureEvalMode )
        then {
          fetchInfo =
            ( if minimizeFetchInfo then {} else fetchInfoUnlocked ) // {
              inherit (builtins.fetchTree fetchInfoUnlocked) narHash;
            };
        } else {};
    in fetchInfo' // {
      from = { id = id_sb + "--" + id_v; type = "indirect"; };
      to = if version != "latest" then fetchInfoUnlocked else {
        id   = id_sb + "--" + ( id_v' realVersion );
        type = "indirect";
      };
    };
    latest = registerVersion "latest";
    keeps = let
      vns = builtins.attrNames packument.versions;
    in builtins.filter versionCond vns;
    entries = [latest] ++ ( map registerVersion keeps );
    merged = let
      notLatest   = { from, ... }: ( baseNameOf from.id ) != "latest";
      oldNodes    = existing.trees or existing.flakes or [];
      oldVersions = builtins.filter notLatest oldNodes;
      oldIds = map ( { from, ... }: from.id ) oldVersions;
      pick = { from, to, ... } @ new: let
        oldv' = builtins.filter ( old: from.id == old.from.id ) oldVersions;
        oldv  = if oldv' == [] then null else builtins.head oldv';
        condNoOld = ! ( builtins.elem from.id oldIds );
        condFI    = ( new ? fetchInfo ) && ( ! ( oldv ? fetchInfo ) );
        condFIT   = ( new ? fetchInfo ) && ( oldv ? fetchInfo ) &&
                    ( oldv.to.type != "tarball" ) &&
                    ( new.to.type == "tarball" );
        keep = condNoOld || ( ( oldv != null ) && ( condFI || condFIT ) );
      in if keep then new else oldv;
    in map pick entries;
  in if treelock then { treelockVersion = 1; trees  = merged; }
                 else { version = 2; flakes = entries; };


  flakeRegistryFromNpm = {
    __functionArgs   = lib.functionArgs flakeRegistryFromPackument;
    __innerFunction  = flakeRegistryFromPackument;
    __thunk.registry = lib.getDefaultRegistry;
    __processArgs = self: x: let
      attrs = if builtins.isAttrs x then x else
              if builtins.isString x then { ident = x; } else
              ( yt.either yt.string ( yt.attrs yt.any ) ) x;
    in self.__thunk // attrs;
    __functor = self: x: self.__innerFunction ( self.__processArgs self x );
  };


# ---------------------------------------------------------------------------- #

  # Flatten a list of `{ from, to, ... }' nodes to an attrset.
  # FIXME: probably move to `rime'.
  flattenLockNodes = lock: let
    proc = acc: { from, to, ... } @ ent: acc // {
      ${from.id} = if to.type == "indirect" then self.${to.id} else
                   ( ent.to // ( ent.fetchInfo or {} ) );
    };
    self = builtins.foldl' proc {} ( lock.trees or lock.flakes );
  in self;


# ---------------------------------------------------------------------------- #

  # FIXME: use `lib.generators.toPretty'
  # FIXME: use `checkPermsDrv' from `flocoPackages' to avoid crashes.
  flakeInputFromVInfoTarball = {
    name       ? null  # We don't use these, but I'm listing them for reference.
  , version    ? null
  , dist       ? {}
  , _resolved  ? vinfo.resolved or vinfo.dist.tarball
  , _from      ? null  # The original descriptor
  , _integrity ? null  # sri+SHA512 ( which we can't use sadly... )
  , _id                # "@${scope}/${pname}@${version}"
    # NOTE: You can't really include `id' in any flake input except `indirect'.
    # We include this option to include the `id' in case the user plans to
    # combine this in a `map' invocation, or will post process to extract the
    # ident to write it to a file.
  , withId ? false
    # We can embed a `__toPretty' function for cases where the caller plans to
    # write a generated flake, which is honestly how I expect this is going
    # to be used in most cases.
    # Just remember that you can't actually pass it to `getTree' with that
    # attribute preset ( use `removeAttrs' if you need both ).
  , withToPretty ? false
    # We can use `fetchTree' to convert the URI to a SHA256 in impure mode,
    # but I've left it optional in case someone needs it.
  , lookupNar ? true
  , ...  # `engines' and a few other obnoxious fields should get tossed.
  } @ vinfo: let
    dropAt = builtins.substring 1 ( builtins.stringLength _id ) _id;
    id = builtins.replaceStrings ["/" "@" "."] ["--" "--" "_"] _id;
    id' = if withId then { inherit id; } else {};
    # FIXME: this will crash if bad directory perms are written in tarball.
    #ff = builtins.fetchTree { url = _resolved; type = "file"; };
    ft = builtins.fetchTree { url = _resolved; type = "tarball"; };
    nh' = if lookupNar then { inherit (ft) narHash; } else {};
    toPretty' =
      if withToPretty then {
        val = { type = "tarball"; url = _resolved; } // nh';
        __pretty = self: ''
          inputs.${id} = {
            type  = "${self.type}";
            url   = "${self.url}";
            flake = false;
        '' + ( if self ? narHash
               then "  narHash = \"${self.narHash}\";\n" else "" ) + ''
          };
        '';
      } else {};
  in if withToPretty then toPretty' else {
    type = "tarball";
    url  = _resolved;
    flake = false;
  } // id' // nh' // toPretty';


# ---------------------------------------------------------------------------- #

  # FIXME: Make this name parser part of `metaEnt.names'.
  #
  # Given an input `id' created by `flakeInputFromVInfoTarball', return an
  # attrset with all the delicious nuggets of info therein.
  # Notably this makes it easy to convert to the `node2nix' names, which is
  # useful for replacing those `fetchurl' invocations with `fetchTree' calls.
  parseInputName = str: let
    ms = builtins.match "(.*)--(.*)--([0-9_]+)" str;
    mn = builtins.match "(.*)--([0-9_]+)" str;
    hasScope = ms != null;
    scope = if hasScope then builtins.head ms else null;
    scopeDir = if hasScope then "@${scope}/" else "";
    pname = if hasScope then builtins.elemAt ms 1 else builtins.head mn;
    version' = if hasScope then builtins.elemAt ms 2 else builtins.elemAt mn 1;
    version = builtins.replaceStrings ["_"] ["."] version';
    name = "${scopeDir}${pname}-${version}";
    packageName = scopeDir + pname;
    node2nixName =
      builtins.replaceStrings ["@" "/"] ["_at_" "_slash_"] packageName;
  in {
    inherit name version scopeDir pname packageName node2nixName;
    flakeInputName = str;
  } // ( if scope == null then {} else { inherit scope; } );


# ---------------------------------------------------------------------------- #

  fetchVInfo = registryUrl: name: version: let
    url  = "${registryUrl}/${name}/${version}";
    urlS = builtins.unsafeDiscardStringContext url;
  in builtins.readFile ( builtins.fetchTree { url = urlS; type = "file"; } );

  importFetchVInfo = registryUrl: name: version:
    builtins.fromJSON ( fetchVInfo registryUrl name version );


# ---------------------------------------------------------------------------- #

  # Abstract info about `version_abbrev' aka "VInfo".
  # This wraps the actual `vinfo' data indicating how it can be fetched, whether
  # the integrity of the data has been audited, etc.
  # This is essentially the contents of a `package.json' file wrapped in a fat
  # "this info is only partially trustworthy" lens.
  defVInfoMeta' = {
    ident    ? vinfo.name
  , version  ? vinfo.version
  , registry ? null
  , url      ? null
  , narHash  ? null
  , trust    ? false
  , vinfo
  } @ args: let
    pu  = lib.liburi.parseFullUrl args.url;
    nh' = if narHash != null then { inherit narHash; } else {};
  in {
    inherit ident version vinfo trust;
    _type    = "vinfoMeta";
    registry = args.registry or "${pu.scheme.transport}://${pu.authority}";
    url      = args.url or "${registry}/${ident}/${version}";
  } // nh';


  # Here we are just defining the record, scrubbing, and typechecking.
  # Fetching and any pure/impure handling can live in `mkVInfoMeta'
  defVInfoMeta = {
    __functionMeta.name = "defVInfoMeta";
    __functionMeta.from = "at-node-nix#lib.libreg";
    __functionMeta.signature = [( yt.attrs yt.any ) yt.Packument.vinfo_meta];
    __innerFunction = defVInfoMeta';
    __functionArgs  =
      ( lib.functionArgs defVInfoMeta.__innerFunction ) // { clean = true; };

    __cleanVersionInfo = { trust, vinfo, ... }: let
      gypfile' = if trust then { inherit (vinfo) gypfile; } else {};
      cleaned  = normalizeVInfo vinfo;
    in cleaned // gypfile';

    # FIXME: clean here not in `__functor'.
    __processArgs = self: x: removeAttrs x ["clean"];
    __thunk.clean = true;

    __functor = self: x: let
      st0     = builtins.head self.__functionMeta.signature;
      st1     = builtins.elemAt self.__functionMeta.signature 1;
      args    = st0 ( self.__processArgs self x );
      rsl     = self.__innerFunction args;
      doClean = x.clean or self.__thunk.clean or false;
      vinfo   = if doClean then self.__cleanVersionInfo rsl else rsl.vinfo;
      final   = st1 ( rsl // { inherit vinfo; } );
      loc     = "${self.__functionMeta.from}.${self.__functionMeta.name}";
      ec      = "(${loc}): called with ${lib.generators.toPretty {} x}";
    in builtins.addErrorContext ec final;
  };


# ---------------------------------------------------------------------------- #

  # XXX: Impure unless `narHash' is passed.
  fetchVInfoMetaNoChecks = {
    ident    ? dirOf key
  , version  ? baseNameOf key
  , key      ? "${ident}/${version}"
  , registry ? lib.registryForScope { inherit ident; }
  , clean    ? true
  , narHash  ? null
  , trust    ? false
  } @ args: let
    nh'     = if args ? narHash then { inherit (args) narHash; } else {};
    narHash = args.narHash or fetched.narHash;
    url     = "${registry}/${ident}/${version}";
    fetched = builtins.fetchTree ( { type = "file"; inherit url; } // nh' );
  in defVInfoMeta {
    inherit ident version url registry trust narHash clean;
    vinfo = lib.importJSON fetched.outPath;
  };


  # TODO: Define `mkVInfoMeta'
  #  - fill missing trust/narHash
  #  - allow impure fetching
  mkVInfoMeta' = { pure ? true, ifd ? false }: {
    __functionArgs = {

    };
  };


# ---------------------------------------------------------------------------- #

  auditVInfoWithIFD = {
    dist             ? args.vinfo.dist
  , scripts          ? args.vinfo.scripts or {}
  , bin              ? args.vinfo.bin or {}
  , hasInstallScript ? args.vinfo.hasInstallScript or false
  , gypfile          ? args.vinfo.gypfile or false

  , narHash ? src.narHash
  , src ? builtins.fetchTree ( {
      type = "tarball";
      url  = dist.tarball;
    } // ( if args ? narHash then { inherit narHash; } else {} ) )
  , ...
  } @ args: let
    pjs        = lib.importJSON ( src + "/package.json" );
    hasGypfile = builtins.pathExists ( src + "/binding.gyp" );
    bname      = baseNameOf pjs.ident;
    forBindir  = let
      ents  = builtins.readDir ( src + "/${pjs.directories.bin}" );
      files = lib.filterAttrs ( _: type: type != "directory" ) ents;
      proc = acc: fname: acc // {
        ${lib.libfs.baseNameOfDropExt fname} =
          "${pjs.directories.bin}/${fname}";
      };
    in builtins.foldl' proc {} ( builtins.attrNames files );
    packBinNorm =
      if builtins.isAttrs ( bin ) then bin else
      if builtins.isString bin then { ${bname} = bin; } else
      throw "Bad 'bin' type: ${builtins.typeOf bin}";
    getBinPairs =
      if builtins.isAttrs ( pjs.bin or {} ) then pjs.bin or {} else
      if builtins.isString pjs.bin then { ${bname} = pjs.bin; } else
      if pjs ? directories.bin     then forBindir else
      throw "Bad 'bin' type: ${builtins.typeOf ( pjs.bin or null )}";

    binsSame  = ( pjs.bin or null ) == ( args.bin or args.vinfo.bin or null );
    binsEquiv = binsSame || ( packBinNorm == getBinPairs );
    scriptsSame  =
      ( args.scripts or args.vinfo.scripts or null ) == ( pjs.scripts or null );
    scriptsEquiv = scriptsSame ||
                   ( hasGypfile &&
                     ( ( scripts.install or null ) ==
                       ( pjs.scripts.install or "node-gyp rebuild" ) ) );
    actuallyHasInstallScript = ( pjs ? scripts.install )     ||
                               ( pjs ? scripts.preinstall )  ||
                               ( pjs ? scripts.postinstall );
    equiv =
      binsEquiv && scriptsEquiv &&
      ( hasGypfile == gypfile ) &&
      ( hasInstallScript == actuallyHasInstallScript );
    registry = {
      inherit hasInstallScript gypfile;
      bin     = args.bin or args.vinfo.bin or null;
      scripts = args.scripts or args.vinfo.scripts or null;
    };
    tarball = {
      hasInstallScript = actuallyHasInstallScript;
      gypfile          = hasGypfile;
      bin              = pjs.bin or null;
      scripts          = pjs.scripts or null;
    };
    diff = let
      d = lib.filterAttrs ( f: v: v != registry.${f} ) tarball;
    in builtins.mapAttrs ( f: v: {
      tarball  = v;
      registry = registry.${f};
    } ) d;
    ediff = let
      drops = ( if scriptsEquiv then ["scripts"] else [] ) ++
              ( if binsEquiv then ["bin"] else [] );
    in removeAttrs diff drops;
  in {
    inherit
      binsSame binsEquiv scriptsSame scriptsEquiv equiv
      registry tarball diff ediff
    ;
  };


# ---------------------------------------------------------------------------- #

  # Drop junk fields from vinfos, and add explicit handlers for a few fields
  # that we actually care about.
  # FIXME: This could probably be shortened using `builtins.intersectAttrs'.
  #
  # NOTE: Information held by the NPM registry is not always accurate.
  # For example several packages are listed as having scripts that don't
  # actually exist in the real `package.json', and at runtime NPM only refers
  # to packument metadata to fetch other packuments for performing semver
  # resolution and fetching tarballs.
  # For builds the information in `package.json' and the tarballs' contents are
  # used - this matters especially for `gypfile', `hasInstallScript', `bin',
  # and `scripts'.
  # In the majority of cases the info is accurate ( except for `gypfile' ), but
  # enough popular packages like `@datadog/*', `fsevents', etc are all plagued
  # by this issue to the point that you shouldn't try to construct a `metaEnt'
  # from this info unless you've audited its accuracy beforehand.
  normalizeVInfo = vinfo: let
    removes = [
      "_npmOperationalInternal"
      "maintainers"
      "_npmUser"
      "contributors"
      #"engines"   # XXX: we want this field
      "homepage"
      "license"
      "icon"
      "keywords"
      "author"
      "bugs"
      # XXX: DO NOT SAVE THIS FIELD!
      "gypfile"  # See note below about `gypfile' field.
      # XXX: DO NOT SAVE THIS FIELD!
    ];
    # Subfields
    removesDist = [  # dist.<ATTR>
      "signatures"
      "npm-signature"
      "unpackedSize"
      "fileCount"
    ];
    dist = removeAttrs ( vinfo.dist or {} ) removesDist;
    san  = ( removeAttrs vinfo removes ) // { inherit dist; };
    # Missing `install' scripts are automatically added by the NPM registry
    # for projects with `binding.gyp' in the root.
    # This SHOULD be in the vinfo already if we pulled from a "standard"
    # registry, but because I can't find anywhere that actually specifies
    # whether or not this is always added for all implementations of "NPM style
    # registries" - I am making this explicit.
    #
    # NOTE: This is not "bullet-proof", there's no real spec for registries.
    # We have no guarantees that the `scripts' or `gypfile' fields will
    # be present.
    # As a practical matter we're covering NPM, Verdaccio, and GitHub Packages.
    #
    # XXX: This is important!
    # The `gypfile' field recorded in the NPM registry does NOT indicate that
    # the tarball contains a `binding.gyp' file.
    # This means the field is context dependant and should be ignored in
    # registry queries, but preserved from `package-lock.json' files.
    # This was a pretty fucking bad idea and there's a fat NPM issue thread
    # spanning ~2 years covering the variety of issues it has caused.
    # v8.x of NPM seemed to be hit particularly hard and will incorrectly run
    # `node-gyp rebuild;' in some installs depending on cache contents...
    hasInstallScript = ( san ? scripts.install )      ||
                       ( san ? scripts.preinstall )   ||
                       ( san ? scripts.postinstall );
    result = { inherit hasInstallScript; } // san;
  in assert ! ( result ? gypfile );
     result;


# ---------------------------------------------------------------------------- #

  importCleanVInfo = registryUrl: name: version:
    normalizeVInfo ( importFetchVInfo registryUrl name version );

  importVInfoNpm = importCleanVInfo "https://registry.npmjs.org";


# ---------------------------------------------------------------------------- #

in {
  inherit
    registryForScope
  ;
  inherit
    fetchPackument
    importFetchPackument
    packumentLatestVersion
  ;

  inherit
    packumenter
    extendWithLatestDeps'
    packumentClosure'
    packumentClosure
  ;

  inherit
    flakeRegistryFromPackument
    flakeRegistryFromNpm
    flakeInputFromVInfoTarball
    flattenLockNodes
  ;

  inherit
    fetchVInfo
    importFetchVInfo
    normalizeVInfo
    importCleanVInfo
    importVInfoNpm
  ;

  inherit
    defVInfoMeta'
    defVInfoMeta
    fetchVInfoMetaNoChecks
    auditVInfoWithIFD
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
