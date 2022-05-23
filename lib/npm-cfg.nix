{ lib ? ( import <nixpkgs> {} ).lib
}:
/**
 * NPM Config files are INI(ish), they are NOT TOML.
 * Where this is important is handling strings and file paths, which do not
 * need to be quoted in INI, but must be quoted in TOML.
 * You can use `builtins.toTOML' to create a config file, but you cannot safely
 * parse an existing config using `builtins.fromTOML'.
 * Notably any config files created with `npm config set KEY VALUE' will not
 * quote strings, so you really shouldn't try to parse them as TOML.
 *
 * I mention that the config files are "INI(ish)"; the reason for this is an
 * extension by NPM which allows arrays to be expressed as space separated
 * strings with a `KEY[] = "VALUE1 VALUE2..."' style assignment.
 * I have yet to see anywhere that this is actually used, the default NPM
 * config fields never take advantage of this, but I make not of if so that in
 * the unlikely case that some plugin/extension to NPM depends on this feature,
 * of that some random user out there assigns an array for a non-standard key
 * that any parsers written here can be prepared.
 * Additionally be aware that NPM config files never use section blocks such as
 * "[global]", rather they separate global/user level configs into separate
 * files which are processed in series.
 */
let
  npmConfigKeys = [
    "access"
    "allow-same-version"
    "also"
    "always-auth"
    "audit"
    "audit-level"
    "auth-type"
    "before"
    "bin-links"
    "browser"
    "ca"
    "cache"
    "cache-lock-retries"
    "cache-lock-stale"
    "cache-lock-wait"
    "cache-max"
    "cache-min"
    "cafile"
    "cert"
    "cidr"
    "color"
    "commit-hooks"
    "depth"
    "description"
    "dev"
    "dry-run"
    "editor"
    "engine-strict"
    "fetch-retries"
    "fetch-retry-factor"
    "fetch-retry-maxtimeout"
    "fetch-retry-mintimeout"
    "force"
    "format-package-lock"
    "fund"
    "git"
    "git-tag-version"
    "global"
    "global-style"
    "globalconfig"
    "globalignorefile"
    "group"
    "ham-it-up"
    "heading"
    "https-proxy"
    "if-present"
    "ignore-prepublish"
    "ignore-scripts"
    "init-author-email"
    "init-author-name"
    "init-author-url"
    "init-license"
    "init-module"
    "init-version"
    "json"
    "key"
    "legacy-bundling"
    "link"
    "local-address"
    "loglevel"
    "logs-max"
    "long"
    "maxsockets"
    "message"
    "metrics-registry"
    "node-options"
    "node-version"
    "noproxy"
    "offline"
    "onload-script"
    "only"
    "optional"
    "otp"
    "package-lock"
    "package-lock-only"
    "parseable"
    "prefer-offline"
    "prefer-online"
    "prefix"
    "preid"
    "production"
    "progress"
    "proxy"
    "read-only"
    "rebuild-bundle"
    "registry"
    "rollback"
    "save"
    "save-bundle"
    "save-dev"
    "save-exact"
    "save-optional"
    "save-prefix"
    "save-prod"
    "scope"
    "script-shell"
    "scripts-prepend-node-path"
    "searchexclude"
    "searchlimit"
    "searchopts"
    "searchstaleness"
    "send-metrics"
    "shell"
    "shrinkwrap"
    "sign-git-commit"
    "sign-git-tag"
    "sso-poll-frequency"
    "sso-type"
    "strict-ssl"
    "tag"
    "tag-version-prefix"
    "timing"
    "tmp"
    "umask"
    "unicode"
    "unsafe-perm"
    "update-notifier"
    "usage"
    "user"
    "user-agent"
    "userconfig"
    "version"
    "versions"
    "viewer"
  ];

  canonicalizeNpmConfigKey = iniKey:
    let lobar = builtins.replaceStrings ["-"] ["_"] iniKey;
    in "npm_config_" + ( lib.toLower lobar );

  uncanonicalizeNpmConfigKey = envKey:
    let lobar = builtins.replaceStrings ["_"] ["-"] envKey;
    in lib.removePrefix "npm_config_" ( lib.toLower lobar );

in {
  inherit npmConfigKeys;
  inherit canonicalizeNpmConfigKey uncanonicalizeNpmConfigKey;
}

/**
 * Example Config
 *   ; cli configs
 *   long = true
 *   metrics-registry = "https://registry.npmjs.org/"
 *   scope = ""
 *   user-agent = "npm/6.14.17 node/v14.19.3 darwin arm64"
 *
 *   ; userconfig /Users/alexameen/.npmrc
 *   cache = "/Users/alexameen/.npm-cache"
 *   init-module = "/Users/alexameen/.npm-init.js"
 *   prefix = "/Users/alexameen/.npm-prefix"
 *
 *   ; default values
 *   access = null
 *   allow-same-version = false
 *   also = null
 *   always-auth = false
 *   audit = true
 *   audit-level = "low"
 *   auth-type = "legacy"
 *   before = null
 *   bin-links = true
 *   browser = null
 *   ca = null
 *   ; cache = "/Users/alexameen/.npm" (overridden)
 *   cache-lock-retries = 10
 *   cache-lock-stale = 60000
 *   cache-lock-wait = 10000
 *   cache-max = null
 *   cache-min = 10
 *   cafile = undefined
 *   cert = null
 *   cidr = null
 *   color = true
 *   commit-hooks = true
 *   depth = null
 *   description = true
 *   dev = false
 *   dry-run = false
 *   editor = "vi"
 *   engine-strict = false
 *   fetch-retries = 2
 *   fetch-retry-factor = 10
 *   fetch-retry-maxtimeout = 60000
 *   fetch-retry-mintimeout = 10000
 *   force = false
 *   format-package-lock = true
 *   fund = true
 *   git = "git"
 *   git-tag-version = true
 *   global = false
 *   global-style = false
 *   globalconfig = "/Users/alexameen/.npm-prefix/etc/npmrc"
 *   globalignorefile = "/Users/alexameen/.npm-prefix/etc/npmignore"
 *   group = 20
 *   ham-it-up = false
 *   heading = "npm"
 *   https-proxy = null
 *   if-present = false
 *   ignore-prepublish = false
 *   ignore-scripts = false
 *   init-author-email = ""
 *   init-author-name = ""
 *   init-author-url = ""
 *   init-license = "ISC"
 *   init-module = "/Users/alexameen/.npm-init.js"
 *   init-version = "1.0.0"
 *   json = false
 *   key = null
 *   legacy-bundling = false
 *   link = false
 *   local-address = undefined
 *   loglevel = "notice"
 *   logs-max = 10
 *   ; long = false (overridden)
 *   maxsockets = 50
 *   message = "%s"
 *   ; metrics-registry = null (overridden)
 *   node-options = null
 *   node-version = "14.19.3"
 *   noproxy = null
 *   offline = false
 *   onload-script = null
 *   only = null
 *   optional = true
 *   otp = null
 *   package-lock = true
 *   package-lock-only = false
 *   parseable = false
 *   prefer-offline = false
 *   prefer-online = false
 *   ; prefix = "/nix/store/4dyj2k6z7qiq7ip7996inrmdzbnwcxdg-nodejs-14.19.3" (overridden)
 *   preid = ""
 *   production = false
 *   progress = true
 *   proxy = null
 *   read-only = false
 *   rebuild-bundle = true
 *   registry = "https://registry.npmjs.org/"
 *   rollback = true
 *   save = true
 *   save-bundle = false
 *   save-dev = false
 *   save-exact = false
 *   save-optional = false
 *   save-prefix = "^"
 *   save-prod = false
 *   scope = ""
 *   script-shell = null
 *   scripts-prepend-node-path = "warn-only"
 *   searchexclude = null
 *   searchlimit = 20
 *   searchopts = ""
 *   searchstaleness = 900
 *   send-metrics = false
 *   shell = "/bin/zsh"
 *   shrinkwrap = true
 *   sign-git-commit = false
 *   sign-git-tag = false
 *   sso-poll-frequency = 500
 *   sso-type = "oauth"
 *   strict-ssl = true
 *   tag = "latest"
 *   tag-version-prefix = "v"
 *   timing = false
 *   tmp = "/tmp"
 *   umask = 18
 *   unicode = true
 *   unsafe-perm = true
 *   update-notifier = true
 *   usage = false
 *   user = 501
 *   ; user-agent = "npm/{npm-version} node/{node-version} {platform} {arch} {ci}" (overridden)
 *   userconfig = "/Users/alexameen/.npmrc"
 *   version = false
 *   versions = false
 *   viewer = "man"
 */
