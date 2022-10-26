# Also: coreutils findutils gnused
{ makeSetupHook, jq, bash, nodejs }: makeSetupHook {
  name = "pjs-util";
  deps = [jq bash nodejs];
} ./pjs-util.sh
