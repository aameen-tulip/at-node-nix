{ lib ? ( getFlake "nixpkgs" ).lib }: let

  inherit (lib) options types;

  fundingType = with types; oneOf [
    string
    ( attrsOf string )
    ( listOf funding )
  ];

  pathLike = with types; either string path;

  # Either a semver string or a fetcher URI.
  depType = types.string;

in {
  # 214 char max. lowercase.
  # "." and "_" can only be used as the first character of a scoped package.
  # URL safe characters only.
  name = types.string;

  # semver string
  version = types.string;
  description = types.singleLineStr;
  keywords = types.listOf types.string;

  # url
  homepage = types.string;

  # bugs (tracker)
  bugs = types.string;

  # `lib.license' probably has a checker for this.
  license = types.string;

  # Fields are { name, email, url } or "${name} <${email}> (${url})"
  person = with types; loaOf ( either string ( attrsOf string ) );

  # This one is fucky. It's recursively defined:
  #
  #   FUNDING  ::=  URL | { TYPE, URL } | [FUNDING]
  funding = fundingType;

  # Globs are fine.
  # Paths MUST be relative.
  # Always included: package.json, README, LICEN[CS]E and `main' field
  # Always ignored: .git CVS .svn .hg .lock-wscript .wafpickle-N .*.swp ._*
  # .DS_Store npm-debug.log .npmrc node_modules config.gypi *.orig
  # package-lock.json
  files = types.listOf pathLike;

  # Relative path to entry such as `index.js'
  # Mutually exclusive with `browser' field.
  main = pathLike;

  # Indicates that Node.js isn't used, naming an alternate.  Ex: "window"
  browser = types.string;

  bin = types.either pathLike ( types.loaOf pathLike );
  man = types.either pathLike ( types.loaOf pathLike );
  # The fields at the top level must be "bin" or "man".
  directories = types.loaOf ( types.either pathLike ( types.loaOf pathLike ) );

  # Attrs fields are `{ type, url, directory }'
  # URLs use the `npm install' URI rules.
  repository = with types; either string ( attrsOf string );

  scripts = types.attrsOf types.string;

  # All values must be strings
  config = types.attrs;

  dependencies = types.attrsOf depType;
  devDependencies = types.attrsOf depType;
  optionalDependencies = types.attrsOf depType;
  peerDependencies = types.attrsOf depType;
  # FIXME: typecheck sub-fields
  peerDependenciesMeta = types.attrs;
  bundledDependencies = types.attrsOf depType;

  # FIXME: enum "node", and other JavaScript runtimes.
  engines = types.string;

  # FIXME: enum
  os = types.string;

  # FIXME: enum
  cpu = types.string;

  private = types.bool;

  # FIXME: typecheck attrs
  publishConfig = types.attrs;

  workspaces = types.attrsOf pathLike;
}
