let

  mkSourceTreeArgs  = builtins.functionArgs ( import ./mkSourceTree.nix );
  innerArgs         = builtins.functionArgs mkSourceTreeDrv.__innerFunction;
  procMkSrcTreeArgs = builtins.intersectAttrs mkSourceTreeArgs;

  mkSourceTreeDrv = {
    __functionArgs = mkSourceTreeArgs // innerArgs // {
      mkSourceTree = true;
    };
    __innerFunction = {
      lib
    , name ? "node_modules"
    # Result of `mkSourceTree'
    , tree ? args.mkSourceTree ( procMkSrcTreeArgs args )
    , mkNmDir # One of the `mkNmDir*' routines
    , runCommandNoCC
    , ...
    } @ args: let
      nmd = mkNmDir { inherit tree; };
      cmd = nmd.cmd + ''

        mkdir -p $out;
        installNodeModules;
      '';
    in ( runCommandNoCC name {
      node_modules_path = builtins.placeholder "out";
    } cmd ) // { passthru = { inherit tree mkNmDir; }; };
    __functor = self: self.__innerFunction;
  };

in mkSourceTreeDrv
