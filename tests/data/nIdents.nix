let
  all   = import ./idents.nix;
  lib = {
    min  = a: b: if a < b then a else b;
    take = lst: n: let
      count = builtins.length lst;
    in builtins.genList ( i: builtins.elemAt lst i ) ( min count n );
  };
in take all
