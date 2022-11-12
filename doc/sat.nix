# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

let

  # at-node-nix = builtins.getFlake "github:aameen-tulip/at-node-nix";
  at-node-nix = builtins.getFlake ( toString ../. );
  inherit (at-node-nix) lib;
  inherit (lib)
    packumenter
  ;
  inherit (lib.libsat)
    getDepSats
    packumentClosureInit
  ;

# ---------------------------------------------------------------------------- #

  first = packumentClosureInit { ident = "bunyan"; version = "1.8.15"; };

  next = prev: let
    proc = { passthru, runs }: satisfied: let
      key = toString satisfied;
      n   = passthru.final key;
    in {
      runs = runs // { ${key} = removeAttrs n ["final"]; };
      passthru = n.passthru // {
        conds = passthru.conds // n.passthru.conds;
        final = n.passthru.final // {
          packumenter = n.passthru.final.packumenter // {
            packuments =
              passthru.final.packumenter.packuments //
              n.passthru.final.packumenter.packuments;
          };
        };
      };
    };
    start = {
      inherit (prev) passthru;
      runs.${prev.key} = removeAttrs prev ["final"];
    };
  in builtins.foldl' proc start ( builtins.attrValues prev.sats );


# ---------------------------------------------------------------------------- #

in ( next first ) // { inherit lib; }


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
