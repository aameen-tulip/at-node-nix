# ============================================================================ #
#
# FIXME: This file needs to be pruned for dead code, or at least split more
# clearly into routines intended for V1 and V2 lockfiles.
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  inherit (builtins)
    attrValues
    partition
    mapAttrs
    listToAttrs
    isString
    foldl'
    genericClosure
    elem
    match
    head
    groupBy
    attrNames
  ;

/* -------------------------------------------------------------------------- */

  # FIXME:
  #   Most of these were written referencing a lockfile created by NPM v6.
  #   NPM v8 made notable changes to the "top level" keys of their lockfile
  #   to support workspaces.
  #   Luckily these changes largely just effect treatment of the top-level; but
  #   these functions should be updated accordingly.


/* -------------------------------------------------------------------------- */

  # Helper that follows linked entries.
  realEntry = plock: path: let
    e = plock.packages."${path}";
    entry = if e.link or false then plock.packages."${e.resolved}" else e;
  in assert plock.lockfileVersion == 2; entry;


  # Given an NPM v8 `package-lock.json', return the top-level lock entry for
  # package with `name'.
  # This does not search nested entries.
  # This "follows" links to get the actual package info.
  # The field `name' will be pushed down into entries if it is not present.
  getTopLevelEntry = plock: name: assert plock.lockfileVersion == 2;
    { inherit name; } // ( realEntry plock "node_modules/${name}" );


/* -------------------------------------------------------------------------- */

  resolveDepFor = plock: from: ident: let
    isSub = k: _: lib.test "${from}/node_modules/${ident}" k;
    subs = lib.filterAttrs isSub plock.packages;
    parent = lib.yank "(.*)/node_modules/(@[^/]+/)?[^/]+" from;
    fromParent = resolveDepFor plock parent ident;
    path = if subs != {} then ( head ( attrNames subs ) ) else
      if parent != null then null else "node_modules/${ident}";
    entry = realEntry plock path;
  in if path == null then fromParent else { resolved = path; value = entry; };


  resolvePkgKeyFor = {
    plock
  , from   ? ""
  , parent ?  let
      _maybeParent = lib.yank "(.*)/node_modules/(@[^/]+/)?[^/]+" from;
    in if _maybeParent == null then "" else _maybeParent
  , ent    ? realEntry plock from
  } @ ctx: ident: let
    fromTop = let
      fromTopNm = ( getTopLevelEntry plock ident ).version;
      _version  = if ident == plock.name then plock.version else fromTopNm;
    in "${ident}/${_version}";
    fromParent =
      if parent != ""
      then ( resolvePkgKeyFor { inherit plock; from = parent; } ident )
      else fromTop;
    sub = ent.dependencies.${ident}    or
          ent.dependencies.${ident}    or
          ent.devDependencies.${ident} or
          ent.dependencies.${ident}    or null;
    version =
      if ( sub == null ) || ( builtins.isString sub ) then null else
      if ( sub.link or false ) then plock.packages.${sub.resolved}.version else
      sub.version;
    fromSub = "${ident}/${version}";
  in if from == "" then fromTop else
     if ent.link or false then resolvePkgKeyFor {
       inherit plock; from = ent.resolved;
     } ident else if version != null then fromSub else fromParent;


  splitNmToAttrPath = nmpath: let
    sp = builtins.tail ( lib.splitString "node_modules/" nmpath );
    stripTrailingSlash = s: let
      m = lib.yank "(.*[^/])/" s;
    in if m == null then s else m;
  in map stripTrailingSlash sp;


  # This one is wonky, it's V2 only and uses fields from V1 and V3.
  # This might be the only function that actually takes advantage of the hybrid.
  # FIXME: this should target V1 or V3, not V2 since that's going to be
  # deprecated in the near future.
  resolvePkgVersionFor = {
    plock
  , from       ? ""
  , parentPath ? lib.take ( ( builtins.length fromPath ) - 1 ) fromPath
  , fromIdent  ? if from == "" then plock.name else
                 lib.yank ".*node_modules/(.*)" from
  , fromPath   ?
      if ctx ? parentPath then ( parentPath ++ [fromIdent] ) else
      ( splitNmToAttrPath from )
  , ent ? if fromPath == [] then plock else
    lib.getAttrFromPath ( lib.intersperse "dependencies" fromPath )
                        plock.dependencies
  } @ ctx: ident: let
    depHasSubs = builtins.isAttrs ent.dependencies.${ident};
    depWasNormalized = ( ent ? dependencies.${ident} ) && depHasSubs;
  in if depWasNormalized then ent.dependencies.${ident}.version else
     resolvePkgVersionFor { inherit plock; fromPath = parentPath; } ident;


/* -------------------------------------------------------------------------- */

  pinVersionsFromPLockV2 = plock: let
    pinEnt = from: {
      version
    , dependencies    ? {}
    , devDependencies ? {}
    , name            ? lib.yank ".*node_modules/(.*)" from
    , ...
    } @ ent: let
      pin = resolvePkgVersionFor { inherit from plock; };
      pinDep = ident: descriptor:
        if builtins.isString descriptor then pin ident else descriptor.version;
      rt' = lib.optionalAttrs ( dependencies != {} ) {
        runtimeDepPins =
          builtins.mapAttrs pinDep
            ( lib.filterAttrs ( _: v: ! ( v.dev or false ) ) dependencies );
      };
      hasNormalizedDev =
        builtins.any ( v: v.dev or false ) ( builtins.attrValues dependencies );
      dev' =
        lib.optionalAttrs ( hasNormalizedDev || ( devDependencies != {} ) ) {
          devDepPins = let
            dd = builtins.mapAttrs pinDep devDependencies;
            d = builtins.mapAttrs pinDep
                  ( lib.filterAttrs ( _: v: ( v.dev or false ) ) dependencies );
          in dd // d;
        };
    in { key = "${name}/${version}"; inherit name version; } // rt' // dev';
    pinned = builtins.mapAttrs pinEnt plock.packages;
    renamed = let
      renameFromKey = { key, ... } @ value: {
        name  = key;
        value = removeAttrs value ["pkey" "key" "name" "version"];
      };
    in builtins.listToAttrs
      ( map renameFromKey ( builtins.attrValues pinned ) );
    # It is with a heavy heart that I added support for "instances"; known as
    # "ABI Conflicts" in compiled languages ( the most dangerous category of
    # undefined behavior ).
    # If your code breaks because of "instances", it's possible that there is a
    # bug here in this routine, but know that I will not respond to any issues
    # or PRs which relate to this "feature".
    # If your code-base depends on instances, then it should be refactored or
    # put down like the rabid animal that it is.
    # The idea that other package managers allow this would be comical if not
    # for how dangerous it were in real world software that real people
    # depend on.
    # Reliance on "instances" indicates that a project has sprawled without
    # sane regard for interface design; and reflects poorly on the authors who
    # produced those interfaces.
    # If you file a bug about how you `node-gyp' build is selecting the wrong
    # `nan' version when deeply nested in `node_modules/' directories, I will
    # mock you and likely make snide remarks about how "you should never have
    # transfered out that MBA program at University".
    # The software we write is used in infrastructure that everyday people
    # depend on to pay their bills, access health care, and communicate with one
    # another - when those systems are poorly engineered or maintained there are
    # real world consequences.
    # My critique of these failure on the part of authors is not merely to call
    # them "stupid", I sincerely fear that they are unknowingly putting others
    # at risk by their own ignorance or lack of education in core
    # Software Engineering fundamentals, which cannot easily be conveyed leaving
    # me with only "have you considered other career paths?" to get the desired
    # point across.
    instances = let
      pushDownPkey =
        builtins.mapAttrs ( pkey: v: v // { inherit pkey; } ) pinned;
      kg = builtins.groupBy ( x: x.key ) ( builtins.attrValues pushDownPkey );
      count = _: gents: let
        all = builtins.length gents;
        uniq = lib.unique ( map ( m: removeAttrs m ["pkey"] ) gents );
      in ( 1 < all ) && ( 1 < ( builtins.length uniq ) );
      need = lib.filterAttrs count kg;
      byPkey = _: builtins.listToAttrs ( { pkey, ... } @ value: {
        name = pkey;
        value.instances = removeAttrs value ["pkey" "key" "name" "version"];
      } );
      insts = builtins.mapAttrs byPkey need;
      warn =
        "WARNING: Conflicting instances of packages were detected in your lock"
        + "\nXXX: Seriously, I know you blow off warnings, this is actually "
        + "bad and you need to take immediate action.";
    in if ( insts != {} ) then builtins.trace warn insts else {};
  in renamed // instances; # this clobbers


/* -------------------------------------------------------------------------- */

in {

  # The real lib members.
  inherit
    realEntry
    getTopLevelEntry

    resolveDepFor
    resolvePkgKeyFor
    resolvePkgVersionFor
    splitNmToAttrPath

    pinVersionsFromPLockV2
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
