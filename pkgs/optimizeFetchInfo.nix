# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib
, urlFetchInfo
, pure
}: let

# ---------------------------------------------------------------------------- #

  _optimizeFetchInfo' = { pure, ... } @ fenv: { url, ... } @ fetchInfo: let
    forImpure = urlFetchInfo url;
    forPure   = throw "TODO";
    opt = if pure then forPure else forImpure;
  in if ( ( fetchInfo.type or null ) == "tarball" ) && ( fetchInfo ? narHash )
     then fetchInfo
     else opt;


# ---------------------------------------------------------------------------- #

  optimizeFetchInfo' = { pure, ... } @ fenv: {
    __functionMeta = {
      name = "optimizeFetchInfo";
      from = "at-node-nix#pkgs";
      properties = { inherit pure; ifd = true; };
    };
    # TODO: genericUrlArgs
    __functionArgs = {
      fetchInfo = true;
      url       = true;
      narHash   = true;
      type      = true;
      unpack    = true;
      hash      = true;
    };
    __innerFunction = _optimizeFetchInfo' fenv;
    __processArgs   = self: x: x.fetchInfo or x;
    __functor       = self: x: let
      args      = self.__processArgs self x;
      fetchInfo = self.__innerFunction args;
      forField  = if x ? __update then x.__update { inherit fetchInfo; } else
                  x // { inherit fetchInfo; };
    in if x ? fetchInfo then forField else fetchInfo;
  };

# ---------------------------------------------------------------------------- #

  optimizeFetchInfoSet' = { pure, ... } @ fenv: ents: let
    shouldRun = x:
      if ! ( x ? fetchInfo ) then x ? url else
      ( x.fetchInfo ? url ) && ( ( x.fetchInfo ? unpack ) ||
                                 ( builtins.elem ( x.fetchInfo.type or null ) [
                                     "tarball" "file"
                                   ] ) );
    optfi  = optimizeFetchInfo' { inherit pure; };
    proc   = key: ent: if shouldRun ent then optfi ent else ent;
    forExt = ents.__extend ( _: builtins.mapAttrs proc );
  in if lib.ytypes.Typeclasses.extensible.check ents then forExt else
     builtins.mapAttrs proc ents;


# ---------------------------------------------------------------------------- #

in {

  optimizeFetchInfo' = {
    __functionArgs.pure = true;
    __functor = self: lib.callWith { inherit pure; } optimizeFetchInfo';
  };
  optimizeFetchInfo = optimizeFetchInfo' { inherit pure; };

  optimizeFetchInfoSet' = {
    __functionArgs.pure = true;
    __functor = self: lib.callWith { inherit pure; } optimizeFetchInfoSet';
  };
  optimizeFetchInfoSet = optimizeFetchInfoSet' { inherit pure; };

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
