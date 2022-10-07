{ name     ? "node_modules"
, tree     ? null
, nmDirCmd ? mkNmDir tree
, mkNmDir
, makeSetupHook
}: makeSetupHook { inherit name; script = nmDirCmd.cmd; }
