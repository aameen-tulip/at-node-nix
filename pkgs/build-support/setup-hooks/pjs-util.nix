# Also: coreutils findutils gnused
{ makeSetupHook, jq, bash }: makeSetupHook {
  name = "pjs-util";
  deps = [jq bash];
} ./pjs-util.sh
