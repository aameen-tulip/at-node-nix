{ nix-gitignore }:
rec {
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
}
