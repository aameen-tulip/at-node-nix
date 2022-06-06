{ nixpkgs       ? builtins.getFlake "nixpkgs"
, system        ? builtins.currentSystem
, nix-gitignore ? nixpkgs.legacyPackages.${system}.nix-gitignore
, lib           ? nixpkgs.lib
}:
let
  inherit (lib.sources) cleanSource cleanSourceWith;
  inherit (nix-gitignore) gitignoreSourcePure gitignoreSource;
in rec {

  /* ------------------------------------------------------------------------ */

  # Preserve only top level Node.js package information files.
  nodePackageFiles = [
    "package.json"
    "package-lock.json"
    "yarn.lock"
  ];

  # NOTE: With gitignore syntax you must add "**/*.<EXT>"
  nodeExtensions = [
    "js" "ts"    # The genuine article
    "jsx" "tsx"  # React files
    "json"
    "md"         # For README.md files
  ];

  webExtensions = ["html" "css" "scss"];

  filterNodeSources =
    { src
    , nodeExtensions   ? nodeExtensions
    , extraExtensions  ? []
    , nodePackageFiles ? nodePackageFiles
    , extraFiles       ? []
    , extraIgnoreLines ? []
    }:
    let
      baseIgnoreList = ["*"] ++ extraIgnoreLines;
      keepNodeExtensions =
        map ( ext: "!**/*." + ext ) ( nodeExtensions ++ extraExtensions );
      keepFiles = map ( file: "!" + file ) ( nodePackageFiles ++ extraFiles );
      ignoreList = baseIgnoreList ++ keepNodeExtensions ++ keepFiles ++ [];
    in nix-gitignore.gitignoreSourcePure ignoreList src;

  # Allows all of the overrides available to `filterNodeSources', but
  # `nodeExtensions' is always cleared.
  filterNodePackageFiles' = args:
    filterNodeSources ( args // { nodeExtensions = []; } );

  # An optimized filter that doesn't process overrides.
  filterNodePackageFiles = src:
    nix-gitignore.gitignoreSourcePure
      ( ["*"] ++ ( map ( file: "!" + file ) nodePackageFiles ) ) src;


  /* ------------------------------------------------------------------------ */

  # Remove `*/.yarn/cache' directories.
  cleanYarnCacheFilter = name: type:
    ! ( ( type == "directory" )                       &&
        ( ( baseNameOf name ) == "cache" )            &&
        ( ( baseNameOf ( dirOf name ) ) == ".yarn" )
      );

  # Remove `*/node_modules' directories
  cleanNodeModulesFilter = name: type:
    ! ( ( type == "directory" ) && ( ( baseNameOf name ) == "node_modules" ) );

  # Clean cached Node.js artifacts, and apply Nix's default clean routine.
  cleanNodeSource = src:
    cleanSourceWith {
      filter = cleanYarnCacheFilter;
      src = cleanSourceWith {
        filter = cleanNodeModulesFilter;
        src = cleanSource src;
      };
    };


  /* ------------------------------------------------------------------------ */
}
