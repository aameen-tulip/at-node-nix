# Dumps a giant collection of unique `{ ident -> descriptor }' pairs.
#   [{ ident = "@foo/bar"; descriptor = "^1.0.0"; } ...]
#
# FIXME: you need a way to get this to obey limits on number of fetches.
let
  packs        = import ./packuments.nix;
  lastAttrVal  = a: builtins.foldl' ( _: x: x ) null ( builtins.attrValues a );
  getLatestMan = p:
    if p ? dist-tags.latest then p.versions.${p.dist-tags.latest}
                            else lastAttrVal p.versions;
  # That's plenty of deps for us to play with, we'll leave the other fields.
  scrapePack = p: let
    joinDeps = m: ( m.dependencies or {} ) // ( m.devDependencies or {} );
    toNv     = ident: descriptor: { inherit ident descriptor; };
    nvps     = builtins.mapAttrs toNv ( joinDeps ( getLatestMan p ) );
  in builtins.attrValues nvps;
  allNvs = builtins.foldl' ( acc: p: acc ++ ( scrapePack p ) ) [] packs;
  uniq = let
    key = x: { ${builtins.hashString "sha1" ( builtins.toJSON x )} = x; };
  in builtins.foldl' ( acc: x: acc // ( key x ) ) {} allNvs;
in builtins.attrValues uniq
