{
  plocks      = import ./plocks.nix;
  idents      = import ./idents.nix;
  packs       = import ./packuments.nix;
  descriptors = import ./descriptors.nix;

  # 130 cached so that you don't need a network connection or lock.
  # Each has between 5 and 20 versions.
  packsCached = let
    unpacked = builtins.fetchTree {
      type    = "tarball";
      url     = toString ./packuments.tar.gz;
      narHash = "sha256-dD308ceCBOXXlXfyXHG3KX7lHL8buHCaxowjcWrLdLo=";
    };
  in builtins.fromJSON ( builtins.readFile unpacked.outPath );

  nIdents = import ./nIdents.nix;
}
