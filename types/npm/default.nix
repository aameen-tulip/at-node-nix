# ============================================================================ #
#
# Merges type sub-modules into full `ytypes.Npm' collection.
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  merges = [
    "Attrs" "Enums" "Structs" "Eithers" "Strings" "Sums" "Typeclasses"
  ];

  proc = tm: acc: f:
    if builtins.elem f merges then acc // {
      ${f} = ( acc.${f} or {} ) // tm.${f};
    } else acc // { ${f} = tm.${f}; };

  typeModules = [./lifecycle.nix ./system.nix];

in builtins.foldl' ( acc: tp: let
     tm = import tp { inherit ytypes; };
   in builtins.foldl' ( proc tm ) acc ( builtins.attrNames tm )
) {} typeModules

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
