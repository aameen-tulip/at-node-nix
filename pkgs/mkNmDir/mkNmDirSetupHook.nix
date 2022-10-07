{ name     ? "node_modules"
, tree     ? null
, nmDirCmd ? mkNmDir tree
, mkNmDir
, writeScript
}: writeScript "${name}-hook" ( nmDirCmd.cmd or ( toString nmDirCmd ) )
