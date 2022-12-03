# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ ytypes }: let

  yt = ytypes // ytypes.Core // ytypes.Prim;

# ---------------------------------------------------------------------------- #

  Attrs.plock_shallow =
    yt.restrict "plock[npm]" ( _: true ) ( yt.attrs yt.any );

  Attrs.plock_supports_v1 = let
    cond = x: builtins.elem x.lockfileVersion [1 2];
  in yt.restrict "supports_v1" cond yt.NpmLock.Attrs.plock_shallow;

  Attrs.plock_supports_v3 = let
    cond = x: builtins.elem x.lockfileVersion [2 3];
  in yt.restrict "supports_v3" cond yt.NpmLock.Attrs.plock_shallow;


# ---------------------------------------------------------------------------- #

in {
  inherit Attrs;
  inherit (Attrs)
    plock_shallow
    plock_supports_v1
    plock_supports_v3
  ;
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
