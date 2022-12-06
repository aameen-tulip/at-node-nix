# ============================================================================ #
#
# NOTE: this is an early draft and has limitations that make it unsuitable for
# general usage.
#
# This routine was designed for use with an NPM workspace where all projects
# are direct subdirs of `lockDir'.
#
# Limitations:
#  - `rootPath' must be a top-level dir outside of any `node_modules/' dirs.
#  - no `../' paths.
#
# Tweaking the routine to fix these limitations isn't difficult, I just haven't
# taken the time to rewrite it yet.
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

# ---------------------------------------------------------------------------- #

  focusTree = {
    treeFull
  , rootPath  # New root path, e.g. `foo' NOT a package "key".
  , metaSet   # used to lookup depInfo.  TODO: accept `depInfo' standalone.
  , ...
  } @ args: let

# ---------------------------------------------------------------------------- #

    rootKey = treeFull.${rootPath};

# ---------------------------------------------------------------------------- #

    depsOf' = {
      ident   ? null
    , version ? null
    , key ? if args ? pkey then treeFull.${args.pkey} else "${ident}/${version}"
    , dev ? false
    , ...
    } @ args: let
      di   = metaSet.${key}.depInfo;
      cond = de: ( de.runtime or false ) || ( dev && ( de.dev or false ) );
    in lib.filterAttrs ( _: cond ) di;


# ---------------------------------------------------------------------------- #

    parentNMs = pkey: let
      sp       = builtins.split "node_modules" pkey;
      dirPaths = builtins.filter builtins.isString sp;
      proc = { cwd, dirs }: p: {
        cwd  = "${cwd}${p}";
        dirs = dirs ++ ["${cwd}node_modules"];
      };
      da = builtins.foldl' proc { cwd = ""; dirs = []; } dirPaths;
    in da.dirs;

    reqsOf = { pkey, key ? treeFull.${pkey}, dev ? false }: let
      deps = depsOf' { inherit key dev; };
      filt = i: ! ( treeFull ? "${pkey}/node_modules/${i}" );
    in builtins.filter filt ( builtins.attrNames deps );

    resolve = from: ident: let
      pnms = parentNMs from;
      proc = resolved: nmdir:
        if treeFull ? "${nmdir}/${ident}" then "${nmdir}/${ident}"
                                          else resolved;
      fromParent = builtins.foldl' proc null pnms;
    in if treeFull ? "${from}/node_modules/${ident}"
       then "${from}/node_modules/${ident}"
       else fromParent;


# ---------------------------------------------------------------------------- #

    resolveClosure' = { dev, pkey }: let
      # If we want to include `dev' deps we must only do so for the initial
      # entry, not for it's deps.
      # Meaning "to focus foo, include its dev deps, but not dev deps of deps".
      target = [{ key = pkey; }];
      startSet = if ! dev then target else target ++ (
        map ( i: { key = resolve pkey i; } )
            ( builtins.attrNames ( depsOf' { inherit pkey dev; } ) )
      );
      close = builtins.genericClosure {
        inherit startSet;
        operator = { key }: let
          deps = builtins.attrNames ( depsOf' { pkey = key; } );
        in map ( i: { key = resolve key i; } ) deps;
      };
      proc = acc: { key }: acc // { ${key} = treeFull.${key}; };
    in builtins.foldl' proc {} close;


    resolveClosure = {
      __functionArgs = { dev = true; pkey = true; };
      __thunk.pkey  = rootPath;
      __processArgs = self: x:
        if builtins.isString x then {
          pkey = x; dev = x == rootPath;
        } else self.__thunk // {
          dev = ( x.pkey or self.__thunk.pkey ) == rootPath;
        } // x;
      __innerFunction = resolveClosure';
      __functor = self: x: self.__innerFunction ( self.__processArgs self x );
    };


# ---------------------------------------------------------------------------- #

    pullDownClosure' = { dev, pkey }: let
      close = resolveClosure' { inherit dev pkey; };
      proc  = { tree, drop } @ acc: p: let
        lkey = lib.yank "${pkey}/(.*)" p;
      in if ! ( lib.hasPrefix "${pkey}/" p ) then acc else acc // {
        tree = tree // { ${lkey} = close.${p}; };
        drop = if ( close ? ${lkey} ) then drop // { ${lkey} = close.${p}; }
                                      else drop;
      };
      clobbered = builtins.foldl' proc { tree = close; drop = {}; }
                                       ( builtins.attrNames close );
      top = lib.filterAttrs ( k: v: lib.hasPrefix "node_modules/" k )
                            clobbered.tree;
      rough = top // { "" = close.${pkey}; };
      pulls = lib.filterAttrs ( k: v: lib.hasPrefix "node_modules/" k ) close;
      fixClobbers = let
        proc = acc: p: let
          pdir = let
            d1 = dirOf p;
            d2 = dirOf d1;
            d  = if ( baseNameOf d1 ) != "node_modules" then d2 else d1;
          in if d == "node_modules" then "${p}/node_modules" else d;
          reqs   = reqsOf { pkey = p; };
          clobs =
            builtins.filter ( i: clobbered.drop ? ${( resolve p i )} ) reqs;
          fixSubtree = n: i: let
            p2s = lib.filterAttrs ( k: v: lib.hasPrefix "node_modules/${i}" k )
                                  close;
            pnames = builtins.attrNames p2s;
            rename = s: { "${dirOf pdir}/${s}" = pulls.${s}; };
          in n // ( builtins.foldl' ( a: rename ) {} pnames );
        in acc // ( builtins.foldl' fixSubtree {} clobs );
      in #builtins.trace ( builtins.toJSON pulls )
        ( builtins.foldl' proc rough ( builtins.attrNames pulls ) );
    in fixClobbers;


    pullDownClosure = {
      __functionArgs = { dev = true; pkey = true; };
      __thunk.pkey  = rootPath;
      __processArgs = self: x:
        if builtins.isString x then {
          pkey = x; dev = x == rootPath;
        } else self.__thunk // {
          dev = ( x.pkey or self.__thunk.pkey ) == rootPath;
        } // x;
      __innerFunction = pullDownClosure';
      __functor = self: x: self.__innerFunction ( self.__processArgs self x );
    };


# ---------------------------------------------------------------------------- #

  in assert treeFull ? ${rootPath}; {
    inherit
      resolveClosure'  resolveClosure
      pullDownClosure' pullDownClosure
    ;
    passthru = { inherit metaSet treeFull rootPath; };  # For reference
  };

  # End `focusTree' function.


# ---------------------------------------------------------------------------- #

in {
  inherit focusTree;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
