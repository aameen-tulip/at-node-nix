{ lib }: let

  inherit (builtins)
    attrNames
    concatLists
    concatStringsSep
    elem
    elemAt
    filter
    head
    isString
    match
    replaceStrings
    split
    stringLength
    substring
  ;


/* --------------------------------------------------------------------------- */

  # `ignore-walk' REXPs are not case sensitive, so we need to handle things like
  # "rEaDmE" explicitly.
  packageMustHaveFileNames' = "readme|copying|license|licence";
  packageMustHaveFileNames = concatStringsSep "|" [
    "[Rr][Ee][Aa][Dd][Mm][Ee]"
    "[Cc][Oo][Pp][Yy][Ii][Nn][Gg]"
    "[Ll][Ii][Cc][Ee][Nn][SsCc][Ee]"
  ];
  # XXX: A leading `@' pattern is a DSL defined by the Node.js package
  # `ignore-walk' in `/lib/index.js' as a part of their "IgnoreWalker" class.
  # It is used to escape "./" which is normally stripped from patterns.
  # This is used to force a pattern to apply to CWD and NOT subdirs.
  # It's behavior is identical to "./foo" in a `.gitignore' - they just need it
  # because the zillion tools they're taping together disagree about stripping
  # leading "./" from paths.
  #packageMustHaves = "@(${packageMustHaveFileNames'}){,.*[^~$]}";
  packageMustHaves = "\\./(${packageMustHaveFileNames'}){,.*[^~$]}";
  packageMustHavesRE = "(${packageMustHaveFileNames})(\\..*[^~$])?";

  # None of these are capture groups, they're used for optionals.
  followRE =
    "(\/node_modules\/(@[^/]+\/[^/]+|[^/]+)\/)*\/node_modules(\/@[^/]+)?";

  ignoreFiles = [".gitignore" ".npmignore"];

  defaultRules = [
    ".npmignore"
    ".gitignore"
    "**/.git"
    "**/.svn"
    "**/.hg"
    "**/CVS"
    "**/.git/**"
    "**/.svn/**"
    "**/.hg/**"
    "**/CVS/**"
    "/.lock-wscript"
    "/.wafpickle-*"
    "/build/config.gypi"
    "npm-debug.log"
    "**/.npmrc"
    ".*.swp"
    ".DS_Store"
    "**/.DS_Store/**"
    "._*"
    "**/._*/**"
    "*.orig"
    "/package-lock.json"
    "/yarn.lock"
    "/pnpm-lock.yaml"
    "/archived-packages/**"
  ];


/* --------------------------------------------------------------------------- */

  # `npm-packlist' implements a tree walker that goes to search for bundled
  # dependencies which should be packed.
  # Notably, it considers symlinked members of the `node_modules/' directory
  # as being "bundled" - this is something we really need to be careful with
  # obviously, because we symlink FUCKING EVERYTHING in `node_modules/'.
  #
  # The tree walker reads `package.json' files for all workspace members, which
  # appear to be marked for inclusion - the `files: []' members specifically.
  # Additionally the "mustHave" files for those workspace members are included.

  mustHaveFilesFromPackage = pjs: let
    browser = if pjs ? browser then ["/${pjs.browser}"] else [];
    main = if pjs ? main then ["/${pjs.main}"] else [];
    bins =
      map ( k: "/${pjs.bin.${k}}" ) ( attrNames ( pjs.bin or {} ) );
    defaults = [
      "/package.json"
      "/npm-shrinkwrap.json"
      "!/package-lock.json"
      packageMustHaves
    ];
  in defaults ++ browser ++ main ++ bins;


/* --------------------------------------------------------------------------- */

  # `rules' is a string, with the contents of a `.{npm,git}ignore' file, or
  # a path to an ignore file be parsed.
  # Lines from `package.json' `files: []' field may also be passed in, just
  # join them to a multiline string first.
  #
  # Single line strings are fine; but it makes a bit more sense to join them
  # before calling this.
  # We use `hercules-ci/gitignore.nix' to convert the `.gitignore' patterns to
  # PCRE, but that could easily be done here if we wanted to drop
  # the dependency.
  # FIXME: fork and modify `hercules-ci/gitignore.nix/rules.nix' and allow
  # a list of strings to be passed in - we waste a bit of effort joining, just
  # to have `gitignoreToRegexes' split it immediately after.
  #
  # Returns a list of tuples: [["^[^/]*" false] ["(^|.*/)bin($|/.*)" true]]
  # where `false' indicates that the file should be ignored, and `true' causes
  # the file to be packaged in the tarball.
  # This list is meant to be run later by `libgi.filterPattern' which allows a
  # prefix to be provided which should match directory that the ignores were
  # defined in - this is used to organize inheritance of ignores, and we do not
  # handle that here.
  # XXX: These patterns are case sensitive! NPM's are not, but their approach is
  # total ass because 99% of users don't expect their `.gitignore' to be
  # reinterpreted this way - it was a poor design decision and we don't
  # replicate it.
  #
  # We use case sensitive matching, and have explicitly created the REGEXPs
  # for the `packageMustHaveFilenames' so that things like "README.md" will be
  # matched, but unlike NPM, we don't treat all patterns as case insensitive.
  # This shouldn't cause issues on projects that were created by sane
  # developers; and since that behavior largely exists to support Micro$oft -
  # we really only have to look out for projects that were authored by shills.
  #
  # NOTE: The `ignore-walk' implementation `onReadIgnoreFile' takes `file' as an
  # argument to stash the results of this operation in a hash-map cache.This
  # implementation leaves that sort of thing up to the caller.
  readIgnoreFile = x: let
    rules = if isString x then x else builtins.readFile x;
  in lib.libgi.gitignoreToRegexes ni;


/* --------------------------------------------------------------------------- */

  # Entries is a list of paths to projects.
  # We use relative paths, which makes processing ignore patterns much simpler.
  onReadDir = cwd: entries: let
  in {};


/* --------------------------------------------------------------------------- */

  getPackageFiles = cwd: entries: pjs: let
    fromDir = onReadDir cwd entries;
    mustPjs = mustHaveFrilesFromPackage pjs;
    doBundle = ( pjs.bundleDependencies or false ) ||
               ( pjs.bundledDependencies or false );
    maybeNm = if doBundle && ( elem "node_modules" entries ) then
              ["node_modules"] else [];
    # FIXME: process `files: []' as gitignore patterns
  in {
  };


/* --------------------------------------------------------------------------- */

  # This is an equivalent to the `npm-packlist'/`ignore-walk' packages class
  # `class Walker : extends IgnoreWalker'.
  # Several of these fields are defined in the parent `IgnoreWalker', and a lot
  # of the wonkiness of how JS handles optional fields is handled here using
  # fallback values.
  # JFC: This entire thing is a 2,000 line long routine split across 4 projects
  # by 4 authors which ultimately amounts to:
  #   sh "ls -a -- $( cat .gitignore .npmignore; jq .files package.json; )";

  # > Scholars have long wondered:
  # >
  # > What is JavaScript doing with all of that RAM?
  # >
  # > One day, a hermit emerged from his cave after 4 months and 20 days of
  # > study and meditation on the matter.
  # >
  # > The monks gathered anxiously, in hopes that their comrade had discovered
  # > the answer to this great mystery.
  # >
  # > The hermit lost in a 1,000 yard stare gathered his focus towards his
  # > brothers, and spoke:
  # >
  # > "Y'all..." *taking a moment's pause, he rubbed his eyes in frustration*
  # > "It's all written by webshits. None of them knowing the way of PCRE."
  # >
  # > The crowd gasped - some shouted in anger, shocked by his doctrine!
  # > Some in the monastery being lifelong practicioners of JavaScript, knew
  # > this to be true; but a group of young pupils studying Electron, could not
  # > accept these truths.
  # >
  # > These students, in the dead of night, dragged the hermit into the woods.
  # > Having pinned the hermit on the ground, the students began chanting a
  # > common incantation:
  # >   enne emme penne, inne stalle emme
  # >   enne emme penne, inne stalle emme
  # >   enne emme penne, inne stalle emme
  # > As chant continued, Node.js "modules" began gathering on the chest of the
  # > hermit - forming a directory.
  # > With each passing minute, the weight of this collection grew larger and
  # > larger - crushing the hermit under it's great weight.
  # >
  # > Some say that it took the students several hours of chanting to complete
  # > this ritual, and I shudder imagining the slow agony that the
  # > hermit endured in his final moments.

  walker = opt@{
    path             ? opt.cwd
  , isSymbolicLink   ? false
  , basename         ? lib.baseName path
  , ignoreFiles      ? [".ignore"]
  , ignoreRules      ? {}
  , parent           ? null
  , root             ? opt.parent.root or path
  , result           ? parent.result or {}
  , entries          ? null
  , sawError         ? false  # You probably don't need this
  , bundled          ? []     # Only for `isProject'
  , bundledScopes    ? null   # Scrape "((@<scope>)/)?<pname>"
  , packageJsonCache ? parent.packageJsonCache or {}
  , ...
  }: let
    rootPath    = opt.parent.root or path;
    follow      = lib.test followRE rootPath;
    ignoreEmpty = false;  # this is explicitly overridden in `opt'
    # This boolen decides which output attrs should appear.
    isProject = ( parent == null ) ||
                ( isSymbolicLink && ( opt.parent.follow or false ) );
    # This is placed here to avoid putting this big ugly block above in the
    # fallback - but this was just a stylistic decisions.
    bundledScopes' = let
      scoped = filter ( lib.hasPrefix "@" ) bundled;
    in if bundledScopes != null then bundledScopes else
       map ( lib.yank' "(@[^/]+)/.*" ) scoped;
    # This sub-condition of `isProject' handles workspaces "inheritence" of
    # ignore rules.
    # This is mimicing the way that Git passes rules from a parent dir, to a
    # child dir.
    isWsContext = isProject && ( opt ? prefix ) && ( opt ? workspaces );
    wsRelpath   = lib.libpath.realpathRel' opt.prefix ( dirOf opt.path );
    rootig      = readOutOfTreeIgnoreFiles opt.prefix wsRelpath;
    childig     = map ( lib.libpath.realpathRel' opt.path ) opt.workspaces;
    wsIgnores   = if isWsContext then rootig else childig;
    # XXX: now they invoke `super.onReadIgnoreFile'


/* --------------------------------------------------------------------------- */

  in {};

in {

}
