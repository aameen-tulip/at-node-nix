let
  lib.importJSON = f: builtins.fromJSON ( builtins.readFile f );
in {
  simpleWs = {
    root = {
      dir   = ./projects/simple-ws;
      pjs   = lib.importJSON ./projects/simple-ws/package.json;
      plock = lib.importJSON ./projects/simple-ws/package-lock.json;
    };
    foo = {
      dir = ./projects/simple-ws/foo;
      pjs = lib.importJSON ./projects/simple-ws/foo/package.json;
    };
    bar = {
      dir = ./projects/simple-ws/bar;
      pjs = lib.importJSON ./projects/simple-ws/bar/package.json;
    };
    baz = {
      dir = ./projects/simple-ws/baz;
      pjs = lib.importJSON ./projects/simple-ws/baz/package.json;
    };
  };
}
