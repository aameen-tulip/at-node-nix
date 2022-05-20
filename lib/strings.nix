{ lib ? ( import <nixpkgs> {} ).lib }:
let

  lines = lib.splitString "\n";
  readLines = file: lines ( builtins.readFile file );

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

in {
  inherit lines readLines applyToLines;
  inherit removeSlashSlashComments removePoundComments;
}
