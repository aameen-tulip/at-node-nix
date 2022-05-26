{ lib ? ( import <nixpkgs> {} ).lib }:
let

  lines = lib.splitString "\n";
  readLines = file: lines ( builtins.readFile file );

  # charN 1 "hey"       ==> "h"
  # charN ( -1 ) "hey"  ==> "y"
  charN = n: str:
    let
      len = builtins.stringLength str;
      charN' = n: builtins.substring n ( n + 1 );
    in charN' ( lib.mod ( n + len ) len ) str;

  test = patt: str: ( builtins.match patt str ) != null;

  applyToLines = f: x:
    let
      inherit (builtins) isString isPath isList concatStringsSep readFile;
      asList = if ( isList x ) then x
        else if ( isString x ) then lines x
        else if ( isPath x )   then readLines x
        else throw ( "Cannot convert type ${builtins.typeOf x} to a list" +
                     " of strings" );
    in lib.concatMapStringsSep "\n" f asList;


/* -------------------------------------------------------------------------- */

  removeSlashSlashComment' = line:
    let ms = builtins.match "([^\"]*(\"[^\"]*\")*[^\"]*[^\\\"])//.*" line;
    in if ( ms == null ) then line else ( builtins.head ms );

  removePoundComment' = line:
    let ms = builtins.match "([^\"]*(\"[^\"]*\")*[^\"]*[^\\\"])#.*" line;
    in if ( ms == null ) then line else ( builtins.head ms );

  removeSlashSlashComments = applyToLines removeSlashSlashComment';
  removePoundComments = applyToLines removePoundComment';


/* -------------------------------------------------------------------------- */

  trim = str:
    let
      ws = "[ \t\n\r]";
      pr = "[^ \t\n\r]";
    in builtins.head ( builtins.match "${ws}*(${pr}+)${ws}*" str );


/* -------------------------------------------------------------------------- */

in {
  inherit lines readLines applyToLines;
  inherit removeSlashSlashComments removePoundComments;
  inherit test charN trim;
}
