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
    packumentClosureOp
  ;

# ---------------------------------------------------------------------------- #

  first = packumentClosureOp { ident = "bunyan"; version = "1.8.15"; };

  next = prev: let
    proc = { final, runs }: satisfied: let
      key = toString satisfied;
      n   = final key;
    in {
      runs = runs // { ${key} = removeAttrs n ["final"]; };
      final = n.final // {
        packumenter = n.final.packumenter // {
          packuments =
            final.packumenter.packuments // n.final.packumenter.packuments;
        };
      };
    };
    start = {
      inherit (prev) final;
      runs.${prev.key} = removeAttrs prev ["final"];
    };
  in builtins.foldl' proc start ( builtins.attrValues prev.sats );


# ---------------------------------------------------------------------------- #

in next first


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
