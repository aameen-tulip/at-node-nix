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
    packumentClosureOp
    packumentSemverClosure
  ;

# ---------------------------------------------------------------------------- #

  first = packumentClosureInit { ident = "bunyan"; version = "1.8.15"; };

  next = packumentClosureOp first;

# ---------------------------------------------------------------------------- #

  closeOld = builtins.genericClosure {
    startSet = [first];
    operator = packumentClosureOp;
  };


# ---------------------------------------------------------------------------- #

  close = packumentSemverClosure { ident = "bunyan"; version = "1.8.15"; };


# ---------------------------------------------------------------------------- #

in lib.librepl // {
  inherit
    lib

    first
    next
    closeOld
    close
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
