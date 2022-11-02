# THIS FILE WAS GENERATED. Manual edits may be lost.
# Deserialze with:  lib.libmeta.metaSetFromSerial
# Regen with: nix run --impure at-node-nix#genMeta -- --prod pacote@13.3.0
{
  "@gar/promisify/1.1.3" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "@gar/promisify";
    key = "@gar/promisify/1.1.3";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-k2Ty1JcVojjJFwrg/ThKi2ujJ7XNLYaFGNB/bWT9wGR+oSMJHMa5w+CUq6p/pVrKeNNgA7pCqEcjSnHVoqJQFw==";
      sha512 = "k2Ty1JcVojjJFwrg/ThKi2ujJ7XNLYaFGNB/bWT9wGR+oSMJHMa5w+CUq6p/pVrKeNNgA7pCqEcjSnHVoqJQFw==";
      type = "tarball";
      url = "https://registry.npmjs.org/@gar/promisify/-/promisify-1.1.3.tgz";
    };
    version = "1.1.3";
  };
  "@npmcli/fs/1.1.1" = {
    depInfo = {
      "@gar/promisify" = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/fs";
    key = "@npmcli/fs/1.1.1";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-8KG5RD0GVP4ydEzRn/I4BNDuxDtqVbOdm8675T49OIG/NGhaK0pjPX7ZcDlvKYbA+ulvVK3ztfcF4uBdOxuJbQ==";
      sha512 = "8KG5RD0GVP4ydEzRn/I4BNDuxDtqVbOdm8675T49OIG/NGhaK0pjPX7ZcDlvKYbA+ulvVK3ztfcF4uBdOxuJbQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/fs/-/fs-1.1.1.tgz";
    };
    version = "1.1.1";
  };
  "@npmcli/fs/2.1.2" = {
    depInfo = {
      "@gar/promisify" = {
        descriptor = "^1.1.3";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/fs";
    key = "@npmcli/fs/2.1.2";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-yOJKRvohFOaLqipNtwYB9WugyZKhC/DZC4VYPmpaCzDBrA8YpK3qHZ8/HGscMnE4GqbkLNuVcCnxkeQEdGt6LQ==";
      sha512 = "yOJKRvohFOaLqipNtwYB9WugyZKhC/DZC4VYPmpaCzDBrA8YpK3qHZ8/HGscMnE4GqbkLNuVcCnxkeQEdGt6LQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/fs/-/fs-2.1.2.tgz";
    };
    version = "2.1.2";
  };
  "@npmcli/git/3.0.2" = {
    depInfo = {
      "@npmcli/promise-spawn" = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      lru-cache = {
        descriptor = "^7.4.4";
        runtime = true;
      };
      mkdirp = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      npm-pick-manifest = {
        descriptor = "^7.0.0";
        runtime = true;
      };
      proc-log = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      promise-inflight = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      promise-retry = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
      which = {
        descriptor = "^2.0.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/git";
    key = "@npmcli/git/3.0.2";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-CAcd08y3DWBJqJDpfuVL0uijlq5oaXaOJEKHKc4wqrjd00gkvTZB+nFuLn+doOOKddaQS9JfqtNoFCO2LCvA3w==";
      sha512 = "CAcd08y3DWBJqJDpfuVL0uijlq5oaXaOJEKHKc4wqrjd00gkvTZB+nFuLn+doOOKddaQS9JfqtNoFCO2LCvA3w==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/git/-/git-3.0.2.tgz";
    };
    version = "3.0.2";
  };
  "@npmcli/installed-package-contents/1.0.7" = {
    bin = {
      installed-package-contents = "index.js";
    };
    depInfo = {
      npm-bundled = {
        descriptor = "^1.1.1";
        runtime = true;
      };
      npm-normalize-package-bin = {
        descriptor = "^1.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "@npmcli/installed-package-contents";
    key = "@npmcli/installed-package-contents/1.0.7";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-9rufe0wnJusCQoLpV9ZPKIVP55itrM5BxOXs10DmdbRfgWtHy1LDyskbwRnBghuB0PrF7pNPOqREVtpz4HqzKw==";
      sha512 = "9rufe0wnJusCQoLpV9ZPKIVP55itrM5BxOXs10DmdbRfgWtHy1LDyskbwRnBghuB0PrF7pNPOqREVtpz4HqzKw==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/installed-package-contents/-/installed-package-contents-1.0.7.tgz";
    };
    version = "1.0.7";
  };
  "@npmcli/move-file/1.1.2" = {
    depInfo = {
      mkdirp = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/move-file";
    key = "@npmcli/move-file/1.1.2";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-1SUf/Cg2GzGDyaf15aR9St9TWlb+XvbZXWpDx8YKs7MLzMH/BCeopv+y9vzrzgkfykCGuWOlSu3mZhj2+FQcrg==";
      sha512 = "1SUf/Cg2GzGDyaf15aR9St9TWlb+XvbZXWpDx8YKs7MLzMH/BCeopv+y9vzrzgkfykCGuWOlSu3mZhj2+FQcrg==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/move-file/-/move-file-1.1.2.tgz";
    };
    version = "1.1.2";
  };
  "@npmcli/move-file/2.0.1" = {
    depInfo = {
      mkdirp = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/move-file";
    key = "@npmcli/move-file/2.0.1";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-mJd2Z5TjYWq/ttPLLGqArdtnC74J6bOzg4rMDnN+p1xTacZ2yPRCk2y0oSWQtygLR9YVQXgOcONrwtnk3JupxQ==";
      sha512 = "mJd2Z5TjYWq/ttPLLGqArdtnC74J6bOzg4rMDnN+p1xTacZ2yPRCk2y0oSWQtygLR9YVQXgOcONrwtnk3JupxQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/move-file/-/move-file-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "@npmcli/node-gyp/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/node-gyp";
    key = "@npmcli/node-gyp/2.0.0";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-doNI35wIe3bBaEgrlPfdJPaCpUR89pJWep4Hq3aRdh6gKazIVWfs0jHttvSSoq47ZXgC7h73kDsUl8AoIQUB+A==";
      sha512 = "doNI35wIe3bBaEgrlPfdJPaCpUR89pJWep4Hq3aRdh6gKazIVWfs0jHttvSSoq47ZXgC7h73kDsUl8AoIQUB+A==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/node-gyp/-/node-gyp-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "@npmcli/promise-spawn/3.0.0" = {
    depInfo = {
      infer-owner = {
        descriptor = "^1.0.4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/promise-spawn";
    key = "@npmcli/promise-spawn/3.0.0";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-s9SgS+p3a9Eohe68cSI3fi+hpcZUmXq5P7w0kMlAsWVtR7XbK3ptkZqKT2cK1zLDObJ3sR+8P59sJE0w/KTL1g==";
      sha512 = "s9SgS+p3a9Eohe68cSI3fi+hpcZUmXq5P7w0kMlAsWVtR7XbK3ptkZqKT2cK1zLDObJ3sR+8P59sJE0w/KTL1g==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/promise-spawn/-/promise-spawn-3.0.0.tgz";
    };
    version = "3.0.0";
  };
  "@npmcli/run-script/3.0.3" = {
    depInfo = {
      "@npmcli/node-gyp" = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      "@npmcli/promise-spawn" = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      node-gyp = {
        descriptor = "^8.4.1";
        runtime = true;
      };
      read-package-json-fast = {
        descriptor = "^2.0.3";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "@npmcli/run-script";
    key = "@npmcli/run-script/3.0.3";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ZXL6qgC5NjwfZJ2nET+ZSLEz/PJgJ/5CU90C2S66dZY4Jw73DasS4ZCXuy/KHWYP0imjJ4VtA+Gebb5BxxKp9Q==";
      sha512 = "ZXL6qgC5NjwfZJ2nET+ZSLEz/PJgJ/5CU90C2S66dZY4Jw73DasS4ZCXuy/KHWYP0imjJ4VtA+Gebb5BxxKp9Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/@npmcli/run-script/-/run-script-3.0.3.tgz";
    };
    version = "3.0.3";
  };
  "@tootallnate/once/1.1.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "@tootallnate/once";
    key = "@tootallnate/once/1.1.2";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-RbzJvlNzmRq5c3O09UipeuXno4tA1FE6ikOjxZK0tuxVv3412l64l5t1W5pj4+rJq9vpkm/kwiR07aZXnsKPxw==";
      sha512 = "RbzJvlNzmRq5c3O09UipeuXno4tA1FE6ikOjxZK0tuxVv3412l64l5t1W5pj4+rJq9vpkm/kwiR07aZXnsKPxw==";
      type = "tarball";
      url = "https://registry.npmjs.org/@tootallnate/once/-/once-1.1.2.tgz";
    };
    version = "1.1.2";
  };
  "@tootallnate/once/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "@tootallnate/once";
    key = "@tootallnate/once/2.0.0";
    scoped = true;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-XCuKFP5PS55gnMVu3dty8KPatLqUoy/ZYzDzAGCQ8JNFCkLXzmI7vNHCR+XpbZaMWQK/vQubr7PkYq8g470J/A==";
      sha512 = "XCuKFP5PS55gnMVu3dty8KPatLqUoy/ZYzDzAGCQ8JNFCkLXzmI7vNHCR+XpbZaMWQK/vQubr7PkYq8g470J/A==";
      type = "tarball";
      url = "https://registry.npmjs.org/@tootallnate/once/-/once-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  __meta = {
    fromType = "package-lock.json(v3)";
    rootKey = "pacote/13.3.0";
    trees = {
      prod = {
        "node_modules/@gar/promisify" = "@gar/promisify/1.1.3";
        "node_modules/@npmcli/fs" = "@npmcli/fs/2.1.2";
        "node_modules/@npmcli/git" = "@npmcli/git/3.0.2";
        "node_modules/@npmcli/installed-package-contents" = "@npmcli/installed-package-contents/1.0.7";
        "node_modules/@npmcli/move-file" = "@npmcli/move-file/2.0.1";
        "node_modules/@npmcli/node-gyp" = "@npmcli/node-gyp/2.0.0";
        "node_modules/@npmcli/promise-spawn" = "@npmcli/promise-spawn/3.0.0";
        "node_modules/@npmcli/run-script" = "@npmcli/run-script/3.0.3";
        "node_modules/@tootallnate/once" = "@tootallnate/once/1.1.2";
        "node_modules/abbrev" = "abbrev/1.1.1";
        "node_modules/agent-base" = "agent-base/6.0.2";
        "node_modules/agentkeepalive" = "agentkeepalive/4.2.1";
        "node_modules/aggregate-error" = "aggregate-error/3.1.0";
        "node_modules/ansi-regex" = "ansi-regex/5.0.1";
        "node_modules/aproba" = "aproba/2.0.0";
        "node_modules/are-we-there-yet" = "are-we-there-yet/3.0.1";
        "node_modules/balanced-match" = "balanced-match/1.0.2";
        "node_modules/brace-expansion" = "brace-expansion/2.0.1";
        "node_modules/builtins" = "builtins/5.0.1";
        "node_modules/cacache" = "cacache/16.1.3";
        "node_modules/chownr" = "chownr/2.0.0";
        "node_modules/clean-stack" = "clean-stack/2.2.0";
        "node_modules/color-support" = "color-support/1.1.3";
        "node_modules/concat-map" = "concat-map/0.0.1";
        "node_modules/console-control-strings" = "console-control-strings/1.1.0";
        "node_modules/debug" = "debug/4.3.4";
        "node_modules/delegates" = "delegates/1.0.0";
        "node_modules/depd" = "depd/1.1.2";
        "node_modules/emoji-regex" = "emoji-regex/8.0.0";
        "node_modules/encoding" = "encoding/0.1.13";
        "node_modules/env-paths" = "env-paths/2.2.1";
        "node_modules/err-code" = "err-code/2.0.3";
        "node_modules/fs-minipass" = "fs-minipass/2.1.0";
        "node_modules/fs.realpath" = "fs.realpath/1.0.0";
        "node_modules/function-bind" = "function-bind/1.1.1";
        "node_modules/gauge" = "gauge/4.0.4";
        "node_modules/glob" = "glob/8.0.3";
        "node_modules/graceful-fs" = "graceful-fs/4.2.10";
        "node_modules/has" = "has/1.0.3";
        "node_modules/has-unicode" = "has-unicode/2.0.1";
        "node_modules/hosted-git-info" = "hosted-git-info/5.2.1";
        "node_modules/http-cache-semantics" = "http-cache-semantics/4.1.0";
        "node_modules/http-proxy-agent" = "http-proxy-agent/4.0.1";
        "node_modules/https-proxy-agent" = "https-proxy-agent/5.0.1";
        "node_modules/humanize-ms" = "humanize-ms/1.2.1";
        "node_modules/iconv-lite" = "iconv-lite/0.6.3";
        "node_modules/ignore-walk" = "ignore-walk/5.0.1";
        "node_modules/imurmurhash" = "imurmurhash/0.1.4";
        "node_modules/indent-string" = "indent-string/4.0.0";
        "node_modules/infer-owner" = "infer-owner/1.0.4";
        "node_modules/inflight" = "inflight/1.0.6";
        "node_modules/inherits" = "inherits/2.0.4";
        "node_modules/ip" = "ip/2.0.0";
        "node_modules/is-core-module" = "is-core-module/2.11.0";
        "node_modules/is-fullwidth-code-point" = "is-fullwidth-code-point/3.0.0";
        "node_modules/is-lambda" = "is-lambda/1.0.1";
        "node_modules/isexe" = "isexe/2.0.0";
        "node_modules/json-parse-even-better-errors" = "json-parse-even-better-errors/2.3.1";
        "node_modules/jsonparse" = "jsonparse/1.3.1";
        "node_modules/lru-cache" = "lru-cache/7.14.0";
        "node_modules/make-fetch-happen" = "make-fetch-happen/9.1.0";
        "node_modules/make-fetch-happen/node_modules/@npmcli/fs" = "@npmcli/fs/1.1.1";
        "node_modules/make-fetch-happen/node_modules/@npmcli/move-file" = "@npmcli/move-file/1.1.2";
        "node_modules/make-fetch-happen/node_modules/brace-expansion" = "brace-expansion/1.1.11";
        "node_modules/make-fetch-happen/node_modules/cacache" = "cacache/15.3.0";
        "node_modules/make-fetch-happen/node_modules/glob" = "glob/7.2.3";
        "node_modules/make-fetch-happen/node_modules/lru-cache" = "lru-cache/6.0.0";
        "node_modules/make-fetch-happen/node_modules/minimatch" = "minimatch/3.1.2";
        "node_modules/make-fetch-happen/node_modules/ssri" = "ssri/8.0.1";
        "node_modules/make-fetch-happen/node_modules/unique-filename" = "unique-filename/1.1.1";
        "node_modules/make-fetch-happen/node_modules/unique-slug" = "unique-slug/2.0.2";
        "node_modules/minimatch" = "minimatch/5.1.0";
        "node_modules/minipass" = "minipass/3.3.4";
        "node_modules/minipass-collect" = "minipass-collect/1.0.2";
        "node_modules/minipass-fetch" = "minipass-fetch/1.4.1";
        "node_modules/minipass-flush" = "minipass-flush/1.0.5";
        "node_modules/minipass-json-stream" = "minipass-json-stream/1.0.1";
        "node_modules/minipass-pipeline" = "minipass-pipeline/1.2.4";
        "node_modules/minipass-sized" = "minipass-sized/1.0.3";
        "node_modules/minizlib" = "minizlib/2.1.2";
        "node_modules/mkdirp" = "mkdirp/1.0.4";
        "node_modules/ms" = "ms/2.1.2";
        "node_modules/negotiator" = "negotiator/0.6.3";
        "node_modules/node-gyp" = "node-gyp/8.4.1";
        "node_modules/node-gyp/node_modules/brace-expansion" = "brace-expansion/1.1.11";
        "node_modules/node-gyp/node_modules/glob" = "glob/7.2.3";
        "node_modules/node-gyp/node_modules/minimatch" = "minimatch/3.1.2";
        "node_modules/nopt" = "nopt/5.0.0";
        "node_modules/normalize-package-data" = "normalize-package-data/4.0.1";
        "node_modules/npm-bundled" = "npm-bundled/1.1.2";
        "node_modules/npm-install-checks" = "npm-install-checks/5.0.0";
        "node_modules/npm-normalize-package-bin" = "npm-normalize-package-bin/1.0.1";
        "node_modules/npm-package-arg" = "npm-package-arg/9.1.2";
        "node_modules/npm-packlist" = "npm-packlist/5.1.3";
        "node_modules/npm-packlist/node_modules/npm-bundled" = "npm-bundled/2.0.1";
        "node_modules/npm-packlist/node_modules/npm-normalize-package-bin" = "npm-normalize-package-bin/2.0.0";
        "node_modules/npm-pick-manifest" = "npm-pick-manifest/7.0.2";
        "node_modules/npm-pick-manifest/node_modules/npm-normalize-package-bin" = "npm-normalize-package-bin/2.0.0";
        "node_modules/npm-registry-fetch" = "npm-registry-fetch/13.3.1";
        "node_modules/npm-registry-fetch/node_modules/@tootallnate/once" = "@tootallnate/once/2.0.0";
        "node_modules/npm-registry-fetch/node_modules/http-proxy-agent" = "http-proxy-agent/5.0.0";
        "node_modules/npm-registry-fetch/node_modules/make-fetch-happen" = "make-fetch-happen/10.2.1";
        "node_modules/npm-registry-fetch/node_modules/minipass-fetch" = "minipass-fetch/2.1.2";
        "node_modules/npm-registry-fetch/node_modules/socks-proxy-agent" = "socks-proxy-agent/7.0.0";
        "node_modules/npmlog" = "npmlog/6.0.2";
        "node_modules/once" = "once/1.4.0";
        "node_modules/p-map" = "p-map/4.0.0";
        "node_modules/path-is-absolute" = "path-is-absolute/1.0.1";
        "node_modules/proc-log" = "proc-log/2.0.1";
        "node_modules/promise-inflight" = "promise-inflight/1.0.1";
        "node_modules/promise-retry" = "promise-retry/2.0.1";
        "node_modules/read-package-json" = "read-package-json/5.0.2";
        "node_modules/read-package-json-fast" = "read-package-json-fast/2.0.3";
        "node_modules/read-package-json/node_modules/npm-normalize-package-bin" = "npm-normalize-package-bin/2.0.0";
        "node_modules/readable-stream" = "readable-stream/3.6.0";
        "node_modules/retry" = "retry/0.12.0";
        "node_modules/rimraf" = "rimraf/3.0.2";
        "node_modules/rimraf/node_modules/brace-expansion" = "brace-expansion/1.1.11";
        "node_modules/rimraf/node_modules/glob" = "glob/7.2.3";
        "node_modules/rimraf/node_modules/minimatch" = "minimatch/3.1.2";
        "node_modules/safe-buffer" = "safe-buffer/5.2.1";
        "node_modules/safer-buffer" = "safer-buffer/2.1.2";
        "node_modules/semver" = "semver/7.3.8";
        "node_modules/semver/node_modules/lru-cache" = "lru-cache/6.0.0";
        "node_modules/set-blocking" = "set-blocking/2.0.0";
        "node_modules/signal-exit" = "signal-exit/3.0.7";
        "node_modules/smart-buffer" = "smart-buffer/4.2.0";
        "node_modules/socks" = "socks/2.7.1";
        "node_modules/socks-proxy-agent" = "socks-proxy-agent/6.2.1";
        "node_modules/spdx-correct" = "spdx-correct/3.1.1";
        "node_modules/spdx-exceptions" = "spdx-exceptions/2.3.0";
        "node_modules/spdx-expression-parse" = "spdx-expression-parse/3.0.1";
        "node_modules/spdx-license-ids" = "spdx-license-ids/3.0.12";
        "node_modules/ssri" = "ssri/9.0.1";
        "node_modules/string-width" = "string-width/4.2.3";
        "node_modules/string_decoder" = "string_decoder/1.3.0";
        "node_modules/strip-ansi" = "strip-ansi/6.0.1";
        "node_modules/tar" = "tar/6.1.12";
        "node_modules/unique-filename" = "unique-filename/2.0.1";
        "node_modules/unique-slug" = "unique-slug/3.0.0";
        "node_modules/util-deprecate" = "util-deprecate/1.0.2";
        "node_modules/validate-npm-package-license" = "validate-npm-package-license/3.0.4";
        "node_modules/validate-npm-package-name" = "validate-npm-package-name/4.0.0";
        "node_modules/which" = "which/2.0.2";
        "node_modules/wide-align" = "wide-align/1.1.5";
        "node_modules/wrappy" = "wrappy/1.0.2";
        "node_modules/yallist" = "yallist/4.0.0";
      };
    };
  };
  "abbrev/1.1.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "abbrev";
    key = "abbrev/1.1.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-nne9/IiQ/hzIhY6pdDnbBtz7DjPTKrY00P/zvPSm5pOFkl6xuGrGnXn/VtTNNfNtAfZ9/1RtehkszU9qcTii0Q==";
      sha512 = "nne9/IiQ/hzIhY6pdDnbBtz7DjPTKrY00P/zvPSm5pOFkl6xuGrGnXn/VtTNNfNtAfZ9/1RtehkszU9qcTii0Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/abbrev/-/abbrev-1.1.1.tgz";
    };
    version = "1.1.1";
  };
  "agent-base/6.0.2" = {
    depInfo = {
      debug = {
        descriptor = "4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "agent-base";
    key = "agent-base/6.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==";
      sha512 = "RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz";
    };
    version = "6.0.2";
  };
  "agentkeepalive/4.2.1" = {
    depInfo = {
      debug = {
        descriptor = "^4.1.0";
        runtime = true;
      };
      depd = {
        descriptor = "^1.1.2";
        runtime = true;
      };
      humanize-ms = {
        descriptor = "^1.2.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "agentkeepalive";
    key = "agentkeepalive/4.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Zn4cw2NEqd+9fiSVWMscnjyQ1a8Yfoc5oBajLeo5w+YBHgDUcEBY2hS4YpTz6iN5f/2zQiktcuM6tS8x1p9dpA==";
      sha512 = "Zn4cw2NEqd+9fiSVWMscnjyQ1a8Yfoc5oBajLeo5w+YBHgDUcEBY2hS4YpTz6iN5f/2zQiktcuM6tS8x1p9dpA==";
      type = "tarball";
      url = "https://registry.npmjs.org/agentkeepalive/-/agentkeepalive-4.2.1.tgz";
    };
    version = "4.2.1";
  };
  "aggregate-error/3.1.0" = {
    depInfo = {
      clean-stack = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      indent-string = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "aggregate-error";
    key = "aggregate-error/3.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-4I7Td01quW/RpocfNayFdFVk1qSuoh0E7JrbRJ16nH01HhKFQ88INq9Sd+nd72zqRySlr9BmDA8xlEJ6vJMrYA==";
      sha512 = "4I7Td01quW/RpocfNayFdFVk1qSuoh0E7JrbRJ16nH01HhKFQ88INq9Sd+nd72zqRySlr9BmDA8xlEJ6vJMrYA==";
      type = "tarball";
      url = "https://registry.npmjs.org/aggregate-error/-/aggregate-error-3.1.0.tgz";
    };
    version = "3.1.0";
  };
  "ansi-regex/5.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "ansi-regex";
    key = "ansi-regex/5.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ==";
      sha512 = "quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/ansi-regex/-/ansi-regex-5.0.1.tgz";
    };
    version = "5.0.1";
  };
  "aproba/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "aproba";
    key = "aproba/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-lYe4Gx7QT+MKGbDsA+Z+he/Wtef0BiwDOlK/XkBrdfsh9J/jPPXbX0tE9x9cl27Tmu5gg3QUbUrQYa/y+KOHPQ==";
      sha512 = "lYe4Gx7QT+MKGbDsA+Z+he/Wtef0BiwDOlK/XkBrdfsh9J/jPPXbX0tE9x9cl27Tmu5gg3QUbUrQYa/y+KOHPQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/aproba/-/aproba-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "are-we-there-yet/3.0.1" = {
    depInfo = {
      delegates = {
        descriptor = "^1.0.0";
        runtime = true;
      };
      readable-stream = {
        descriptor = "^3.6.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "are-we-there-yet";
    key = "are-we-there-yet/3.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-QZW4EDmGwlYur0Yyf/b2uGucHQMa8aFUP7eu9ddR73vvhFyt4V0Vl3QHPcTNJ8l6qYOBdxgXdnBXQrHilfRQBg==";
      sha512 = "QZW4EDmGwlYur0Yyf/b2uGucHQMa8aFUP7eu9ddR73vvhFyt4V0Vl3QHPcTNJ8l6qYOBdxgXdnBXQrHilfRQBg==";
      type = "tarball";
      url = "https://registry.npmjs.org/are-we-there-yet/-/are-we-there-yet-3.0.1.tgz";
    };
    version = "3.0.1";
  };
  "balanced-match/1.0.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "balanced-match";
    key = "balanced-match/1.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-3oSeUO0TMV67hN1AmbXsK4yaqU7tjiHlbxRDZOpH0KW9+CeX4bRAaX0Anxt0tx2MrpRpWwQaPwIlISEJhYU5Pw==";
      sha512 = "3oSeUO0TMV67hN1AmbXsK4yaqU7tjiHlbxRDZOpH0KW9+CeX4bRAaX0Anxt0tx2MrpRpWwQaPwIlISEJhYU5Pw==";
      type = "tarball";
      url = "https://registry.npmjs.org/balanced-match/-/balanced-match-1.0.2.tgz";
    };
    version = "1.0.2";
  };
  "brace-expansion/1.1.11" = {
    depInfo = {
      balanced-match = {
        descriptor = "^1.0.0";
        runtime = true;
      };
      concat-map = {
        descriptor = "0.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "brace-expansion";
    key = "brace-expansion/1.1.11";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-iCuPHDFgrHX7H2vEI/5xpz07zSHB00TpugqhmYtVmMO6518mCuRMoOYFldEBl0g187ufozdaHgWKcYFb61qGiA==";
      sha512 = "iCuPHDFgrHX7H2vEI/5xpz07zSHB00TpugqhmYtVmMO6518mCuRMoOYFldEBl0g187ufozdaHgWKcYFb61qGiA==";
      type = "tarball";
      url = "https://registry.npmjs.org/brace-expansion/-/brace-expansion-1.1.11.tgz";
    };
    version = "1.1.11";
  };
  "brace-expansion/2.0.1" = {
    depInfo = {
      balanced-match = {
        descriptor = "^1.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "brace-expansion";
    key = "brace-expansion/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-XnAIvQ8eM+kC6aULx6wuQiwVsnzsi9d3WxzV3FpWTGA19F621kwdbsAcFKXgKUHZWsy+mY6iL1sHTxWEFCytDA==";
      sha512 = "XnAIvQ8eM+kC6aULx6wuQiwVsnzsi9d3WxzV3FpWTGA19F621kwdbsAcFKXgKUHZWsy+mY6iL1sHTxWEFCytDA==";
      type = "tarball";
      url = "https://registry.npmjs.org/brace-expansion/-/brace-expansion-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "builtins/5.0.1" = {
    depInfo = {
      semver = {
        descriptor = "^7.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "builtins";
    key = "builtins/5.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-qwVpFEHNfhYJIzNRBvd2C1kyo6jz3ZSMPyyuR47OPdiKWlbYnZNyDWuyR175qDnAJLiCo5fBBqPb3RiXgWlkOQ==";
      sha512 = "qwVpFEHNfhYJIzNRBvd2C1kyo6jz3ZSMPyyuR47OPdiKWlbYnZNyDWuyR175qDnAJLiCo5fBBqPb3RiXgWlkOQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/builtins/-/builtins-5.0.1.tgz";
    };
    version = "5.0.1";
  };
  "cacache/15.3.0" = {
    depInfo = {
      "@npmcli/fs" = {
        descriptor = "^1.0.0";
        runtime = true;
      };
      "@npmcli/move-file" = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      chownr = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      fs-minipass = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      glob = {
        descriptor = "^7.1.4";
        runtime = true;
      };
      infer-owner = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      lru-cache = {
        descriptor = "^6.0.0";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.1";
        runtime = true;
      };
      minipass-collect = {
        descriptor = "^1.0.2";
        runtime = true;
      };
      minipass-flush = {
        descriptor = "^1.0.5";
        runtime = true;
      };
      minipass-pipeline = {
        descriptor = "^1.2.2";
        runtime = true;
      };
      mkdirp = {
        descriptor = "^1.0.3";
        runtime = true;
      };
      p-map = {
        descriptor = "^4.0.0";
        runtime = true;
      };
      promise-inflight = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
      ssri = {
        descriptor = "^8.0.1";
        runtime = true;
      };
      tar = {
        descriptor = "^6.0.2";
        runtime = true;
      };
      unique-filename = {
        descriptor = "^1.1.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "cacache";
    key = "cacache/15.3.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-VVdYzXEn+cnbXpFgWs5hTT7OScegHVmLhJIR8Ufqk3iFD6A6j5iSX1KuBTfNEv4tdJWE2PzA6IVFtcLC7fN9wQ==";
      sha512 = "VVdYzXEn+cnbXpFgWs5hTT7OScegHVmLhJIR8Ufqk3iFD6A6j5iSX1KuBTfNEv4tdJWE2PzA6IVFtcLC7fN9wQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/cacache/-/cacache-15.3.0.tgz";
    };
    version = "15.3.0";
  };
  "cacache/16.1.3" = {
    depInfo = {
      "@npmcli/fs" = {
        descriptor = "^2.1.0";
        runtime = true;
      };
      "@npmcli/move-file" = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      chownr = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      fs-minipass = {
        descriptor = "^2.1.0";
        runtime = true;
      };
      glob = {
        descriptor = "^8.0.1";
        runtime = true;
      };
      infer-owner = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      lru-cache = {
        descriptor = "^7.7.1";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.6";
        runtime = true;
      };
      minipass-collect = {
        descriptor = "^1.0.2";
        runtime = true;
      };
      minipass-flush = {
        descriptor = "^1.0.5";
        runtime = true;
      };
      minipass-pipeline = {
        descriptor = "^1.2.4";
        runtime = true;
      };
      mkdirp = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      p-map = {
        descriptor = "^4.0.0";
        runtime = true;
      };
      promise-inflight = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
      ssri = {
        descriptor = "^9.0.0";
        runtime = true;
      };
      tar = {
        descriptor = "^6.1.11";
        runtime = true;
      };
      unique-filename = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "cacache";
    key = "cacache/16.1.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-/+Emcj9DAXxX4cwlLmRI9c166RuL3w30zp4R7Joiv2cQTtTtA+jeuCAjH3ZlGnYS3tKENSrKhAzVVP9GVyzeYQ==";
      sha512 = "/+Emcj9DAXxX4cwlLmRI9c166RuL3w30zp4R7Joiv2cQTtTtA+jeuCAjH3ZlGnYS3tKENSrKhAzVVP9GVyzeYQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/cacache/-/cacache-16.1.3.tgz";
    };
    version = "16.1.3";
  };
  "chownr/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "chownr";
    key = "chownr/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-bIomtDF5KGpdogkLd9VspvFzk9KfpyyGlS8YFVZl7TGPBHL5snIOnxeshwVgPteQ9b4Eydl+pVbIyE1DcvCWgQ==";
      sha512 = "bIomtDF5KGpdogkLd9VspvFzk9KfpyyGlS8YFVZl7TGPBHL5snIOnxeshwVgPteQ9b4Eydl+pVbIyE1DcvCWgQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/chownr/-/chownr-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "clean-stack/2.2.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "clean-stack";
    key = "clean-stack/2.2.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-4diC9HaTE+KRAMWhDhrGOECgWZxoevMc5TlkObMqNSsVU62PYzXZ/SMTjzyGAFF1YusgxGcSWTEXBhp0CPwQ1A==";
      sha512 = "4diC9HaTE+KRAMWhDhrGOECgWZxoevMc5TlkObMqNSsVU62PYzXZ/SMTjzyGAFF1YusgxGcSWTEXBhp0CPwQ1A==";
      type = "tarball";
      url = "https://registry.npmjs.org/clean-stack/-/clean-stack-2.2.0.tgz";
    };
    version = "2.2.0";
  };
  "color-support/1.1.3" = {
    bin = {
      color-support = "bin.js";
    };
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "color-support";
    key = "color-support/1.1.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-qiBjkpbMLO/HL68y+lh4q0/O1MZFj2RX6X/KmMa3+gJD3z+WwI1ZzDHysvqHGS3mP6mznPckpXmw1nI9cJjyRg==";
      sha512 = "qiBjkpbMLO/HL68y+lh4q0/O1MZFj2RX6X/KmMa3+gJD3z+WwI1ZzDHysvqHGS3mP6mznPckpXmw1nI9cJjyRg==";
      type = "tarball";
      url = "https://registry.npmjs.org/color-support/-/color-support-1.1.3.tgz";
    };
    version = "1.1.3";
  };
  "concat-map/0.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "concat-map";
    key = "concat-map/0.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-/Srv4dswyQNBfohGpz9o6Yb3Gz3SrUDqBH5rTuhGR7ahtlbYKnVxw2bCFMRljaA7EXHaXZ8wsHdodFvbkhKmqg==";
      sha512 = "/Srv4dswyQNBfohGpz9o6Yb3Gz3SrUDqBH5rTuhGR7ahtlbYKnVxw2bCFMRljaA7EXHaXZ8wsHdodFvbkhKmqg==";
      type = "tarball";
      url = "https://registry.npmjs.org/concat-map/-/concat-map-0.0.1.tgz";
    };
    version = "0.0.1";
  };
  "console-control-strings/1.1.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "console-control-strings";
    key = "console-control-strings/1.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ty/fTekppD2fIwRvnZAVdeOiGd1c7YXEixbgJTNzqcxJWKQnjJ/V1bNEEE6hygpM3WjwHFUVK6HTjWSzV4a8sQ==";
      sha512 = "ty/fTekppD2fIwRvnZAVdeOiGd1c7YXEixbgJTNzqcxJWKQnjJ/V1bNEEE6hygpM3WjwHFUVK6HTjWSzV4a8sQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/console-control-strings/-/console-control-strings-1.1.0.tgz";
    };
    version = "1.1.0";
  };
  "debug/4.3.4" = {
    depInfo = {
      ms = {
        descriptor = "2.1.2";
        runtime = true;
      };
      supports-color = {
        optional = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "debug";
    key = "debug/4.3.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==";
      sha512 = "PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz";
    };
    version = "4.3.4";
  };
  "delegates/1.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "delegates";
    key = "delegates/1.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-bd2L678uiWATM6m5Z1VzNCErI3jiGzt6HGY8OVICs40JQq/HALfbyNJmp0UDakEY4pMMaN0Ly5om/B1VI/+xfQ==";
      sha512 = "bd2L678uiWATM6m5Z1VzNCErI3jiGzt6HGY8OVICs40JQq/HALfbyNJmp0UDakEY4pMMaN0Ly5om/B1VI/+xfQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/delegates/-/delegates-1.0.0.tgz";
    };
    version = "1.0.0";
  };
  "depd/1.1.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "depd";
    key = "depd/1.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-7emPTl6Dpo6JRXOXjLRxck+FlLRX5847cLKEn00PLAgc3g2hTZZgr+e4c2v6QpSmLeFP3n5yUo7ft6avBK/5jQ==";
      sha512 = "7emPTl6Dpo6JRXOXjLRxck+FlLRX5847cLKEn00PLAgc3g2hTZZgr+e4c2v6QpSmLeFP3n5yUo7ft6avBK/5jQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/depd/-/depd-1.1.2.tgz";
    };
    version = "1.1.2";
  };
  "emoji-regex/8.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "emoji-regex";
    key = "emoji-regex/8.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A==";
      sha512 = "MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A==";
      type = "tarball";
      url = "https://registry.npmjs.org/emoji-regex/-/emoji-regex-8.0.0.tgz";
    };
    version = "8.0.0";
  };
  "encoding/0.1.13" = {
    depInfo = {
      iconv-lite = {
        descriptor = "^0.6.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "encoding";
    key = "encoding/0.1.13";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ETBauow1T35Y/WZMkio9jiM0Z5xjHHmJ4XmjZOq1l/dXz3lr2sRn87nJy20RupqSh1F2m3HHPSp8ShIPQJrJ3A==";
      sha512 = "ETBauow1T35Y/WZMkio9jiM0Z5xjHHmJ4XmjZOq1l/dXz3lr2sRn87nJy20RupqSh1F2m3HHPSp8ShIPQJrJ3A==";
      type = "tarball";
      url = "https://registry.npmjs.org/encoding/-/encoding-0.1.13.tgz";
    };
    version = "0.1.13";
  };
  "env-paths/2.2.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "env-paths";
    key = "env-paths/2.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-+h1lkLKhZMTYjog1VEpJNG7NZJWcuc2DDk/qsqSTRRCOXiLjeQ1d1/udrUGhqMxUgAlwKNZ0cf2uqan5GLuS2A==";
      sha512 = "+h1lkLKhZMTYjog1VEpJNG7NZJWcuc2DDk/qsqSTRRCOXiLjeQ1d1/udrUGhqMxUgAlwKNZ0cf2uqan5GLuS2A==";
      type = "tarball";
      url = "https://registry.npmjs.org/env-paths/-/env-paths-2.2.1.tgz";
    };
    version = "2.2.1";
  };
  "err-code/2.0.3" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "err-code";
    key = "err-code/2.0.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-2bmlRpNKBxT/CRmPOlyISQpNj+qSeYvcym/uT0Jx2bMOlKLtSy1ZmLuVxSEKKyor/N5yhvp/ZiG1oE3DEYMSFA==";
      sha512 = "2bmlRpNKBxT/CRmPOlyISQpNj+qSeYvcym/uT0Jx2bMOlKLtSy1ZmLuVxSEKKyor/N5yhvp/ZiG1oE3DEYMSFA==";
      type = "tarball";
      url = "https://registry.npmjs.org/err-code/-/err-code-2.0.3.tgz";
    };
    version = "2.0.3";
  };
  "fs-minipass/2.1.0" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "fs-minipass";
    key = "fs-minipass/2.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-V/JgOLFCS+R6Vcq0slCuaeWEdNC3ouDlJMNIsacH2VtALiu9mV4LPrHc5cDl8k5aw6J8jwgWWpiTo5RYhmIzvg==";
      sha512 = "V/JgOLFCS+R6Vcq0slCuaeWEdNC3ouDlJMNIsacH2VtALiu9mV4LPrHc5cDl8k5aw6J8jwgWWpiTo5RYhmIzvg==";
      type = "tarball";
      url = "https://registry.npmjs.org/fs-minipass/-/fs-minipass-2.1.0.tgz";
    };
    version = "2.1.0";
  };
  "fs.realpath/1.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "fs.realpath";
    key = "fs.realpath/1.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-OO0pH2lK6a0hZnAdau5ItzHPI6pUlvI7jMVnxUQRtw4owF2wk8lOSabtGDCTP4Ggrg2MbGnWO9X8K1t4+fGMDw==";
      sha512 = "OO0pH2lK6a0hZnAdau5ItzHPI6pUlvI7jMVnxUQRtw4owF2wk8lOSabtGDCTP4Ggrg2MbGnWO9X8K1t4+fGMDw==";
      type = "tarball";
      url = "https://registry.npmjs.org/fs.realpath/-/fs.realpath-1.0.0.tgz";
    };
    version = "1.0.0";
  };
  "function-bind/1.1.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "function-bind";
    key = "function-bind/1.1.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-yIovAzMX49sF8Yl58fSCWJ5svSLuaibPxXQJFLmBObTuCr0Mf1KiPopGM9NiFjiYBCbfaa2Fh6breQ6ANVTI0A==";
      sha512 = "yIovAzMX49sF8Yl58fSCWJ5svSLuaibPxXQJFLmBObTuCr0Mf1KiPopGM9NiFjiYBCbfaa2Fh6breQ6ANVTI0A==";
      type = "tarball";
      url = "https://registry.npmjs.org/function-bind/-/function-bind-1.1.1.tgz";
    };
    version = "1.1.1";
  };
  "gauge/4.0.4" = {
    depInfo = {
      aproba = {
        descriptor = "^1.0.3 || ^2.0.0";
        runtime = true;
      };
      color-support = {
        descriptor = "^1.1.3";
        runtime = true;
      };
      console-control-strings = {
        descriptor = "^1.1.0";
        runtime = true;
      };
      has-unicode = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      signal-exit = {
        descriptor = "^3.0.7";
        runtime = true;
      };
      string-width = {
        descriptor = "^4.2.3";
        runtime = true;
      };
      strip-ansi = {
        descriptor = "^6.0.1";
        runtime = true;
      };
      wide-align = {
        descriptor = "^1.1.5";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "gauge";
    key = "gauge/4.0.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-f9m+BEN5jkg6a0fZjleidjN51VE1X+mPFQ2DJ0uv1V39oCLCbsGe6yjbBnp7eK7z/+GAon99a3nHuqbuuthyPg==";
      sha512 = "f9m+BEN5jkg6a0fZjleidjN51VE1X+mPFQ2DJ0uv1V39oCLCbsGe6yjbBnp7eK7z/+GAon99a3nHuqbuuthyPg==";
      type = "tarball";
      url = "https://registry.npmjs.org/gauge/-/gauge-4.0.4.tgz";
    };
    version = "4.0.4";
  };
  "glob/7.2.3" = {
    depInfo = {
      "fs.realpath" = {
        descriptor = "^1.0.0";
        runtime = true;
      };
      inflight = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      inherits = {
        descriptor = "2";
        runtime = true;
      };
      minimatch = {
        descriptor = "^3.1.1";
        runtime = true;
      };
      once = {
        descriptor = "^1.3.0";
        runtime = true;
      };
      path-is-absolute = {
        descriptor = "^1.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "glob";
    key = "glob/7.2.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-nFR0zLpU2YCaRxwoCJvL6UvCH2JFyFVIvwTLsIf21AuHlMskA1hhTdk+LlYJtOlYt9v6dvszD2BGRqBL+iQK9Q==";
      sha512 = "nFR0zLpU2YCaRxwoCJvL6UvCH2JFyFVIvwTLsIf21AuHlMskA1hhTdk+LlYJtOlYt9v6dvszD2BGRqBL+iQK9Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/glob/-/glob-7.2.3.tgz";
    };
    version = "7.2.3";
  };
  "glob/8.0.3" = {
    depInfo = {
      "fs.realpath" = {
        descriptor = "^1.0.0";
        runtime = true;
      };
      inflight = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      inherits = {
        descriptor = "2";
        runtime = true;
      };
      minimatch = {
        descriptor = "^5.0.1";
        runtime = true;
      };
      once = {
        descriptor = "^1.3.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "glob";
    key = "glob/8.0.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ull455NHSHI/Y1FqGaaYFaLGkNMMJbavMrEGFXG/PGrg6y7sutWHUHrz6gy6WEBH6akM1M414dWKCNs+IhKdiQ==";
      sha512 = "ull455NHSHI/Y1FqGaaYFaLGkNMMJbavMrEGFXG/PGrg6y7sutWHUHrz6gy6WEBH6akM1M414dWKCNs+IhKdiQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/glob/-/glob-8.0.3.tgz";
    };
    version = "8.0.3";
  };
  "graceful-fs/4.2.10" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "graceful-fs";
    key = "graceful-fs/4.2.10";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-9ByhssR2fPVsNZj478qUUbKfmL0+t5BDVyjShtyZZLiK7ZDAArFFfopyOTj0M05wE2tJPisA4iTnnXl2YoPvOA==";
      sha512 = "9ByhssR2fPVsNZj478qUUbKfmL0+t5BDVyjShtyZZLiK7ZDAArFFfopyOTj0M05wE2tJPisA4iTnnXl2YoPvOA==";
      type = "tarball";
      url = "https://registry.npmjs.org/graceful-fs/-/graceful-fs-4.2.10.tgz";
    };
    version = "4.2.10";
  };
  "has-unicode/2.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "has-unicode";
    key = "has-unicode/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-8Rf9Y83NBReMnx0gFzA8JImQACstCYWUplepDa9xprwwtmgEZUF0h/i5xSA625zB/I37EtrswSST6OXxwaaIJQ==";
      sha512 = "8Rf9Y83NBReMnx0gFzA8JImQACstCYWUplepDa9xprwwtmgEZUF0h/i5xSA625zB/I37EtrswSST6OXxwaaIJQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/has-unicode/-/has-unicode-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "has/1.0.3" = {
    depInfo = {
      function-bind = {
        descriptor = "^1.1.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "has";
    key = "has/1.0.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-f2dvO0VU6Oej7RkWJGrehjbzMAjFp5/VKPp5tTpWIV4JHHZK1/BxbFRtf/siA2SWTe09caDmVtYYzWEIbBS4zw==";
      sha512 = "f2dvO0VU6Oej7RkWJGrehjbzMAjFp5/VKPp5tTpWIV4JHHZK1/BxbFRtf/siA2SWTe09caDmVtYYzWEIbBS4zw==";
      type = "tarball";
      url = "https://registry.npmjs.org/has/-/has-1.0.3.tgz";
    };
    version = "1.0.3";
  };
  "hosted-git-info/5.2.1" = {
    depInfo = {
      lru-cache = {
        descriptor = "^7.5.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "hosted-git-info";
    key = "hosted-git-info/5.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-xIcQYMnhcx2Nr4JTjsFmwwnr9vldugPy9uVm0o87bjqqWMv9GaqsTeT+i99wTl0mk1uLxJtHxLb8kymqTENQsw==";
      sha512 = "xIcQYMnhcx2Nr4JTjsFmwwnr9vldugPy9uVm0o87bjqqWMv9GaqsTeT+i99wTl0mk1uLxJtHxLb8kymqTENQsw==";
      type = "tarball";
      url = "https://registry.npmjs.org/hosted-git-info/-/hosted-git-info-5.2.1.tgz";
    };
    version = "5.2.1";
  };
  "http-cache-semantics/4.1.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "http-cache-semantics";
    key = "http-cache-semantics/4.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-carPklcUh7ROWRK7Cv27RPtdhYhUsela/ue5/jKzjegVvXDqM2ILE9Q2BGn9JZJh1g87cp56su/FgQSzcWS8cQ==";
      sha512 = "carPklcUh7ROWRK7Cv27RPtdhYhUsela/ue5/jKzjegVvXDqM2ILE9Q2BGn9JZJh1g87cp56su/FgQSzcWS8cQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/http-cache-semantics/-/http-cache-semantics-4.1.0.tgz";
    };
    version = "4.1.0";
  };
  "http-proxy-agent/4.0.1" = {
    depInfo = {
      "@tootallnate/once" = {
        descriptor = "1";
        runtime = true;
      };
      agent-base = {
        descriptor = "6";
        runtime = true;
      };
      debug = {
        descriptor = "4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "http-proxy-agent";
    key = "http-proxy-agent/4.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-k0zdNgqWTGA6aeIRVpvfVob4fL52dTfaehylg0Y4UvSySvOq/Y+BOyPrgpUrA7HylqvU8vIZGsRuXmspskV0Tg==";
      sha512 = "k0zdNgqWTGA6aeIRVpvfVob4fL52dTfaehylg0Y4UvSySvOq/Y+BOyPrgpUrA7HylqvU8vIZGsRuXmspskV0Tg==";
      type = "tarball";
      url = "https://registry.npmjs.org/http-proxy-agent/-/http-proxy-agent-4.0.1.tgz";
    };
    version = "4.0.1";
  };
  "http-proxy-agent/5.0.0" = {
    depInfo = {
      "@tootallnate/once" = {
        descriptor = "2";
        runtime = true;
      };
      agent-base = {
        descriptor = "6";
        runtime = true;
      };
      debug = {
        descriptor = "4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "http-proxy-agent";
    key = "http-proxy-agent/5.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-n2hY8YdoRE1i7r6M0w9DIw5GgZN0G25P8zLCRQ8rjXtTU3vsNFBI/vWK/UIeE6g5MUUz6avwAPXmL6Fy9D/90w==";
      sha512 = "n2hY8YdoRE1i7r6M0w9DIw5GgZN0G25P8zLCRQ8rjXtTU3vsNFBI/vWK/UIeE6g5MUUz6avwAPXmL6Fy9D/90w==";
      type = "tarball";
      url = "https://registry.npmjs.org/http-proxy-agent/-/http-proxy-agent-5.0.0.tgz";
    };
    version = "5.0.0";
  };
  "https-proxy-agent/5.0.1" = {
    depInfo = {
      agent-base = {
        descriptor = "6";
        runtime = true;
      };
      debug = {
        descriptor = "4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "https-proxy-agent";
    key = "https-proxy-agent/5.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==";
      sha512 = "dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==";
      type = "tarball";
      url = "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-5.0.1.tgz";
    };
    version = "5.0.1";
  };
  "humanize-ms/1.2.1" = {
    depInfo = {
      ms = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "humanize-ms";
    key = "humanize-ms/1.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Fl70vYtsAFb/C06PTS9dZBo7ihau+Tu/DNCk/OyHhea07S+aeMWpFFkUaXRa8fI+ScZbEI8dfSxwY7gxZ9SAVQ==";
      sha512 = "Fl70vYtsAFb/C06PTS9dZBo7ihau+Tu/DNCk/OyHhea07S+aeMWpFFkUaXRa8fI+ScZbEI8dfSxwY7gxZ9SAVQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/humanize-ms/-/humanize-ms-1.2.1.tgz";
    };
    version = "1.2.1";
  };
  "iconv-lite/0.6.3" = {
    depInfo = {
      safer-buffer = {
        descriptor = ">= 2.1.2 < 3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "iconv-lite";
    key = "iconv-lite/0.6.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-4fCk79wshMdzMp2rH06qWrJE4iolqLhCUH+OiuIgU++RB0+94NlDL81atO7GX55uUKueo0txHNtvEyI6D7WdMw==";
      sha512 = "4fCk79wshMdzMp2rH06qWrJE4iolqLhCUH+OiuIgU++RB0+94NlDL81atO7GX55uUKueo0txHNtvEyI6D7WdMw==";
      type = "tarball";
      url = "https://registry.npmjs.org/iconv-lite/-/iconv-lite-0.6.3.tgz";
    };
    version = "0.6.3";
  };
  "ignore-walk/5.0.1" = {
    depInfo = {
      minimatch = {
        descriptor = "^5.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "ignore-walk";
    key = "ignore-walk/5.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-yemi4pMf51WKT7khInJqAvsIGzoqYXblnsz0ql8tM+yi1EKYTY1evX4NAbJrLL/Aanr2HyZeluqU+Oi7MGHokw==";
      sha512 = "yemi4pMf51WKT7khInJqAvsIGzoqYXblnsz0ql8tM+yi1EKYTY1evX4NAbJrLL/Aanr2HyZeluqU+Oi7MGHokw==";
      type = "tarball";
      url = "https://registry.npmjs.org/ignore-walk/-/ignore-walk-5.0.1.tgz";
    };
    version = "5.0.1";
  };
  "imurmurhash/0.1.4" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "imurmurhash";
    key = "imurmurhash/0.1.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-JmXMZ6wuvDmLiHEml9ykzqO6lwFbof0GG4IkcGaENdCRDDmMVnny7s5HsIgHCbaq0w2MyPhDqkhTUgS2LU2PHA==";
      sha512 = "JmXMZ6wuvDmLiHEml9ykzqO6lwFbof0GG4IkcGaENdCRDDmMVnny7s5HsIgHCbaq0w2MyPhDqkhTUgS2LU2PHA==";
      type = "tarball";
      url = "https://registry.npmjs.org/imurmurhash/-/imurmurhash-0.1.4.tgz";
    };
    version = "0.1.4";
  };
  "indent-string/4.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "indent-string";
    key = "indent-string/4.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-EdDDZu4A2OyIK7Lr/2zG+w5jmbuk1DVBnEwREQvBzspBJkCEbRa8GxU1lghYcaGJCnRWibjDXlq779X1/y5xwg==";
      sha512 = "EdDDZu4A2OyIK7Lr/2zG+w5jmbuk1DVBnEwREQvBzspBJkCEbRa8GxU1lghYcaGJCnRWibjDXlq779X1/y5xwg==";
      type = "tarball";
      url = "https://registry.npmjs.org/indent-string/-/indent-string-4.0.0.tgz";
    };
    version = "4.0.0";
  };
  "infer-owner/1.0.4" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "infer-owner";
    key = "infer-owner/1.0.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-IClj+Xz94+d7irH5qRyfJonOdfTzuDaifE6ZPWfx0N0+/ATZCbuTPq2prFl526urkQd90WyUKIh1DfBQ2hMz9A==";
      sha512 = "IClj+Xz94+d7irH5qRyfJonOdfTzuDaifE6ZPWfx0N0+/ATZCbuTPq2prFl526urkQd90WyUKIh1DfBQ2hMz9A==";
      type = "tarball";
      url = "https://registry.npmjs.org/infer-owner/-/infer-owner-1.0.4.tgz";
    };
    version = "1.0.4";
  };
  "inflight/1.0.6" = {
    depInfo = {
      once = {
        descriptor = "^1.3.0";
        runtime = true;
      };
      wrappy = {
        descriptor = "1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "inflight";
    key = "inflight/1.0.6";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-k92I/b08q4wvFscXCLvqfsHCrjrF7yiXsQuIVvVE7N82W3+aqpzuUdBbfhWcy/FZR3/4IgflMgKLOsvPDrGCJA==";
      sha512 = "k92I/b08q4wvFscXCLvqfsHCrjrF7yiXsQuIVvVE7N82W3+aqpzuUdBbfhWcy/FZR3/4IgflMgKLOsvPDrGCJA==";
      type = "tarball";
      url = "https://registry.npmjs.org/inflight/-/inflight-1.0.6.tgz";
    };
    version = "1.0.6";
  };
  "inherits/2.0.4" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "inherits";
    key = "inherits/2.0.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ==";
      sha512 = "k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/inherits/-/inherits-2.0.4.tgz";
    };
    version = "2.0.4";
  };
  "ip/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "ip";
    key = "ip/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-WKa+XuLG1A1R0UWhl2+1XQSi+fZWMsYKffMZTTYsiZaUD8k2yDAj5atimTUD2TZkyCkNEeYE5NhFZmupOGtjYQ==";
      sha512 = "WKa+XuLG1A1R0UWhl2+1XQSi+fZWMsYKffMZTTYsiZaUD8k2yDAj5atimTUD2TZkyCkNEeYE5NhFZmupOGtjYQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/ip/-/ip-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "is-core-module/2.11.0" = {
    depInfo = {
      has = {
        descriptor = "^1.0.3";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "is-core-module";
    key = "is-core-module/2.11.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-RRjxlvLDkD1YJwDbroBHMb+cukurkDWNyHx7D3oNB5x9rb5ogcksMC5wHCadcXoo67gVr/+3GFySh3134zi6rw==";
      sha512 = "RRjxlvLDkD1YJwDbroBHMb+cukurkDWNyHx7D3oNB5x9rb5ogcksMC5wHCadcXoo67gVr/+3GFySh3134zi6rw==";
      type = "tarball";
      url = "https://registry.npmjs.org/is-core-module/-/is-core-module-2.11.0.tgz";
    };
    version = "2.11.0";
  };
  "is-fullwidth-code-point/3.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "is-fullwidth-code-point";
    key = "is-fullwidth-code-point/3.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg==";
      sha512 = "zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg==";
      type = "tarball";
      url = "https://registry.npmjs.org/is-fullwidth-code-point/-/is-fullwidth-code-point-3.0.0.tgz";
    };
    version = "3.0.0";
  };
  "is-lambda/1.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "is-lambda";
    key = "is-lambda/1.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-z7CMFGNrENq5iFB9Bqo64Xk6Y9sg+epq1myIcdHaGnbMTYOxvzsEtdYqQUylB7LxfkvgrrjP32T6Ywciio9UIQ==";
      sha512 = "z7CMFGNrENq5iFB9Bqo64Xk6Y9sg+epq1myIcdHaGnbMTYOxvzsEtdYqQUylB7LxfkvgrrjP32T6Ywciio9UIQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/is-lambda/-/is-lambda-1.0.1.tgz";
    };
    version = "1.0.1";
  };
  "isexe/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "isexe";
    key = "isexe/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-RHxMLp9lnKHGHRng9QFhRCMbYAcVpn69smSGcq3f36xjgVVWThj4qqLbTLlq7Ssj8B+fIQ1EuCEGI2lKsyQeIw==";
      sha512 = "RHxMLp9lnKHGHRng9QFhRCMbYAcVpn69smSGcq3f36xjgVVWThj4qqLbTLlq7Ssj8B+fIQ1EuCEGI2lKsyQeIw==";
      type = "tarball";
      url = "https://registry.npmjs.org/isexe/-/isexe-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "json-parse-even-better-errors/2.3.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "json-parse-even-better-errors";
    key = "json-parse-even-better-errors/2.3.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-xyFwyhro/JEof6Ghe2iz2NcXoj2sloNsWr/XsERDK/oiPCfaNhl5ONfp+jQdAZRQQ0IJWNzH9zIZF7li91kh2w==";
      sha512 = "xyFwyhro/JEof6Ghe2iz2NcXoj2sloNsWr/XsERDK/oiPCfaNhl5ONfp+jQdAZRQQ0IJWNzH9zIZF7li91kh2w==";
      type = "tarball";
      url = "https://registry.npmjs.org/json-parse-even-better-errors/-/json-parse-even-better-errors-2.3.1.tgz";
    };
    version = "2.3.1";
  };
  "jsonparse/1.3.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "jsonparse";
    key = "jsonparse/1.3.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-POQXvpdL69+CluYsillJ7SUhKvytYjW9vG/GKpnf+xP8UWgYEM/RaMzHHofbALDiKbbP1W8UEYmgGl39WkPZsg==";
      sha512 = "POQXvpdL69+CluYsillJ7SUhKvytYjW9vG/GKpnf+xP8UWgYEM/RaMzHHofbALDiKbbP1W8UEYmgGl39WkPZsg==";
      type = "tarball";
      url = "https://registry.npmjs.org/jsonparse/-/jsonparse-1.3.1.tgz";
    };
    version = "1.3.1";
  };
  "lru-cache/6.0.0" = {
    depInfo = {
      yallist = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "lru-cache";
    key = "lru-cache/6.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Jo6dJ04CmSjuznwJSS3pUeWmd/H0ffTlkXXgwZi+eq1UCmqQwCh+eLsYOYCwY991i2Fah4h1BEMCx4qThGbsiA==";
      sha512 = "Jo6dJ04CmSjuznwJSS3pUeWmd/H0ffTlkXXgwZi+eq1UCmqQwCh+eLsYOYCwY991i2Fah4h1BEMCx4qThGbsiA==";
      type = "tarball";
      url = "https://registry.npmjs.org/lru-cache/-/lru-cache-6.0.0.tgz";
    };
    version = "6.0.0";
  };
  "lru-cache/7.14.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "lru-cache";
    key = "lru-cache/7.14.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-EIRtP1GrSJny0dqb50QXRUNBxHJhcpxHC++M5tD7RYbvLLn5KVWKsbyswSSqDuU15UFi3bgTQIY8nhDMeF6aDQ==";
      sha512 = "EIRtP1GrSJny0dqb50QXRUNBxHJhcpxHC++M5tD7RYbvLLn5KVWKsbyswSSqDuU15UFi3bgTQIY8nhDMeF6aDQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/lru-cache/-/lru-cache-7.14.0.tgz";
    };
    version = "7.14.0";
  };
  "make-fetch-happen/10.2.1" = {
    depInfo = {
      agentkeepalive = {
        descriptor = "^4.2.1";
        runtime = true;
      };
      cacache = {
        descriptor = "^16.1.0";
        runtime = true;
      };
      http-cache-semantics = {
        descriptor = "^4.1.0";
        runtime = true;
      };
      http-proxy-agent = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      https-proxy-agent = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      is-lambda = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      lru-cache = {
        descriptor = "^7.7.1";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.6";
        runtime = true;
      };
      minipass-collect = {
        descriptor = "^1.0.2";
        runtime = true;
      };
      minipass-fetch = {
        descriptor = "^2.0.3";
        runtime = true;
      };
      minipass-flush = {
        descriptor = "^1.0.5";
        runtime = true;
      };
      minipass-pipeline = {
        descriptor = "^1.2.4";
        runtime = true;
      };
      negotiator = {
        descriptor = "^0.6.3";
        runtime = true;
      };
      promise-retry = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      socks-proxy-agent = {
        descriptor = "^7.0.0";
        runtime = true;
      };
      ssri = {
        descriptor = "^9.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "make-fetch-happen";
    key = "make-fetch-happen/10.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-NgOPbRiaQM10DYXvN3/hhGVI2M5MtITFryzBGxHM5p4wnFxsVCbxkrBrDsk+EZ5OB4jEOT7AjDxtdF+KVEFT7w==";
      sha512 = "NgOPbRiaQM10DYXvN3/hhGVI2M5MtITFryzBGxHM5p4wnFxsVCbxkrBrDsk+EZ5OB4jEOT7AjDxtdF+KVEFT7w==";
      type = "tarball";
      url = "https://registry.npmjs.org/make-fetch-happen/-/make-fetch-happen-10.2.1.tgz";
    };
    version = "10.2.1";
  };
  "make-fetch-happen/9.1.0" = {
    depInfo = {
      agentkeepalive = {
        descriptor = "^4.1.3";
        runtime = true;
      };
      cacache = {
        descriptor = "^15.2.0";
        runtime = true;
      };
      http-cache-semantics = {
        descriptor = "^4.1.0";
        runtime = true;
      };
      http-proxy-agent = {
        descriptor = "^4.0.1";
        runtime = true;
      };
      https-proxy-agent = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      is-lambda = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      lru-cache = {
        descriptor = "^6.0.0";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.3";
        runtime = true;
      };
      minipass-collect = {
        descriptor = "^1.0.2";
        runtime = true;
      };
      minipass-fetch = {
        descriptor = "^1.3.2";
        runtime = true;
      };
      minipass-flush = {
        descriptor = "^1.0.5";
        runtime = true;
      };
      minipass-pipeline = {
        descriptor = "^1.2.4";
        runtime = true;
      };
      negotiator = {
        descriptor = "^0.6.2";
        runtime = true;
      };
      promise-retry = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      socks-proxy-agent = {
        descriptor = "^6.0.0";
        runtime = true;
      };
      ssri = {
        descriptor = "^8.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "make-fetch-happen";
    key = "make-fetch-happen/9.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-+zopwDy7DNknmwPQplem5lAZX/eCOzSvSNNcSKm5eVwTkOBzoktEfXsa9L23J/GIRhxRsaxzkPEhrJEpE2F4Gg==";
      sha512 = "+zopwDy7DNknmwPQplem5lAZX/eCOzSvSNNcSKm5eVwTkOBzoktEfXsa9L23J/GIRhxRsaxzkPEhrJEpE2F4Gg==";
      type = "tarball";
      url = "https://registry.npmjs.org/make-fetch-happen/-/make-fetch-happen-9.1.0.tgz";
    };
    version = "9.1.0";
  };
  "minimatch/3.1.2" = {
    depInfo = {
      brace-expansion = {
        descriptor = "^1.1.7";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minimatch";
    key = "minimatch/3.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-J7p63hRiAjw1NDEww1W7i37+ByIrOWO5XQQAzZ3VOcL0PNybwpfmV/N05zFAzwQ9USyEcX6t3UO+K5aqBQOIHw==";
      sha512 = "J7p63hRiAjw1NDEww1W7i37+ByIrOWO5XQQAzZ3VOcL0PNybwpfmV/N05zFAzwQ9USyEcX6t3UO+K5aqBQOIHw==";
      type = "tarball";
      url = "https://registry.npmjs.org/minimatch/-/minimatch-3.1.2.tgz";
    };
    version = "3.1.2";
  };
  "minimatch/5.1.0" = {
    depInfo = {
      brace-expansion = {
        descriptor = "^2.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minimatch";
    key = "minimatch/5.1.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-9TPBGGak4nHfGZsPBohm9AWg6NoT7QTCehS3BIJABslyZbzxfV78QM2Y6+i741OPZIafFAaiiEMh5OyIrJPgtg==";
      sha512 = "9TPBGGak4nHfGZsPBohm9AWg6NoT7QTCehS3BIJABslyZbzxfV78QM2Y6+i741OPZIafFAaiiEMh5OyIrJPgtg==";
      type = "tarball";
      url = "https://registry.npmjs.org/minimatch/-/minimatch-5.1.0.tgz";
    };
    version = "5.1.0";
  };
  "minipass-collect/1.0.2" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-collect";
    key = "minipass-collect/1.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-6T6lH0H8OG9kITm/Jm6tdooIbogG9e0tLgpY6mphXSm/A9u8Nq1ryBG+Qspiub9LjWlBPsPS3tWQ/Botq4FdxA==";
      sha512 = "6T6lH0H8OG9kITm/Jm6tdooIbogG9e0tLgpY6mphXSm/A9u8Nq1ryBG+Qspiub9LjWlBPsPS3tWQ/Botq4FdxA==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-collect/-/minipass-collect-1.0.2.tgz";
    };
    version = "1.0.2";
  };
  "minipass-fetch/1.4.1" = {
    depInfo = {
      encoding = {
        descriptor = "^0.1.12";
        optional = true;
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.0";
        runtime = true;
      };
      minipass-sized = {
        descriptor = "^1.0.3";
        runtime = true;
      };
      minizlib = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-fetch";
    key = "minipass-fetch/1.4.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-CGH1eblLq26Y15+Azk7ey4xh0J/XfJfrCox5LDJiKqI2Q2iwOLOKrlmIaODiSQS8d18jalF6y2K2ePUm0CmShw==";
      sha512 = "CGH1eblLq26Y15+Azk7ey4xh0J/XfJfrCox5LDJiKqI2Q2iwOLOKrlmIaODiSQS8d18jalF6y2K2ePUm0CmShw==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-fetch/-/minipass-fetch-1.4.1.tgz";
    };
    version = "1.4.1";
  };
  "minipass-fetch/2.1.2" = {
    depInfo = {
      encoding = {
        descriptor = "^0.1.13";
        optional = true;
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.6";
        runtime = true;
      };
      minipass-sized = {
        descriptor = "^1.0.3";
        runtime = true;
      };
      minizlib = {
        descriptor = "^2.1.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-fetch";
    key = "minipass-fetch/2.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-LT49Zi2/WMROHYoqGgdlQIZh8mLPZmOrN2NdJjMXxYe4nkN6FUyuPuOAOedNJDrx0IRGg9+4guZewtp8hE6TxA==";
      sha512 = "LT49Zi2/WMROHYoqGgdlQIZh8mLPZmOrN2NdJjMXxYe4nkN6FUyuPuOAOedNJDrx0IRGg9+4guZewtp8hE6TxA==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-fetch/-/minipass-fetch-2.1.2.tgz";
    };
    version = "2.1.2";
  };
  "minipass-flush/1.0.5" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-flush";
    key = "minipass-flush/1.0.5";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-JmQSYYpPUqX5Jyn1mXaRwOda1uQ8HP5KAT/oDSLCzt1BYRhQU0/hDtsB1ufZfEEzMZ9aAVmsBw8+FWsIXlClWw==";
      sha512 = "JmQSYYpPUqX5Jyn1mXaRwOda1uQ8HP5KAT/oDSLCzt1BYRhQU0/hDtsB1ufZfEEzMZ9aAVmsBw8+FWsIXlClWw==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-flush/-/minipass-flush-1.0.5.tgz";
    };
    version = "1.0.5";
  };
  "minipass-json-stream/1.0.1" = {
    depInfo = {
      jsonparse = {
        descriptor = "^1.3.1";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-json-stream";
    key = "minipass-json-stream/1.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ODqY18UZt/I8k+b7rl2AENgbWE8IDYam+undIJONvigAz8KR5GWblsFTEfQs0WODsjbSXWlm+JHEv8Gr6Tfdbg==";
      sha512 = "ODqY18UZt/I8k+b7rl2AENgbWE8IDYam+undIJONvigAz8KR5GWblsFTEfQs0WODsjbSXWlm+JHEv8Gr6Tfdbg==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-json-stream/-/minipass-json-stream-1.0.1.tgz";
    };
    version = "1.0.1";
  };
  "minipass-pipeline/1.2.4" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-pipeline";
    key = "minipass-pipeline/1.2.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-xuIq7cIOt09RPRJ19gdi4b+RiNvDFYe5JH+ggNvBqGqpQXcru3PcRmOZuHBKWK1Txf9+cQ+HMVN4d6z46LZP7A==";
      sha512 = "xuIq7cIOt09RPRJ19gdi4b+RiNvDFYe5JH+ggNvBqGqpQXcru3PcRmOZuHBKWK1Txf9+cQ+HMVN4d6z46LZP7A==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-pipeline/-/minipass-pipeline-1.2.4.tgz";
    };
    version = "1.2.4";
  };
  "minipass-sized/1.0.3" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass-sized";
    key = "minipass-sized/1.0.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-MbkQQ2CTiBMlA2Dm/5cY+9SWFEN8pzzOXi6rlM5Xxq0Yqbda5ZQy9sU75a673FE9ZK0Zsbr6Y5iP6u9nktfg2g==";
      sha512 = "MbkQQ2CTiBMlA2Dm/5cY+9SWFEN8pzzOXi6rlM5Xxq0Yqbda5ZQy9sU75a673FE9ZK0Zsbr6Y5iP6u9nktfg2g==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass-sized/-/minipass-sized-1.0.3.tgz";
    };
    version = "1.0.3";
  };
  "minipass/3.3.4" = {
    depInfo = {
      yallist = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minipass";
    key = "minipass/3.3.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-I9WPbWHCGu8W+6k1ZiGpPu0GkoKBeorkfKNuAFBNS1HNFJvke82sxvI5bzcCNpWPorkOO5QQ+zomzzwRxejXiw==";
      sha512 = "I9WPbWHCGu8W+6k1ZiGpPu0GkoKBeorkfKNuAFBNS1HNFJvke82sxvI5bzcCNpWPorkOO5QQ+zomzzwRxejXiw==";
      type = "tarball";
      url = "https://registry.npmjs.org/minipass/-/minipass-3.3.4.tgz";
    };
    version = "3.3.4";
  };
  "minizlib/2.1.2" = {
    depInfo = {
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      yallist = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "minizlib";
    key = "minizlib/2.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-bAxsR8BVfj60DWXHE3u30oHzfl4G7khkSuPW+qvpd7jFRHm7dLxOjUk1EHACJ/hxLY8phGJ0YhYHZo7jil7Qdg==";
      sha512 = "bAxsR8BVfj60DWXHE3u30oHzfl4G7khkSuPW+qvpd7jFRHm7dLxOjUk1EHACJ/hxLY8phGJ0YhYHZo7jil7Qdg==";
      type = "tarball";
      url = "https://registry.npmjs.org/minizlib/-/minizlib-2.1.2.tgz";
    };
    version = "2.1.2";
  };
  "mkdirp/1.0.4" = {
    bin = {
      mkdirp = "bin/cmd.js";
    };
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "mkdirp";
    key = "mkdirp/1.0.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-vVqVZQyf3WLx2Shd0qJ9xuvqgAyKPLAiqITEtqW0oIUjzo3PePDd6fW9iFz30ef7Ysp/oiWqbhszeGWW2T6Gzw==";
      sha512 = "vVqVZQyf3WLx2Shd0qJ9xuvqgAyKPLAiqITEtqW0oIUjzo3PePDd6fW9iFz30ef7Ysp/oiWqbhszeGWW2T6Gzw==";
      type = "tarball";
      url = "https://registry.npmjs.org/mkdirp/-/mkdirp-1.0.4.tgz";
    };
    version = "1.0.4";
  };
  "ms/2.1.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "ms";
    key = "ms/2.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w==";
      sha512 = "sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w==";
      type = "tarball";
      url = "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz";
    };
    version = "2.1.2";
  };
  "negotiator/0.6.3" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "negotiator";
    key = "negotiator/0.6.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg==";
      sha512 = "+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg==";
      type = "tarball";
      url = "https://registry.npmjs.org/negotiator/-/negotiator-0.6.3.tgz";
    };
    version = "0.6.3";
  };
  "node-gyp/8.4.1" = {
    bin = {
      node-gyp = "bin/node-gyp.js";
    };
    depInfo = {
      env-paths = {
        descriptor = "^2.2.0";
        runtime = true;
      };
      glob = {
        descriptor = "^7.1.4";
        runtime = true;
      };
      graceful-fs = {
        descriptor = "^4.2.6";
        runtime = true;
      };
      make-fetch-happen = {
        descriptor = "^9.1.0";
        runtime = true;
      };
      nopt = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      npmlog = {
        descriptor = "^6.0.0";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
      tar = {
        descriptor = "^6.1.2";
        runtime = true;
      };
      which = {
        descriptor = "^2.0.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "node-gyp";
    key = "node-gyp/8.4.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-olTJRgUtAb/hOXG0E93wZDs5YiJlgbXxTwQAFHyNlRsXQnYzUaF2aGgujZbw+hR8aF4ZG/rST57bWMWD16jr9w==";
      sha512 = "olTJRgUtAb/hOXG0E93wZDs5YiJlgbXxTwQAFHyNlRsXQnYzUaF2aGgujZbw+hR8aF4ZG/rST57bWMWD16jr9w==";
      type = "tarball";
      url = "https://registry.npmjs.org/node-gyp/-/node-gyp-8.4.1.tgz";
    };
    version = "8.4.1";
  };
  "nopt/5.0.0" = {
    bin = {
      nopt = "bin/nopt.js";
    };
    depInfo = {
      abbrev = {
        descriptor = "1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "nopt";
    key = "nopt/5.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Tbj67rffqceeLpcRXrT7vKAN8CwfPeIBgM7E6iBkmKLV7bEMwpGgYLGv0jACUsECaa/vuxP0IjEont6umdMgtQ==";
      sha512 = "Tbj67rffqceeLpcRXrT7vKAN8CwfPeIBgM7E6iBkmKLV7bEMwpGgYLGv0jACUsECaa/vuxP0IjEont6umdMgtQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/nopt/-/nopt-5.0.0.tgz";
    };
    version = "5.0.0";
  };
  "normalize-package-data/4.0.1" = {
    depInfo = {
      hosted-git-info = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      is-core-module = {
        descriptor = "^2.8.1";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
      validate-npm-package-license = {
        descriptor = "^3.0.4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "normalize-package-data";
    key = "normalize-package-data/4.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-EBk5QKKuocMJhB3BILuKhmaPjI8vNRSpIfO9woLC6NyHVkKKdVEdAO1mrT0ZfxNR1lKwCcTkuZfmGIFdizZ8Pg==";
      sha512 = "EBk5QKKuocMJhB3BILuKhmaPjI8vNRSpIfO9woLC6NyHVkKKdVEdAO1mrT0ZfxNR1lKwCcTkuZfmGIFdizZ8Pg==";
      type = "tarball";
      url = "https://registry.npmjs.org/normalize-package-data/-/normalize-package-data-4.0.1.tgz";
    };
    version = "4.0.1";
  };
  "npm-bundled/1.1.2" = {
    depInfo = {
      npm-normalize-package-bin = {
        descriptor = "^1.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-bundled";
    key = "npm-bundled/1.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-x5DHup0SuyQcmL3s7Rx/YQ8sbw/Hzg0rj48eN0dV7hf5cmQq5PXIeioroH3raV1QC1yh3uTYuMThvEQF3iKgGQ==";
      sha512 = "x5DHup0SuyQcmL3s7Rx/YQ8sbw/Hzg0rj48eN0dV7hf5cmQq5PXIeioroH3raV1QC1yh3uTYuMThvEQF3iKgGQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-bundled/-/npm-bundled-1.1.2.tgz";
    };
    version = "1.1.2";
  };
  "npm-bundled/2.0.1" = {
    depInfo = {
      npm-normalize-package-bin = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-bundled";
    key = "npm-bundled/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-gZLxXdjEzE/+mOstGDqR6b0EkhJ+kM6fxM6vUuckuctuVPh80Q6pw/rSZj9s4Gex9GxWtIicO1pc8DB9KZWudw==";
      sha512 = "gZLxXdjEzE/+mOstGDqR6b0EkhJ+kM6fxM6vUuckuctuVPh80Q6pw/rSZj9s4Gex9GxWtIicO1pc8DB9KZWudw==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-bundled/-/npm-bundled-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "npm-install-checks/5.0.0" = {
    depInfo = {
      semver = {
        descriptor = "^7.1.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-install-checks";
    key = "npm-install-checks/5.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-65lUsMI8ztHCxFz5ckCEC44DRvEGdZX5usQFriauxHEwt7upv1FKaQEmAtU0YnOAdwuNWCmk64xYiQABNrEyLA==";
      sha512 = "65lUsMI8ztHCxFz5ckCEC44DRvEGdZX5usQFriauxHEwt7upv1FKaQEmAtU0YnOAdwuNWCmk64xYiQABNrEyLA==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-install-checks/-/npm-install-checks-5.0.0.tgz";
    };
    version = "5.0.0";
  };
  "npm-normalize-package-bin/1.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-normalize-package-bin";
    key = "npm-normalize-package-bin/1.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-EPfafl6JL5/rU+ot6P3gRSCpPDW5VmIzX959Ob1+ySFUuuYHWHekXpwdUZcKP5C+DS4GEtdJluwBjnsNDl+fSA==";
      sha512 = "EPfafl6JL5/rU+ot6P3gRSCpPDW5VmIzX959Ob1+ySFUuuYHWHekXpwdUZcKP5C+DS4GEtdJluwBjnsNDl+fSA==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-normalize-package-bin/-/npm-normalize-package-bin-1.0.1.tgz";
    };
    version = "1.0.1";
  };
  "npm-normalize-package-bin/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-normalize-package-bin";
    key = "npm-normalize-package-bin/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-awzfKUO7v0FscrSpRoogyNm0sajikhBWpU0QMrW09AMi9n1PoKU6WaIqUzuJSQnpciZZmJ/jMZ2Egfmb/9LiWQ==";
      sha512 = "awzfKUO7v0FscrSpRoogyNm0sajikhBWpU0QMrW09AMi9n1PoKU6WaIqUzuJSQnpciZZmJ/jMZ2Egfmb/9LiWQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-normalize-package-bin/-/npm-normalize-package-bin-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "npm-package-arg/9.1.2" = {
    depInfo = {
      hosted-git-info = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      proc-log = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
      validate-npm-package-name = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-package-arg";
    key = "npm-package-arg/9.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-pzd9rLEx4TfNJkovvlBSLGhq31gGu2QDexFPWT19yCDh0JgnRhlBLNo5759N0AJmBk+kQ9Y/hXoLnlgFD+ukmg==";
      sha512 = "pzd9rLEx4TfNJkovvlBSLGhq31gGu2QDexFPWT19yCDh0JgnRhlBLNo5759N0AJmBk+kQ9Y/hXoLnlgFD+ukmg==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-package-arg/-/npm-package-arg-9.1.2.tgz";
    };
    version = "9.1.2";
  };
  "npm-packlist/5.1.3" = {
    bin = {
      npm-packlist = "bin/index.js";
    };
    depInfo = {
      glob = {
        descriptor = "^8.0.1";
        runtime = true;
      };
      ignore-walk = {
        descriptor = "^5.0.1";
        runtime = true;
      };
      npm-bundled = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      npm-normalize-package-bin = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "npm-packlist";
    key = "npm-packlist/5.1.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-263/0NGrn32YFYi4J533qzrQ/krmmrWwhKkzwTuM4f/07ug51odoaNjUexxO4vxlzURHcmYMH1QjvHjsNDKLVg==";
      sha512 = "263/0NGrn32YFYi4J533qzrQ/krmmrWwhKkzwTuM4f/07ug51odoaNjUexxO4vxlzURHcmYMH1QjvHjsNDKLVg==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-packlist/-/npm-packlist-5.1.3.tgz";
    };
    version = "5.1.3";
  };
  "npm-pick-manifest/7.0.2" = {
    depInfo = {
      npm-install-checks = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      npm-normalize-package-bin = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      npm-package-arg = {
        descriptor = "^9.0.0";
        runtime = true;
      };
      semver = {
        descriptor = "^7.3.5";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-pick-manifest";
    key = "npm-pick-manifest/7.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-gk37SyRmlIjvTfcYl6RzDbSmS9Y4TOBXfsPnoYqTHARNgWbyDiCSMLUpmALDj4jjcTZpURiEfsSHJj9k7EV4Rw==";
      sha512 = "gk37SyRmlIjvTfcYl6RzDbSmS9Y4TOBXfsPnoYqTHARNgWbyDiCSMLUpmALDj4jjcTZpURiEfsSHJj9k7EV4Rw==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-pick-manifest/-/npm-pick-manifest-7.0.2.tgz";
    };
    version = "7.0.2";
  };
  "npm-registry-fetch/13.3.1" = {
    depInfo = {
      make-fetch-happen = {
        descriptor = "^10.0.6";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.6";
        runtime = true;
      };
      minipass-fetch = {
        descriptor = "^2.0.3";
        runtime = true;
      };
      minipass-json-stream = {
        descriptor = "^1.0.1";
        runtime = true;
      };
      minizlib = {
        descriptor = "^2.1.2";
        runtime = true;
      };
      npm-package-arg = {
        descriptor = "^9.0.1";
        runtime = true;
      };
      proc-log = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npm-registry-fetch";
    key = "npm-registry-fetch/13.3.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-eukJPi++DKRTjSBRcDZSDDsGqRK3ehbxfFUcgaRd0Yp6kRwOwh2WVn0r+8rMB4nnuzvAk6rQVzl6K5CkYOmnvw==";
      sha512 = "eukJPi++DKRTjSBRcDZSDDsGqRK3ehbxfFUcgaRd0Yp6kRwOwh2WVn0r+8rMB4nnuzvAk6rQVzl6K5CkYOmnvw==";
      type = "tarball";
      url = "https://registry.npmjs.org/npm-registry-fetch/-/npm-registry-fetch-13.3.1.tgz";
    };
    version = "13.3.1";
  };
  "npmlog/6.0.2" = {
    depInfo = {
      are-we-there-yet = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      console-control-strings = {
        descriptor = "^1.1.0";
        runtime = true;
      };
      gauge = {
        descriptor = "^4.0.3";
        runtime = true;
      };
      set-blocking = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "npmlog";
    key = "npmlog/6.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-/vBvz5Jfr9dT/aFWd0FIRf+T/Q2WBsLENygUaFUqstqsycmZAP/t5BvFJTK0viFmSUxiUKTUplWy5vt+rvKIxg==";
      sha512 = "/vBvz5Jfr9dT/aFWd0FIRf+T/Q2WBsLENygUaFUqstqsycmZAP/t5BvFJTK0viFmSUxiUKTUplWy5vt+rvKIxg==";
      type = "tarball";
      url = "https://registry.npmjs.org/npmlog/-/npmlog-6.0.2.tgz";
    };
    version = "6.0.2";
  };
  "once/1.4.0" = {
    depInfo = {
      wrappy = {
        descriptor = "1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "once";
    key = "once/1.4.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==";
      sha512 = "lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==";
      type = "tarball";
      url = "https://registry.npmjs.org/once/-/once-1.4.0.tgz";
    };
    version = "1.4.0";
  };
  "p-map/4.0.0" = {
    depInfo = {
      aggregate-error = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "p-map";
    key = "p-map/4.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-/bjOqmgETBYB5BoEeGVea8dmvHb2m9GLy1E9W43yeyfP6QQCZGFNa+XRceJEuDB6zqr+gKpIAmlLebMpykw/MQ==";
      sha512 = "/bjOqmgETBYB5BoEeGVea8dmvHb2m9GLy1E9W43yeyfP6QQCZGFNa+XRceJEuDB6zqr+gKpIAmlLebMpykw/MQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/p-map/-/p-map-4.0.0.tgz";
    };
    version = "4.0.0";
  };
  "pacote/13.3.0" = {
    bin = {
      pacote = "lib/bin.js";
    };
    depInfo = {
      "@npmcli/git" = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      "@npmcli/installed-package-contents" = {
        descriptor = "^1.0.7";
        runtime = true;
      };
      "@npmcli/promise-spawn" = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      "@npmcli/run-script" = {
        descriptor = "^3.0.1";
        runtime = true;
      };
      cacache = {
        descriptor = "^16.0.0";
        runtime = true;
      };
      chownr = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      fs-minipass = {
        descriptor = "^2.1.0";
        runtime = true;
      };
      infer-owner = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.1.6";
        runtime = true;
      };
      mkdirp = {
        descriptor = "^1.0.4";
        runtime = true;
      };
      npm-package-arg = {
        descriptor = "^9.0.0";
        runtime = true;
      };
      npm-packlist = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      npm-pick-manifest = {
        descriptor = "^7.0.0";
        runtime = true;
      };
      npm-registry-fetch = {
        descriptor = "^13.0.1";
        runtime = true;
      };
      proc-log = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      promise-retry = {
        descriptor = "^2.0.1";
        runtime = true;
      };
      read-package-json = {
        descriptor = "^5.0.0";
        runtime = true;
      };
      read-package-json-fast = {
        descriptor = "^2.0.3";
        runtime = true;
      };
      rimraf = {
        descriptor = "^3.0.2";
        runtime = true;
      };
      ssri = {
        descriptor = "^9.0.0";
        runtime = true;
      };
      tar = {
        descriptor = "^6.1.11";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "pacote";
    key = "pacote/13.3.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-auhJAUlfC2TALo6I0s1vFoPvVFgWGx+uz/PnIojTTgkGwlK3Np8sGJ0ghfFhiuzJXTZoTycMLk8uLskdntPbDw==";
      sha512 = "auhJAUlfC2TALo6I0s1vFoPvVFgWGx+uz/PnIojTTgkGwlK3Np8sGJ0ghfFhiuzJXTZoTycMLk8uLskdntPbDw==";
      type = "tarball";
      url = "https://registry.npmjs.org/pacote/-/pacote-13.3.0.tgz";
    };
    version = "13.3.0";
  };
  "path-is-absolute/1.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "path-is-absolute";
    key = "path-is-absolute/1.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-AVbw3UJ2e9bq64vSaS9Am0fje1Pa8pbGqTTsmXfaIiMpnr5DlDhfJOuLj9Sf95ZPVDAUerDfEk88MPmPe7UCQg==";
      sha512 = "AVbw3UJ2e9bq64vSaS9Am0fje1Pa8pbGqTTsmXfaIiMpnr5DlDhfJOuLj9Sf95ZPVDAUerDfEk88MPmPe7UCQg==";
      type = "tarball";
      url = "https://registry.npmjs.org/path-is-absolute/-/path-is-absolute-1.0.1.tgz";
    };
    version = "1.0.1";
  };
  "proc-log/2.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "proc-log";
    key = "proc-log/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Kcmo2FhfDTXdcbfDH76N7uBYHINxc/8GW7UAVuVP9I+Va3uHSerrnKV6dLooga/gh7GlgzuCCr/eoldnL1muGw==";
      sha512 = "Kcmo2FhfDTXdcbfDH76N7uBYHINxc/8GW7UAVuVP9I+Va3uHSerrnKV6dLooga/gh7GlgzuCCr/eoldnL1muGw==";
      type = "tarball";
      url = "https://registry.npmjs.org/proc-log/-/proc-log-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "promise-inflight/1.0.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "promise-inflight";
    key = "promise-inflight/1.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-6zWPyEOFaQBJYcGMHBKTKJ3u6TBsnMFOIZSa6ce1e/ZrrsOlnHRHbabMjLiBYKp+n44X9eUI6VUPaukCXHuG4g==";
      sha512 = "6zWPyEOFaQBJYcGMHBKTKJ3u6TBsnMFOIZSa6ce1e/ZrrsOlnHRHbabMjLiBYKp+n44X9eUI6VUPaukCXHuG4g==";
      type = "tarball";
      url = "https://registry.npmjs.org/promise-inflight/-/promise-inflight-1.0.1.tgz";
    };
    version = "1.0.1";
  };
  "promise-retry/2.0.1" = {
    depInfo = {
      err-code = {
        descriptor = "^2.0.2";
        runtime = true;
      };
      retry = {
        descriptor = "^0.12.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "promise-retry";
    key = "promise-retry/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-y+WKFlBR8BGXnsNlIHFGPZmyDf3DFMoLhaflAnyZgV6rG6xu+JwesTo2Q9R6XwYmtmwAFCkAk3e35jEdoeh/3g==";
      sha512 = "y+WKFlBR8BGXnsNlIHFGPZmyDf3DFMoLhaflAnyZgV6rG6xu+JwesTo2Q9R6XwYmtmwAFCkAk3e35jEdoeh/3g==";
      type = "tarball";
      url = "https://registry.npmjs.org/promise-retry/-/promise-retry-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "read-package-json-fast/2.0.3" = {
    depInfo = {
      json-parse-even-better-errors = {
        descriptor = "^2.3.0";
        runtime = true;
      };
      npm-normalize-package-bin = {
        descriptor = "^1.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "read-package-json-fast";
    key = "read-package-json-fast/2.0.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-W/BKtbL+dUjTuRL2vziuYhp76s5HZ9qQhd/dKfWIZveD0O40453QNyZhC0e63lqZrAQ4jiOapVoeJ7JrszenQQ==";
      sha512 = "W/BKtbL+dUjTuRL2vziuYhp76s5HZ9qQhd/dKfWIZveD0O40453QNyZhC0e63lqZrAQ4jiOapVoeJ7JrszenQQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/read-package-json-fast/-/read-package-json-fast-2.0.3.tgz";
    };
    version = "2.0.3";
  };
  "read-package-json/5.0.2" = {
    depInfo = {
      glob = {
        descriptor = "^8.0.1";
        runtime = true;
      };
      json-parse-even-better-errors = {
        descriptor = "^2.3.1";
        runtime = true;
      };
      normalize-package-data = {
        descriptor = "^4.0.0";
        runtime = true;
      };
      npm-normalize-package-bin = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "read-package-json";
    key = "read-package-json/5.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-BSzugrt4kQ/Z0krro8zhTwV1Kd79ue25IhNN/VtHFy1mG/6Tluyi+msc0UpwaoQzxSHa28mntAjIZY6kEgfR9Q==";
      sha512 = "BSzugrt4kQ/Z0krro8zhTwV1Kd79ue25IhNN/VtHFy1mG/6Tluyi+msc0UpwaoQzxSHa28mntAjIZY6kEgfR9Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/read-package-json/-/read-package-json-5.0.2.tgz";
    };
    version = "5.0.2";
  };
  "readable-stream/3.6.0" = {
    depInfo = {
      inherits = {
        descriptor = "^2.0.3";
        runtime = true;
      };
      string_decoder = {
        descriptor = "^1.1.1";
        runtime = true;
      };
      util-deprecate = {
        descriptor = "^1.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "readable-stream";
    key = "readable-stream/3.6.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-BViHy7LKeTz4oNnkcLJ+lVSL6vpiFeX6/d3oSH8zCW7UxP2onchk+vTGB143xuFjHS3deTgkKoXXymXqymiIdA==";
      sha512 = "BViHy7LKeTz4oNnkcLJ+lVSL6vpiFeX6/d3oSH8zCW7UxP2onchk+vTGB143xuFjHS3deTgkKoXXymXqymiIdA==";
      type = "tarball";
      url = "https://registry.npmjs.org/readable-stream/-/readable-stream-3.6.0.tgz";
    };
    version = "3.6.0";
  };
  "retry/0.12.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "retry";
    key = "retry/0.12.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-9LkiTwjUh6rT555DtE9rTX+BKByPfrMzEAtnlEtdEwr3Nkffwiihqe2bWADg+OQRjt9gl6ICdmB/ZFDCGAtSow==";
      sha512 = "9LkiTwjUh6rT555DtE9rTX+BKByPfrMzEAtnlEtdEwr3Nkffwiihqe2bWADg+OQRjt9gl6ICdmB/ZFDCGAtSow==";
      type = "tarball";
      url = "https://registry.npmjs.org/retry/-/retry-0.12.0.tgz";
    };
    version = "0.12.0";
  };
  "rimraf/3.0.2" = {
    bin = {
      rimraf = "bin.js";
    };
    depInfo = {
      glob = {
        descriptor = "^7.1.3";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "rimraf";
    key = "rimraf/3.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-JZkJMZkAGFFPP2YqXZXPbMlMBgsxzE8ILs4lMIX/2o0L9UBw9O/Y3o6wFw/i9YLapcUJWwqbi3kdxIPdC62TIA==";
      sha512 = "JZkJMZkAGFFPP2YqXZXPbMlMBgsxzE8ILs4lMIX/2o0L9UBw9O/Y3o6wFw/i9YLapcUJWwqbi3kdxIPdC62TIA==";
      type = "tarball";
      url = "https://registry.npmjs.org/rimraf/-/rimraf-3.0.2.tgz";
    };
    version = "3.0.2";
  };
  "safe-buffer/5.2.1" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "safe-buffer";
    key = "safe-buffer/5.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ==";
      sha512 = "rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/safe-buffer/-/safe-buffer-5.2.1.tgz";
    };
    version = "5.2.1";
  };
  "safer-buffer/2.1.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "safer-buffer";
    key = "safer-buffer/2.1.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-YZo3K82SD7Riyi0E1EQPojLz7kpepnSQI9IyPbHHg1XXXevb5dJI7tpyN2ADxGcQbHG7vcyRHk0cbwqcQriUtg==";
      sha512 = "YZo3K82SD7Riyi0E1EQPojLz7kpepnSQI9IyPbHHg1XXXevb5dJI7tpyN2ADxGcQbHG7vcyRHk0cbwqcQriUtg==";
      type = "tarball";
      url = "https://registry.npmjs.org/safer-buffer/-/safer-buffer-2.1.2.tgz";
    };
    version = "2.1.2";
  };
  "semver/7.3.8" = {
    bin = {
      semver = "bin/semver.js";
    };
    depInfo = {
      lru-cache = {
        descriptor = "^6.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "semver";
    key = "semver/7.3.8";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-NB1ctGL5rlHrPJtFDVIVzTyQylMLu9N9VICA6HSFJo8MCGVTMW6gfpicwKmmK/dAjTOrqu5l63JJOpDSrAis3A==";
      sha512 = "NB1ctGL5rlHrPJtFDVIVzTyQylMLu9N9VICA6HSFJo8MCGVTMW6gfpicwKmmK/dAjTOrqu5l63JJOpDSrAis3A==";
      type = "tarball";
      url = "https://registry.npmjs.org/semver/-/semver-7.3.8.tgz";
    };
    version = "7.3.8";
  };
  "set-blocking/2.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "set-blocking";
    key = "set-blocking/2.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-KiKBS8AnWGEyLzofFfmvKwpdPzqiy16LvQfK3yv/fVH7Bj13/wl3JSR1J+rfgRE9q7xUJK4qvgS8raSOeLUehw==";
      sha512 = "KiKBS8AnWGEyLzofFfmvKwpdPzqiy16LvQfK3yv/fVH7Bj13/wl3JSR1J+rfgRE9q7xUJK4qvgS8raSOeLUehw==";
      type = "tarball";
      url = "https://registry.npmjs.org/set-blocking/-/set-blocking-2.0.0.tgz";
    };
    version = "2.0.0";
  };
  "signal-exit/3.0.7" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "signal-exit";
    key = "signal-exit/3.0.7";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-wnD2ZE+l+SPC/uoS0vXeE9L1+0wuaMqKlfz9AMUo38JsyLSBWSFcHR1Rri62LZc12vLr1gb3jl7iwQhgwpAbGQ==";
      sha512 = "wnD2ZE+l+SPC/uoS0vXeE9L1+0wuaMqKlfz9AMUo38JsyLSBWSFcHR1Rri62LZc12vLr1gb3jl7iwQhgwpAbGQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/signal-exit/-/signal-exit-3.0.7.tgz";
    };
    version = "3.0.7";
  };
  "smart-buffer/4.2.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "smart-buffer";
    key = "smart-buffer/4.2.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-94hK0Hh8rPqQl2xXc3HsaBoOXKV20MToPkcXvwbISWLEs+64sBq5kFgn2kJDHb1Pry9yrP0dxrCI9RRci7RXKg==";
      sha512 = "94hK0Hh8rPqQl2xXc3HsaBoOXKV20MToPkcXvwbISWLEs+64sBq5kFgn2kJDHb1Pry9yrP0dxrCI9RRci7RXKg==";
      type = "tarball";
      url = "https://registry.npmjs.org/smart-buffer/-/smart-buffer-4.2.0.tgz";
    };
    version = "4.2.0";
  };
  "socks-proxy-agent/6.2.1" = {
    depInfo = {
      agent-base = {
        descriptor = "^6.0.2";
        runtime = true;
      };
      debug = {
        descriptor = "^4.3.3";
        runtime = true;
      };
      socks = {
        descriptor = "^2.6.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "socks-proxy-agent";
    key = "socks-proxy-agent/6.2.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-a6KW9G+6B3nWZ1yB8G7pJwL3ggLy1uTzKAgCb7ttblwqdz9fMGJUuTy3uFzEP48FAs9FLILlmzDlE2JJhVQaXQ==";
      sha512 = "a6KW9G+6B3nWZ1yB8G7pJwL3ggLy1uTzKAgCb7ttblwqdz9fMGJUuTy3uFzEP48FAs9FLILlmzDlE2JJhVQaXQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/socks-proxy-agent/-/socks-proxy-agent-6.2.1.tgz";
    };
    version = "6.2.1";
  };
  "socks-proxy-agent/7.0.0" = {
    depInfo = {
      agent-base = {
        descriptor = "^6.0.2";
        runtime = true;
      };
      debug = {
        descriptor = "^4.3.3";
        runtime = true;
      };
      socks = {
        descriptor = "^2.6.2";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "socks-proxy-agent";
    key = "socks-proxy-agent/7.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Fgl0YPZ902wEsAyiQ+idGd1A7rSFx/ayC1CQVMw5P+EQx2V0SgpGtf6OKFhVjPflPUl9YMmEOnmfjCdMUsygww==";
      sha512 = "Fgl0YPZ902wEsAyiQ+idGd1A7rSFx/ayC1CQVMw5P+EQx2V0SgpGtf6OKFhVjPflPUl9YMmEOnmfjCdMUsygww==";
      type = "tarball";
      url = "https://registry.npmjs.org/socks-proxy-agent/-/socks-proxy-agent-7.0.0.tgz";
    };
    version = "7.0.0";
  };
  "socks/2.7.1" = {
    depInfo = {
      ip = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      smart-buffer = {
        descriptor = "^4.2.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "socks";
    key = "socks/2.7.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-7maUZy1N7uo6+WVEX6psASxtNlKaNVMlGQKkG/63nEDdLOWNbiUMoLK7X4uYoLhQstau72mLgfEWcXcwsaHbYQ==";
      sha512 = "7maUZy1N7uo6+WVEX6psASxtNlKaNVMlGQKkG/63nEDdLOWNbiUMoLK7X4uYoLhQstau72mLgfEWcXcwsaHbYQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/socks/-/socks-2.7.1.tgz";
    };
    version = "2.7.1";
  };
  "spdx-correct/3.1.1" = {
    depInfo = {
      spdx-expression-parse = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      spdx-license-ids = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "spdx-correct";
    key = "spdx-correct/3.1.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-cOYcUWwhCuHCXi49RhFRCyJEK3iPj1Ziz9DpViV3tbZOwXD49QzIN3MpOLJNxh2qwq2lJJZaKMVw9qNi4jTC0w==";
      sha512 = "cOYcUWwhCuHCXi49RhFRCyJEK3iPj1Ziz9DpViV3tbZOwXD49QzIN3MpOLJNxh2qwq2lJJZaKMVw9qNi4jTC0w==";
      type = "tarball";
      url = "https://registry.npmjs.org/spdx-correct/-/spdx-correct-3.1.1.tgz";
    };
    version = "3.1.1";
  };
  "spdx-exceptions/2.3.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "spdx-exceptions";
    key = "spdx-exceptions/2.3.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-/tTrYOC7PPI1nUAgx34hUpqXuyJG+DTHJTnIULG4rDygi4xu/tfgmq1e1cIRwRzwZgo4NLySi+ricLkZkw4i5A==";
      sha512 = "/tTrYOC7PPI1nUAgx34hUpqXuyJG+DTHJTnIULG4rDygi4xu/tfgmq1e1cIRwRzwZgo4NLySi+ricLkZkw4i5A==";
      type = "tarball";
      url = "https://registry.npmjs.org/spdx-exceptions/-/spdx-exceptions-2.3.0.tgz";
    };
    version = "2.3.0";
  };
  "spdx-expression-parse/3.0.1" = {
    depInfo = {
      spdx-exceptions = {
        descriptor = "^2.1.0";
        runtime = true;
      };
      spdx-license-ids = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "spdx-expression-parse";
    key = "spdx-expression-parse/3.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-cbqHunsQWnJNE6KhVSMsMeH5H/L9EpymbzqTQ3uLwNCLZ1Q481oWaofqH7nO6V07xlXwY6PhQdQ2IedWx/ZK4Q==";
      sha512 = "cbqHunsQWnJNE6KhVSMsMeH5H/L9EpymbzqTQ3uLwNCLZ1Q481oWaofqH7nO6V07xlXwY6PhQdQ2IedWx/ZK4Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/spdx-expression-parse/-/spdx-expression-parse-3.0.1.tgz";
    };
    version = "3.0.1";
  };
  "spdx-license-ids/3.0.12" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "spdx-license-ids";
    key = "spdx-license-ids/3.0.12";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-rr+VVSXtRhO4OHbXUiAF7xW3Bo9DuuF6C5jH+q/x15j2jniycgKbxU09Hr0WqlSLUs4i4ltHGXqTe7VHclYWyA==";
      sha512 = "rr+VVSXtRhO4OHbXUiAF7xW3Bo9DuuF6C5jH+q/x15j2jniycgKbxU09Hr0WqlSLUs4i4ltHGXqTe7VHclYWyA==";
      type = "tarball";
      url = "https://registry.npmjs.org/spdx-license-ids/-/spdx-license-ids-3.0.12.tgz";
    };
    version = "3.0.12";
  };
  "ssri/8.0.1" = {
    depInfo = {
      minipass = {
        descriptor = "^3.1.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "ssri";
    key = "ssri/8.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-97qShzy1AiyxvPNIkLWoGua7xoQzzPjQ0HAH4B0rWKo7SZ6USuPcrUiAFrws0UH8RrbWmgq3LMTObhPIHbbBeQ==";
      sha512 = "97qShzy1AiyxvPNIkLWoGua7xoQzzPjQ0HAH4B0rWKo7SZ6USuPcrUiAFrws0UH8RrbWmgq3LMTObhPIHbbBeQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/ssri/-/ssri-8.0.1.tgz";
    };
    version = "8.0.1";
  };
  "ssri/9.0.1" = {
    depInfo = {
      minipass = {
        descriptor = "^3.1.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "ssri";
    key = "ssri/9.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-o57Wcn66jMQvfHG1FlYbWeZWW/dHZhJXjpIcTfXldXEk5nz5lStPo3mK0OJQfGR3RbZUlbISexbljkJzuEj/8Q==";
      sha512 = "o57Wcn66jMQvfHG1FlYbWeZWW/dHZhJXjpIcTfXldXEk5nz5lStPo3mK0OJQfGR3RbZUlbISexbljkJzuEj/8Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/ssri/-/ssri-9.0.1.tgz";
    };
    version = "9.0.1";
  };
  "string-width/4.2.3" = {
    depInfo = {
      emoji-regex = {
        descriptor = "^8.0.0";
        runtime = true;
      };
      is-fullwidth-code-point = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      strip-ansi = {
        descriptor = "^6.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "string-width";
    key = "string-width/4.2.3";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g==";
      sha512 = "wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g==";
      type = "tarball";
      url = "https://registry.npmjs.org/string-width/-/string-width-4.2.3.tgz";
    };
    version = "4.2.3";
  };
  "string_decoder/1.3.0" = {
    depInfo = {
      safe-buffer = {
        descriptor = "~5.2.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "string_decoder";
    key = "string_decoder/1.3.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==";
      sha512 = "hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==";
      type = "tarball";
      url = "https://registry.npmjs.org/string_decoder/-/string_decoder-1.3.0.tgz";
    };
    version = "1.3.0";
  };
  "strip-ansi/6.0.1" = {
    depInfo = {
      ansi-regex = {
        descriptor = "^5.0.1";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "strip-ansi";
    key = "strip-ansi/6.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A==";
      sha512 = "Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A==";
      type = "tarball";
      url = "https://registry.npmjs.org/strip-ansi/-/strip-ansi-6.0.1.tgz";
    };
    version = "6.0.1";
  };
  "tar/6.1.12" = {
    depInfo = {
      chownr = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      fs-minipass = {
        descriptor = "^2.0.0";
        runtime = true;
      };
      minipass = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      minizlib = {
        descriptor = "^2.1.1";
        runtime = true;
      };
      mkdirp = {
        descriptor = "^1.0.3";
        runtime = true;
      };
      yallist = {
        descriptor = "^4.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "tar";
    key = "tar/6.1.12";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-jU4TdemS31uABHd+Lt5WEYJuzn+TJTCBLljvIAHZOz6M9Os5pJ4dD+vRFLxPa/n3T0iEFzpi+0x1UfuDZYbRMw==";
      sha512 = "jU4TdemS31uABHd+Lt5WEYJuzn+TJTCBLljvIAHZOz6M9Os5pJ4dD+vRFLxPa/n3T0iEFzpi+0x1UfuDZYbRMw==";
      type = "tarball";
      url = "https://registry.npmjs.org/tar/-/tar-6.1.12.tgz";
    };
    version = "6.1.12";
  };
  "unique-filename/1.1.1" = {
    depInfo = {
      unique-slug = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "unique-filename";
    key = "unique-filename/1.1.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-Vmp0jIp2ln35UTXuryvjzkjGdRyf9b2lTXuSYUiPmzRcl3FDtYqAwOnTJkAngD9SWhnoJzDbTKwaOrZ+STtxNQ==";
      sha512 = "Vmp0jIp2ln35UTXuryvjzkjGdRyf9b2lTXuSYUiPmzRcl3FDtYqAwOnTJkAngD9SWhnoJzDbTKwaOrZ+STtxNQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/unique-filename/-/unique-filename-1.1.1.tgz";
    };
    version = "1.1.1";
  };
  "unique-filename/2.0.1" = {
    depInfo = {
      unique-slug = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "unique-filename";
    key = "unique-filename/2.0.1";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-ODWHtkkdx3IAR+veKxFV+VBkUMcN+FaqzUUd7IZzt+0zhDZFPFxhlqwPF3YQvMHx1TD0tdgYl+kuPnJ8E6ql7A==";
      sha512 = "ODWHtkkdx3IAR+veKxFV+VBkUMcN+FaqzUUd7IZzt+0zhDZFPFxhlqwPF3YQvMHx1TD0tdgYl+kuPnJ8E6ql7A==";
      type = "tarball";
      url = "https://registry.npmjs.org/unique-filename/-/unique-filename-2.0.1.tgz";
    };
    version = "2.0.1";
  };
  "unique-slug/2.0.2" = {
    depInfo = {
      imurmurhash = {
        descriptor = "^0.1.4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "unique-slug";
    key = "unique-slug/2.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-zoWr9ObaxALD3DOPfjPSqxt4fnZiWblxHIgeWqW8x7UqDzEtHEQLzji2cuJYQFCU6KmoJikOYAZlrTHHebjx2w==";
      sha512 = "zoWr9ObaxALD3DOPfjPSqxt4fnZiWblxHIgeWqW8x7UqDzEtHEQLzji2cuJYQFCU6KmoJikOYAZlrTHHebjx2w==";
      type = "tarball";
      url = "https://registry.npmjs.org/unique-slug/-/unique-slug-2.0.2.tgz";
    };
    version = "2.0.2";
  };
  "unique-slug/3.0.0" = {
    depInfo = {
      imurmurhash = {
        descriptor = "^0.1.4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "unique-slug";
    key = "unique-slug/3.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-8EyMynh679x/0gqE9fT9oilG+qEt+ibFyqjuVTsZn1+CMxH+XLlpvr2UZx4nVcCwTpx81nICr2JQFkM+HPLq4w==";
      sha512 = "8EyMynh679x/0gqE9fT9oilG+qEt+ibFyqjuVTsZn1+CMxH+XLlpvr2UZx4nVcCwTpx81nICr2JQFkM+HPLq4w==";
      type = "tarball";
      url = "https://registry.npmjs.org/unique-slug/-/unique-slug-3.0.0.tgz";
    };
    version = "3.0.0";
  };
  "util-deprecate/1.0.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "util-deprecate";
    key = "util-deprecate/1.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-EPD5q1uXyFxJpCrLnCc1nHnq3gOa6DZBocAIiI2TaSCA7VCJ1UJDMagCzIkXNsUYfD1daK//LTEQ8xiIbrHtcw==";
      sha512 = "EPD5q1uXyFxJpCrLnCc1nHnq3gOa6DZBocAIiI2TaSCA7VCJ1UJDMagCzIkXNsUYfD1daK//LTEQ8xiIbrHtcw==";
      type = "tarball";
      url = "https://registry.npmjs.org/util-deprecate/-/util-deprecate-1.0.2.tgz";
    };
    version = "1.0.2";
  };
  "validate-npm-package-license/3.0.4" = {
    depInfo = {
      spdx-correct = {
        descriptor = "^3.0.0";
        runtime = true;
      };
      spdx-expression-parse = {
        descriptor = "^3.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "validate-npm-package-license";
    key = "validate-npm-package-license/3.0.4";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-DpKm2Ui/xN7/HQKCtpZxoRWBhZ9Z0kqtygG8XCgNQ8ZlDnxuQmWhj566j8fN4Cu3/JmbhsDo7fcAJq4s9h27Ew==";
      sha512 = "DpKm2Ui/xN7/HQKCtpZxoRWBhZ9Z0kqtygG8XCgNQ8ZlDnxuQmWhj566j8fN4Cu3/JmbhsDo7fcAJq4s9h27Ew==";
      type = "tarball";
      url = "https://registry.npmjs.org/validate-npm-package-license/-/validate-npm-package-license-3.0.4.tgz";
    };
    version = "3.0.4";
  };
  "validate-npm-package-name/4.0.0" = {
    depInfo = {
      builtins = {
        descriptor = "^5.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "validate-npm-package-name";
    key = "validate-npm-package-name/4.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-mzR0L8ZDktZjpX4OB46KT+56MAhl4EIazWP/+G/HPGuvfdaqg4YsCdtOm6U9+LOFyYDoh4dpnpxZRB9MQQns5Q==";
      sha512 = "mzR0L8ZDktZjpX4OB46KT+56MAhl4EIazWP/+G/HPGuvfdaqg4YsCdtOm6U9+LOFyYDoh4dpnpxZRB9MQQns5Q==";
      type = "tarball";
      url = "https://registry.npmjs.org/validate-npm-package-name/-/validate-npm-package-name-4.0.0.tgz";
    };
    version = "4.0.0";
  };
  "which/2.0.2" = {
    bin = {
      node-which = "bin/node-which";
    };
    depInfo = {
      isexe = {
        descriptor = "^2.0.0";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    hasBin = true;
    ident = "which";
    key = "which/2.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-BLI3Tl1TW3Pvl70l3yq3Y64i+awpwXqsGBYWkkqMtnbXgrMD+yj7rhW0kuEDxzJaYXGjEW5ogapKNMEKNMjibA==";
      sha512 = "BLI3Tl1TW3Pvl70l3yq3Y64i+awpwXqsGBYWkkqMtnbXgrMD+yj7rhW0kuEDxzJaYXGjEW5ogapKNMEKNMjibA==";
      type = "tarball";
      url = "https://registry.npmjs.org/which/-/which-2.0.2.tgz";
    };
    version = "2.0.2";
  };
  "wide-align/1.1.5" = {
    depInfo = {
      string-width = {
        descriptor = "^1.0.2 || 2 || 3 || 4";
        runtime = true;
      };
    };
    entFromtype = "package-lock.json(v3)";
    ident = "wide-align";
    key = "wide-align/1.1.5";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-eDMORYaPNZ4sQIuuYPDHdQvf4gyCF9rEEV/yPxGfwPkRodwEgiMUUXTx/dex+Me0wxx53S+NgUHaP7y3MGlDmg==";
      sha512 = "eDMORYaPNZ4sQIuuYPDHdQvf4gyCF9rEEV/yPxGfwPkRodwEgiMUUXTx/dex+Me0wxx53S+NgUHaP7y3MGlDmg==";
      type = "tarball";
      url = "https://registry.npmjs.org/wide-align/-/wide-align-1.1.5.tgz";
    };
    version = "1.1.5";
  };
  "wrappy/1.0.2" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "wrappy";
    key = "wrappy/1.0.2";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-l4Sp/DRseor9wL6EvV2+TuQn63dMkPjZ/sp9XkghTEbV9KlPS1xUsZ3u7/IQO4wxtcFB4bgpQPRcR3QCvezPcQ==";
      sha512 = "l4Sp/DRseor9wL6EvV2+TuQn63dMkPjZ/sp9XkghTEbV9KlPS1xUsZ3u7/IQO4wxtcFB4bgpQPRcR3QCvezPcQ==";
      type = "tarball";
      url = "https://registry.npmjs.org/wrappy/-/wrappy-1.0.2.tgz";
    };
    version = "1.0.2";
  };
  "yallist/4.0.0" = {
    depInfo = { };
    entFromtype = "package-lock.json(v3)";
    ident = "yallist";
    key = "yallist/4.0.0";
    scoped = false;
    sourceInfo = {
      entSubtype = "registry-tarball";
      hash = "sha512-3wdGidZyq5PB084XLES5TpOSRA3wjXAlIWMhum2kRcv/41Sn2emQ0dycQW4uZXLejwKvg6EsvbdlVL+FYEct7A==";
      sha512 = "3wdGidZyq5PB084XLES5TpOSRA3wjXAlIWMhum2kRcv/41Sn2emQ0dycQW4uZXLejwKvg6EsvbdlVL+FYEct7A==";
      type = "tarball";
      url = "https://registry.npmjs.org/yallist/-/yallist-4.0.0.tgz";
    };
    version = "4.0.0";
  };
}
