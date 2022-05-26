{ lib ? ( import <nixpkgs> {} ).lib
, libstr ? import ../strings.nix { inherit lib; }
}:
/**
 * This certainly ranks among my most absurd tangeants.
 *
 * "Parse semver constraints" - alright but first I'm gonna write an EBNF parser
 * so that I can represent semver constraints in EBNF!
 */
let
  inherit (builtins) match elemAt head substring length stringLength attrNames;
  inherit (builtins) foldl' split isString elem filter;
  inherit (lib) hasPrefix hasSuffix unique;
  inherit (libstr) test charN trim;

  tokensLiteral = {
    tilde  = "~";
    caret  = "^";
    hyphen = " - ";
    dash   = "-";
    plus   = "+";
    dot    = ".";
    ge     = ">=";
    gt     = ">";
    le     = "<=";
    lt     = "<";
    eq     = "=";
    lor    = "||";
    glob_x = "x";
    glob_X = "X";
    star   = "*";
    ws     = " ";
    empty  = "";
  };

  tokensRE = {
    nr      = "(0|[1-9]([0-9])*)";
    part_an = "[-0-9A-Za-z]+";
  };

  # "@TOKEN@" and "&GRAMMAR&" are used to represent substitution.
  grammar = {
    ranges     = "&range& ( &lor& &range& ) *";  # Top
    lor        = "@lor@";
    range      = "&hyphen& | &simple& ( @ws@ &simple& ) * | &empty&";
    hyphen     = "&partial& @hyphen@ &partial&";
    simple     = "&primitive& | &partial& | &tilde& | &caret&";
    primitive  = "( @lt@ | @gt@ | @ge@ | @le@ | @eq@ ) &partial&";
    partial    = "&xr& ( @dot@ &xr& ( @dot@ &xr& &qualifier& ? ) ? ) ?";
    xr         = "@glob_x@ | @glob_X@ | &@star@ | &nr&";
    nr         = "@nr@";
    tilde      = "@tilde@ &partial&";
    caret      = "@caret@ &partial&";
    qualifier  = "( @dash@ &pre& ) ? ( @plus@ &build& ) ?";
    pre        = "&parts&";
    build      = "&parts&";
    parts      = "&part& ( @dot@ &part& ) *";
    part       = "&nr& | @part_an@";
  };

  cmatch = p:
    if ( ( hasPrefix "(" p ) && ( hasSuffix ")" p ) ) then p else "(${p})";

  genTokenizerLit = type: str:
    let
      isMatch = hasPrefix tokensLiteral.${type} str;
      tlen = stringLength tokensLiteral.${type};
      matched = substring 0 tlen str;
      rest = substring tlen ( stringLength str ) str;
    in if isMatch then { inherit matched rest type tlen; } else null;

  genTokenizerRE = type: str:
    let
      matches = match ( ( cmatch tokensRE.${type} ) + "(.*)" ) str;
      isMatch = matches != null;
      matched = head matches;
      tlen    = stringLength matched;
      rest    = lib.last matches;
    in if isMatch then { inherit matched rest type tlen; } else null;

  tokenizers =
    let
      lits = map genTokenizerLit ( attrNames tokensLiteral );
      res  = map genTokenizerRE ( attrNames tokensLiteral );
    in lits // res;

  # Given a list of tokenizers, and a string - RUNNIT!
  # Produces a `{ matched : string, type : enum, tlen : uint }' result.
  tokenize = tns: str:
    let
      runTokenizer = acc: t:
        let
          rsl = t str;
          # Pretty naive accumulator that prefers consuming longer tokens.
          shouldReplace = ( acc == null ) || ( acc.tlen < rsl.tlen );
        in if ( ( rsl == null ) || shouldReplace ) then acc else rsl;
    in foldl' runTokenizer null tns;

  directTokenizersForGrammar = g:
    let
      matches = split "@" g;
      tnames = attrNames tokenizers;
      keep = x: ( isString x ) && ( elem x tnames );
    in filter keep matches;

  directSubgrammars = g:
    let
      matches = split "&" g;
      gnames = attrNames grammars;
      keep = x: ( isString x ) && ( elem x gnames );
    in filter keep matches;

  subgrammars = g:
    let dsubs = directSubgrammars g;
    in unique ( dsubs ++ ( map subgrammars dsubs ) );

  tokenizersForGrammar = g:
    let collectTokenizers = acc: x: acc ++ ( directTokenizersForGrammar x );
    in unique ( foldl' collectTokenizers ( subgrammars g ) );

  scanG = g: str:


in rec {

}
