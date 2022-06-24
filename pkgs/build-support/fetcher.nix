{ lib
, fetchurl
, fetchgit
, fetchFromGithub
, fetchzip
}: let
  inherit (builtins) fetchurl;

  plockEntryHashAttr = entry: let
    integrity2Sha = integrity: let
      m = builtins.match "(sha(512|256|1))-(.*)" integrity;
      shaSet = { ${builtins.head m} = ${builtins.elemAt m 2}; };
    in if m == null then { hash = integrity; } else shaSet;
    fromInteg = integrity2Sha entry.integrity;
  in if entry ? integrity then fromInteg else
     if entry ? sha1      then { inherit (entry) sha1; } else {};

  per2fetchArgs = { resolved, ... }@entry: let
    nha = plockEntryHashAttr entry;
    nfu = { url = resolved; } // nha;
  in

in null
