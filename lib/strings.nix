{ lib }:
let

  lines = lib.splitString "\n";

  # `ak-nix.lib' also carries a `libstr' which we have to refer to here.
  applyToLines = f: x: let
    inherit (builtins) isString isPath isList concatStringsSep readFile;
    asList = if ( isList x ) then x
      else if ( isString x ) then lines x
      else if ( isPath x )   then lib.readLines x
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

  trim = str: let
    ws = "[ \t\n\r]";
    pr = "[^ \t\n\r]";
  in builtins.head ( builtins.match "${ws}*(${pr}+)${ws}*" str );


/* -------------------------------------------------------------------------- */

  # FIXME: move to pkginfo or parse?
  renamePkgAtVersion = n: let
    m = builtins.match "@([^/]+)/([^@]+)@(.*)" n;
    y = builtins.elemAt m;
  in if ( builtins.substring 0 1 n ) == "@"
     then "${y 0}--${y 1}--${y 2}"
     else ( builtins.replaceStrings ["@"] ["--"] n );


/* -------------------------------------------------------------------------- */

in {
  inherit lines applyToLines trim;
  inherit removeSlashSlashComments removePoundComments;
}
