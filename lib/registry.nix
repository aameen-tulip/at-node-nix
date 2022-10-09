# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  inherit (lib.flocoConfig) registryScopes;
  dftReg = registryScopes._default;

# ---------------------------------------------------------------------------- #

  # Given a scope, return the registry URL we should use.
  # Uses thunked dictionary to map scopes to registries. 
  _registryForScope = {
    scope          ? meta.scope or ( lib.yank "@([^/]+)" ( dirOf ident ) )
  , ident          ? meta.ident or name
  , name           ? meta.name  or ( dirOf key )
  , key            ? meta.key
  , meta           ? {}
  , registryScopes ? flocoConfig.registryScopes
  , flocoConfig    ? lib.flocoConfig or lib.libcfg.defaultFlocoConfig
  , ...
  } @ args: let
    stripped = lib.yank "@?([^/]+)/?" scope;
    sc = if ( scope == "." ) || ( scope == null ) then "_default" else stripped;
  in registryScopes.${sc} or registryScopes._default;

  # See `tests/libreg/tests.nix' for more examples.
  registryForScope = {
    __functionMeta = {
      argTypes = ["string" "set"];
      destructure  = true;
      terminalArgs = { scope = "string"; };
      thunkMembers = { registryScopes = "set"; };
      keywords = [
        "functor" "configured" "thunk" "polymorphic" "wrapper"
        "registry" "scope"
      ];
      doc = ''
  registryForScope :: (String:<key|ident|scope> | Attrs) -> String

  Ex:  registryForScope "foo"                                  ==> "https://registry.npmjs.org"
  Ex:  registryForScope { ident = "@foo/bar"; }                ==> "https://registry.npmjs.org"
  Ex:  registryForScope { flocoConfig = ...; scope = "foo"; }  ==> http://myregistry.com

  Recommended Attr Args: { scope, registryScopes }
  Fallback Attr Args:    { scope <- ident|name|key|meta, registryScopes <- flocoConfig }  ;;  `meta' may provide (ident|name|key) fallbacks

  Uses `lib.flocoConfig.registryScopes' by default.
  You may also set `__thunk.(registryScopes|flocoConfig)' to specialize this functor to use alternate scope settings.

  When a string argument is passed, the default registry scope list is used, and the string is parsed using `lib.libpkginfo.normalizePkgScope'.
  NOTE: this means that passing "@foo/bar" OR "foo" uses "foo" as the scope - which might not be what you expect.

  KEYWORDS: functor, configured, thunk, polymorphic, registry, scope
'';
    };
    __functor = self: arg:
      self.__innerFunction self ( self.__processArgs self arg );
    __functionArgs = ( lib.functionArgs _registryForScope ) // {
      name = true;
      key  = true;
    };
    __processArgs = self: arg: let
      scopeFromString =
        if ! ( lib.libpkginfo.Scope.isType arg ) then { scope = null; } else
        { inherit (lib.libpkginfo.Scope.fromString arg) scope; };
   in if builtins.isString arg then scopeFromString else
      if builtins.isAttrs arg then arg else
      if arg == null then { scope = null; } else
      throw "registryForScope: arg must be a string (scope) or attrset";
    __thunk = let
      flocoConfig = lib.flocoConfig or lib.libcfg.defaultFlocoConfig;
    in { inherit (flocoConfig) registryScopes; };
    __innerFunction = self: _registryForScope;
  };

# ---------------------------------------------------------------------------- #

  isPackument = x: let
    # Values are for "is field optional".
    # This wasn't audited on a particularly large data set, but it can be
    # refined as needed.
    # Note that GitHub Packages and NPM have differences concerning fallback
    # values ( `readme' for example ).
    # I have not checked Verdaccio.
    knownFields = {
      _id = false;
      _rev = true;
      author = true;
      bugs = true;
      contributors = true;
      description = false;
      dist-tags = false;
      homepage = false;
      keywords = true;
      license = false;
      maintainers = true;
      name = false;
      readme = true;           # Not on GitHub Packages
      readmeFilename = true;   # Not on GitHub Packages
      repository = false;
      time = false;
      users = true;
      versions = false;
    };
    indicators = [
      ( ( x._type or null ) == "packument" )
      # Make sure we have the required fields
      ( builtins.all ( f: knownFields.${f} || ( x ? ${f} ) )
                     ( builtins.attrNames knownFields ) )
    ];
    conds = [
      ( builtins.isAttrs x )
      ( builtins.any ( b: b == true ) indicators )
    ];
  in builtins.all ( b: b == true ) conds;


# ---------------------------------------------------------------------------- #

  # Fetch a packument from the registry.
  # String string contexts to ensure that the fetched result doesn't root its
  # hash from any arguments.
  # NOTE: I honestly don't know if it would do this, but I'm not going to dig
  #       through the Nix source code to find out right now.
  _fetchPackument = { registry, ident, ... }: let
    url = builtins.unsafeDiscardStringContext "${registry}/${ident}";
  in builtins.readFile ( builtins.fetchurl url );

  fetchPackument = {
    __functionMeta = {
      argTypes     = ["string" "set"];
      destructure  = true;
      terminalArgs = { registry = "string"; ident = "string"; };
      thunkMembers = { registryScopes = "set"; };
    };
    __functionArgs = {
      flocoConfig    = true;
      registryScopes = true;
      registry       = true;
      name           = true;
      ident          = true;
      meta           = true;
      key            = true;
    };
    __thunk = let
      flocoConfig = lib.flocoConfig or lib.libcfg.defaultFlocoConfig;
    in { inherit (flocoConfig) registryScopes; };
    __functor = self: arg: let
      regArgs =
        if builtins.isAttrs arg then self.__thunk // arg else
        self.__thunk // {
          scope = lib.yank "@([^/]+).*" arg;
          ident = lib.yank "((@[^/]+/)?[^@/]+)(/[1-9][^/@]*)?" arg;
        };
      registry = registryForScope regArgs;
      ident =
        regArgs.ident or regArgs.meta.ident or regArgs.name or regArgs.meta.name
        or ( dirOf ( regArgs.key or regArgs.meta.key ) );
    in _fetchPackument ( { inherit ident registry; } // regArgs );
  };

  # Tail calls `builtins.fromJSON' after fetching.
  importFetchPackument = fetchPackument // {
    __functor = self: arg: let
      wrapFP = fetchPackument // { inherit (self) __thunk; };
    in builtins.fromJSON ( wrapFP arg );
  };


# ---------------------------------------------------------------------------- #

  addPackumentExtras = packument: let
    nid' = lib.libparse.parseIdent packument._id;
    scopeDir = if ( nid'.scope != null ) then "@${nid'.scope}/" else "";
    nid = nid' // { inherit scopeDir; };
    addNiVers = vers: val: val // nid // { reference = vers; };
    addTarInfoVers = val: let
      fetchTarballArgs = ( { tarball, integrity ? "", shasum ? "", ... }: {
        url = tarball;
        hash = integrity;
        sha1 = shasum;
      } ) val.dist;
      fetchWith = {
        fetchurl ? ( { url, ... }: builtins.fetchurl url )
      }: builtins.fetchurl fetchTarballArgs;
    in val // {
      inherit fetchTarballArgs fetchWith;
      inherit (val.dist) tarball;
    };
    addAllDeps = val: val // {
      allDependencies = lib.libpkginfo.allDependencies val;
    };
    addPerVers = vers: val:
      #( addAllDeps ( addTarInfoVers ( addNiVers vers val ) ) );
      addNiVers vers val;
    # FIXME:
    versions = builtins.mapAttrs addPerVers ( packument.versions or {} );
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
  # "Is arg a packument" is determined by `lib.libreg.isPackument'.
  # You can override `importFetchPackument' in the thunk with a custom
  # fetcher, and you man also specialize the thunk member's `registryScopes'
  # field just as you would for the `lib.importFetchPackument' functor.
  packumentLatestVersion = {
    __functionMeta = {
      argTypes = ["string" "set"];
      destructure = true;
      terminalArgs = { packument = "set"; };
      thunkMembers = { importFetchPackument = "lambda"; };
    };
    __functor = self: arg:
      self.__innerFunction self ( self.__processArgs self arg );
    __thunk = { inherit (lib.libreg) importFetchPackument; };
    __functionArgs = fetchPackument.__functionArgs // {
      importFetchPackument = true;
      packument = true;
    };
    __processArgs = self: arg: let
      ifp = arg.importFetchPackument or self.__thunk.importFetchPackument;
      ifpT = if ! ( builtins.isAttrs ifp ) then ifp else
             ifp // { __thunk = ifp.__thunk // self.__thunk; };
      ifpArgs = removeAttrs ( self.__thunk // arg ) ["importFetchPackument"];
      fallback = if builtins.isString arg then ifpT arg else
                 if lib.libreg.isPackument arg then arg else ifp ifpArgs;
    in arg.packument or fallback;
    __innerFunction = self: packumentLatestVersion';
  };


# ---------------------------------------------------------------------------- #

  getTarInfo = x:
    let dist = x.dist or x.tarball or ( packumentLatestVersion x ).dist;
    in { inherit (dist) tarball; integrity = dist.integrity or null; };

  # FIXME: You can likely convert `shasum' to a valid hash.
  getFetchurlTarballArgs = x:
    let ti = getTarInfo x; in { url = ti.tarball; hash = ti.integrity; };


# ---------------------------------------------------------------------------- #

  fetchTarInfo = registryUrl: name: version:
    let packument = importFetchPackument registryUrl name;
    in getTarInfo packument.versions.${version};

  fetchFetchurlTarballArgs = registryUrl: name: version: let
    packument = importFetchPackument registryUrl name;
    dist = packument.versions.${version}.dist;
  in {
    url  = dist.tarball;
    hash = dist.integrity or "";
    sha1 = dist.shasum or "";
  };

  fetchFetchurlTarballArgsNpm =
    { name ? null, pname ? null, version ? "latest" }:
      assert ( name != null ) || ( ( pname != null ) && ( version != null ) );
      let
        pns = builtins.split "@" name;
        pnsl = builtins.length pns;
        versionFromName = builtins.elemAt pns ( pnsl - 1 );
        pnameFromName = if pnsl == 5 then "@" + ( builtins.elemAt pns 2 )
                                     else ( builtins.head pns );
        pname' = if name == null then pname else pnameFromName;
        version' = if name == null then version else versionFromName;
      in fetchFetchurlTarballArgs "https://registry.npmjs.org/" pname' version';


# ---------------------------------------------------------------------------- #

  # FIXME: updates to `importFetchPackument' broke this functor, but
  # honestly we've learned a lot since this was written and could use it could
  # benefit from a rewrite to integrate with the new registry/scope handling.

  /**
   * A lazily evaluated extensible packument database.
   * Packuments will not be fetched twice.
   *   let
   *     pr   = packumenter;
   *     pr'  = pr.extend ( pr.lookup "lodash" );
   *     pr'' = pr.extend ( pr.lookup "3d-view" );
   *   in pr''.packuments
   *
   * Or use the packumenter itself as a function:
   *   let
   *     pr   = packumenter;
   *     pr'  = pr "lodash";
   *     pr'' = pr "lodash";
   *   in pr''.packuments;
   *
   * This is particularly useful with `builtins.foldl'':
   *   ( builtins.foldl' ( x: x ) packumenter ["lodash" "3d-view"] ).packuments
   */
  packumenter = lib.makeExtensible ( final: {
    packuments = {};
    registry = "https://registry.npmjs.org/";
    # Create an override extending a packumenter with a packument
    lookup = str: let
      ni = lib.libparse.nameInfo str;
      fetchPack = prev:
        let raw = importFetchPackument prev.registry ni.name;
        in addPackumentExtras raw;
      addPack = final: prev:
        if ( prev.packuments ? ${ni.name} ) then {} else {
          packuments = prev.packuments // { ${ni.name} = ( fetchPack prev ); };
        };
    in addPack;
    __functor = self: str: self.extend ( self.lookup str );
  } );


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
      foldl' ( acc: x: builtins.trace "looking up ${x}" ( acc x ) ) pr deduped;
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

  # That's right ladies and gentlemen, you've stubmled upon the mythic
  # "Y Combinator" in the wild.
  packumentClosure' = prev: packages:
    let pr = builtins.foldl' ( x: x ) prev ( lib.toList packages );
    in lib.converge extendWithLatestDeps' pr;

  packumentClosure = packumentClosure' packumenter;


# ---------------------------------------------------------------------------- #

  # XXX: YOU STILL NEED TO SET `inputs.<ID>.flake = false' in your `flake.nix'!
  # NOTE: `ak-nix' carries a flake registry generator routine which may be
  # preferable here since it can use a common record to output flake inputs,
  # flake registries, and a custom "fetchTree registry" which is effectively
  # a `flake.lock' with some added fields.
  flakeRegistryFromPackuments = registryUrl: name: let
    p = importFetchPackument registryUrl name;
    registerVersion = version:
      let v = builtins.replaceStrings ["@" "."] ["_" "_"] version; in {
      from = { id = name + "-" + v; type = "indirect"; };
      to = {
        type = "tarball";
        url = p.versions.${version}.dist.tarball;
      };
    };
    latest = let
      v = ( packumentLatestVersion' p ).version;
      v' = builtins.replaceStrings ["@" "."] ["_" "_"] v;
    in {
      from = { id = name; type = "indirect"; };
      to = { id = name + "-" + v'; type = "indirect"; };
    };
  in {
    version = 2;
    flakes =
      [latest] ++ ( map registerVersion ( builtins.attrNames p.versions ) );
  };

  flakeRegistryFromNpm =
    flakeRegistryFromPackuments "https://registry.npmjs.org";


# ---------------------------------------------------------------------------- #

  # FIXME: use `lib.generators.toPretty'
  flakeInputFromManifestTarball = {
    name       ? null  # We don't use these, but I'm listing them for reference.
  , version    ? null
  , dist       ? {}
  , _resolved
  , _from      ? null  # The original descriptor
  , _integrity ? null  # sri+SHA512 ( which we can't use sadly... )
  , _id                # "@${scope}/${pname}@${version}"
    # NOTE: You can't really include `id' in any flake input except `indirect'.
    # We include this option to include the `id' in case the user plans to
    # combine this in a `map' invocation, or will post process to extract the
    # ident to write it to a file.
  , withId ? false
    # We can embed a `__toString' function for cases where the caller plans to
    # write a generated flake, which is honestly how I expect this is going
    # to be used in most cases.
    # Just remember that you can't actually pass it to `getTree' with that
    # attribute preset ( use `removeAttrs' if you need both ).
  , withToString ? false
    # We can use `fetchTree' to convert the URI to a SHA256 in impure mode,
    # but I've left it optional in case someone needs it.
  , lookupNar ? true
  , ...  # `engines' and a few other obnoxious fields should get tossed.
  } @ manifest: let
    dropAt = builtins.substring 1 ( builtins.stringLength _id ) _id;
    id = builtins.replaceStrings ["/" "@" "."] ["--" "--" "_"] ( _id );
    maybeId = if withId then { inherit id; } else {};
    ft = builtins.fetchTree { url = _resolved; type = "tarball"; };
    maybeNarHash = if lookupNar then { inherit (ft) narHash; } else {};
    maybeToString =
      if withToString then {
        __toString = self: ''
          inputs.${id} = {
            type = "${self.type}";
            url = "${self.url}";
            flake = false;
        '' + ( if self ? narHash
               then "  narHash = \"${self.narHash}\";\n" else "" ) + ''
          };
        '';
      } else {};
  in {
    type = "tarball";
    url  = _resolved;
    flake = false;
  } // maybeId // maybeNarHash // maybeToString;


# ---------------------------------------------------------------------------- #

  # FIXME: Make this name parser part of `metaEnt.names'.
  #
  # Given an input `id' created by `flakeInputFromManifestTarball', return an
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

  fetchManifest = registryUrl: name: version: let
    url  = "${registryUrl}/${name}/${version}";
    urlS = builtins.unsafeDiscardStringContext url;
  in builtins.readFile ( builtins.fetchurl urlS );

  importFetchManifest = registryUrl: name: version:
    builtins.fromJSON ( fetchManifest registryUrl name version );


# ---------------------------------------------------------------------------- #

  # Drop junk fields from manifests, and add explicit handlers for a few fields
  # that we actually care about.
  # FIXME: This could probably be shortened using `builtins.intersectAttrs'.
  # FIXME: Create a `metaEnt' from this.
  normalizeManifest = manifest: let
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
    ];
    # Subfields
    removesDist = [  # dist.<ATTR>
      "signatures"
      "npm-signature"
      "unpackedSize"
      "fileCount"
    ];
    dist = removeAttrs ( manifest.dist or {} ) removesDist;
    san  = ( removeAttrs manifest removes ) // { inherit dist; };
    # Missing `install' scripts are automatically added by the NPM registry
    # for projects with `binding.gyp' in the root.
    # This SHOULD be in the manifest already if we pulled from a "standard"
    # registry, but because I can't find anywhere that actually specifies
    # whether or not this is always added for all implementations of "NPM style
    # registries" - I am making this explicit.
    #
    # NOTE: This is not "bullet-proof", there's no real spec for registries.
    # We have no guarantees that the `scripts' or `gypfile' fields will be present.
    # As a practical matter we're covering NPM, Verdaccio, and GitHub Packages.
    hasInstallScript = ( san ? scripts.install )      ||
                       ( san ? scripts.preinstall )   ||
                       ( san ? scripts.postinstall )  ||
                       ( san.gypfile or false );
    gypfile = san.gypfile or false;
  in { inherit hasInstallScript gypfile; } // san;


# ---------------------------------------------------------------------------- #

  importCleanManifest = registryUrl: name: version:
    normalizeManifest ( importFetchManifest registryUrl name version );

  importManifestNpm = importCleanManifest "https://registry.npmjs.org";


# ---------------------------------------------------------------------------- #

  # Fetch an NPM package using `fetchTree'.
  # FIXME: this is kind of dumb, you'd need to run `prepare'.
  fetchGitNpm = name: version: let
    mf = importManifestNpm name version;
    noPx = builtins.replaceStrings ["git+"] [""] mf.repository.url;
    # `fetchTree' doesn't like it when you pass `rev' as an argument, which
    # is probably a bug - this works around the issue.
    rev = if mf ? gitHead then "#${mf.gitHead}" else "";
  in builtins.fetchTree {
    inherit (mf.repository) type;
    url = noPx + rev;
  };


# ---------------------------------------------------------------------------- #

in {
  inherit
    registryForScope
  ;
  inherit
    isPackument
    fetchPackument
    importFetchPackument
    packumentLatestVersion
  ;

  inherit
    getTarInfo
    getFetchurlTarballArgs
    fetchTarInfo
    fetchFetchurlTarballArgs
    fetchFetchurlTarballArgsNpm
  ;

  inherit
    packumenter
    extendWithLatestDeps'
    packumentClosure'
    packumentClosure;

  inherit
    flakeRegistryFromPackuments
    flakeRegistryFromNpm
    flakeInputFromManifestTarball
  ;

  inherit
    fetchManifest
    importFetchManifest
    normalizeManifest
    importCleanManifest
    importManifestNpm
    fetchGitNpm
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
