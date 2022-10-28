{ at-node-nix ? builtins.getFlake ( toString ../../.. )
, lib         ? at-node-nix.lib
, system      ? builtins.currentSystem
, pkgsFor     ? at-node-nix.legacyPackages.${system}
}: pkgsFor.callPackage ./pacote.nix { inherit lib system; }
