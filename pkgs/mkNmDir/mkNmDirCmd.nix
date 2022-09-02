# ============================================================================ #
#
# Given an NM tree represented as an attrset of `{ <NM-PATH> = PKG; }'
# entries, produce a shell script which builds a `node_modules/' directory.
#
# The `PKG' value can be a `pkgEnt' attrset, or an attset with the fields
# `outPath' and ( if required ) `bin' ( normalized, see example below ), or in
# its simplest form a store path ( string, `outPath' of a prepared module ).
# NOTE: `outPath' will be copied/linked "as is", so do any building/node-gyp
# stuff first; in particular ensure that `bin' scripts have proper permissions
# and are patched using `patch-shebangs' or `patchShebangs'.
#
# It is recommended that you use this routine using input from `libtree' which
# is designed specifically for this purpose; but you are free to hack together
# any tree you'd like with various types of inputs.
#
# XXX: A single leading `node_modules/' path is ignored when creating the
# tree to make passing from a `package-lock.json(v3)' easy; if you omit this
# prefix you must do it for all entries because othewise we have to do a ton of
# conditional regex on every path.
# Use `node_modules/foo/node_modules/bar' for everything,
# or use `foo/node_modules/bar' for everything; do not mix them!
#
#
# ---------------------------------------------------------------------------- #
#
# An example tree with several types of `PKG' values:
#
#   tree = {
#     # Just a store path.
#     "node_modules/foo" = "/nix/store/XXXX...-foo";
#     # `fetchTree' output has an `outPath' field so this works too
#     "node_modules/@bar/bar-core" = builtins.fetchTree { ... };
#
#     # Nested deps
#     "node_modules/@bar/bar-core/node_modules/@bar/bar-utils" =
#       builtins.fetchTree { ... };
#
#     # With bins
#     "node_modules/@blub/quux" = {
#       outPath = builtins.fetchTree { ... };
#       bin.quux        = "./bin/main.js";
#       bin.quux-client = "./client/bin/client.js";
#     };
#
#     # local path with "normalized" bindir ( encoded as `__DIR__' ).
#     # See `libpkginfo' for more info about `__DIR__'.
#     "node_modules/@blub/quux-cli-extras" =
#       outPath = ( builtins.path {
#         path = ./custom-quux-cli;
#         filter = name: type: ( baseNameOf name ) != "node_modules";
#       } ).outPath;
#       # Points to `./custom-quux-cli/bin'. Pay attention to the quotes.
#       bin.__DIR__ = "./bin";
#     };
#
#     # From a `pkgEnt' ( see `mkNmDirFromWithSet' as well )
#     "node_modules/@my-pkgs/my-ent" = myPkgSet."@my-pkgs/my-ent/0.0.1";
#
#     # A nested dependency yanked from a `pkgSet' with an override.
#     "node_modules/bar/node_modules/baz" =
#       myPkgSet."baz/1.0.0".prepared.override { runScripts = ["my-script"]; };
#   };
#
#
# ---------------------------------------------------------------------------- #
{ lib
, coreutils
, lndir           # From `nixpkgs.xorg.lndir'
, ...
} @ globalArgs: let

# ---------------------------------------------------------------------------- #

  # Helpers to extract fields from tree entries.

  hasBin = { ignoreSubBins ? false }: path: ent: let
    split   = builtins.split "node_modules" path;
    nmDepth = builtins.length ( builtins.filter builtins.isList split );
  in ( ! builtins.isString ent ) &&
     ( ignoreSubBins -> ( nmDepth < 2 ) ) &&
     ( ent.meta.hasBin or ( ( ent.bin or ent.meta.bin or {} ) != {} ) );

  # Return the `bin' attrset for an entry.
  # XXX: FIlter using `hasBin' first.
  getBins = ent: ent.bin or ent.meta.bin or
                 ( throw "(mkNmDir:getBins) No bin attr in entry." );

  getFromdir = ent:
    if builtins.isString ent then assert lib.isStorePath ent; ent else
    ent.outPath or ent.prepared.outPath;

  getTodir = path: ent: let
    fromEnt = if builtins.isString ent then null else
              ent.ident or ent.name or ent.meta.ident or ent.meta.name or null;
    fromPath = lib.libplock.pathId path;
    subdir = if fromEnt != null then fromEnt else
             if fromPath != null then fromPath else
             # Since we have already stripped the `leading' "node_modules/"
             # path we expect to get `null' from `pathId' for inputs like
             # "@foo/bar" which have already been converted to their identifier.
             path;
  in "$node_modules_path/${subdir}";

  # Get bindir where a path's bins should be installed.
  # This will be the "parent" `node_modules/.bin' dir; for example:
  #   "@foo/bar/node_modules/@baz/quux"
  #   -->
  #   "$node_modules_path/@foo/bar/node_modules/.bin".
  # NOTE: this expects paths to be stripped beforehand.
  # NOTE: In my humble opinion, installing bins to anything other than the top
  # level `node_modules/' directory is a waste of effort for our builders.
  # In NPM and Yarn these bins are created because `[pre|post]install' scripts
  # and "recursive builds" ( workspaces ).
  # Our Nix builders run install and build scripts in isolation these aren't
  # necessary in the context of the build being executed.
  # `mkNmDirCmd' has a flag `ignoreSubBins' which will skip those subdirs.
  # With that in mind, this function is only called if we are creating subdirs.
  # There are of course wonky edge cases where someone may be trying to do
  # something evil with `resolve()' and `exec' using relative paths; but that's
  # note something we're going to deal with out of the box ( those edge cases
  # would break with global installs in other package managers as well ).
  getBindir = path: let
    parent  = lib.libplock.parentPath path;
  in if builtins.elem parent ["" null] then "$node_modules_path/.bin" else
     "$node_modules_path/${parent}/node_modules/.bin";

  # Remove leading `node_modules/' component from an attrset's keys.
  # If the first string doesn't have this prefix no stripping is performed.
  stripLeadingNmDirs = x: let
    inherit (builtins) listToAttrs attrValues mapAttrs;
    rename = name: value: {
      name = lib.libpath.stripComponents 1 name;
      inherit value;
    };
  in listToAttrs ( attrValues ( mapAttrs rename x ) );


# ---------------------------------------------------------------------------- #

  # Standard `addCmd' routines.
  # These are used to add a module from directory `from' to directory `to'.
  # The simplest example is:
  #   addCmd = from: to: ''cp -rT ${from} "${to}";''
  #   -->
  #   cp -rT /nix/store/XXXX...-bar "$out/@foo/bar";
  # NOTE: the `to' directory already exists when `addCmd' runs; this is why our
  #       example uses `cp -rT' to copy "files in `from/' into `to/'" rather
  #       than making `from' a subdir of `to'.

  # Be sure to quote your args; JavaScript programmers were raised in barns and
  # often put spaces in their directory names.
  _mkNmDirLinkCmd = lndir: from: to:
    ''${lndir}/bin/lndir -silent "${from}" "${to}";'';

  _mkNmDirCopyCmd = coreutils: from: to:
    ''${coreutils}/bin/cp -r --reflink=auto -T "${from}" "${to}";'';


# ---------------------------------------------------------------------------- #

  # Link a dir of binaries to bindir.
  _mkNmDirAddBinWithDirCmd = coreutils: path: ent: let
    bin = getBins ent;
    from = assert ( builtins.attrNames bin ) == ["__DIR__"];
           "${getFromdir ent}/${bin.__DIR__}";
  in ''${coreutils}/bin/ln -srf "${from}"/* -t "${getBindir path}/";'';

  # XXX: NPM has a bug, or at least an unspecificied edge case about how to
  #      handle conflicting bin names.
  # NPM has changed the behavior between patch versions in some cases, and
  # it's not worth trying to align; instead we simply wipe out existing
  # bins with whatever happens to be listed last.
  # If this causes problems in your project, clean up your dependency list.
  _mkNmDirAddBinNoDirsCmd = coreutils: path: ent: let
    bin   = getBins ent;
    bd    = getBindir path;
    fd    = getFromdir ent;
    addOne = name: relPath: let
      from = "${fd}/${relPath}";
      to   = "${bd}/${name}";
    in ''${coreutils}/bin/ln -srf "${from}" "${to}";'';
    cmds = builtins.attrValues ( builtins.mapAttrs addOne bin );
  in builtins.concatStringsSep "\n" cmds;

  # Handles either kind.
  _mkNmDirAddBinCmd = coreutils: path: ent: let
    ab = if ( getBins ent ) ? __DIR__ then _mkNmDirAddBinWithDirCmd
                                      else _mkNmDirAddBinNoDirsCmd;
  in ab coreutils path ent;

# ---------------------------------------------------------------------------- #

  _mkNmDirCmdWith = {
    tree
  # A function taking `from' and `to' as arguments, which should produce a shell
  # command that "adds" ( copies/links ) module FROM source directory TO
  # module directory.
  # See examples above.
  # NOTE: Use absolute paths to utilities, this command may be nested as a
  # hook in other derivations and you are NOT guaranteed to have `stdenv'
  # default path available - not even `coreutils'.
  , addCmd ? from: to: _mkNmDirLinkCmd lndir from to
  # Only handle top level `node_modules/.bin` dir.
  # This is what you want if  you're only using isolated Nix builders.
  # If you're creating an install script for use outside of Nix and you want
  # `npm rebuild' and similar commands to work you need those subdirs though.
  , ignoreSubBins ? false
  # For `package.json' inputs in pure eval mode, we may not know exactly which
  # bins need to be linked yet; so we have to perform additional checking and
  # globbing at runtime.
  # `package-lock.json' inputs don't need to check, and we can skip a lot of IO
  # by setting this to false, indicating that your `tree' never contains
  # `bin.__DIR__' entries.
  # NOTE: We do not process `directories.bin' - you need to normalize your tree
  # fields using `libpkginfo' before calling this.
  , handleBindir ? true
  # Same deal as `addCmd' but for handling bin links.
  # This is exposed in case you need to do something wonky like create wrapper
  # scripts; but I think it's unlikely that you'll need to.
  , addBinCmd ? path: ent:
      if handleBindir then _mkNmDirAddBinCmd       coreutils path ent
                      else _mkNmDirAddBinNoDirsCmd coreutils path ent
  # Hooks
  , preNmDir  ? ""
  , postNmDir ? ""
  # Input Drvs
  , coreutils ? globalArgs.coreutils
  , lndir     ? globalArgs.lndir
  , ...
  } @ args: let

    tree' = let
      doStrip = lib.hasPrefix "node_modules/"
                              ( builtins.head ( builtins.attrNames tree ) );
    in if doStrip then stripLeadingNmDirs tree else tree;

    haveBin = lib.filterAttrs ( hasBin { inherit ignoreSubBins; } ) tree';

    # Create directories in groups of 5 at time using `mkdir'.
    # We cannot just dump all of them on the CLI because we'll blow it out; but
    # this essentially behaves like `xargs' to avoid long line limit.
    mkdirs = dirs: let
      dirs' = builtins.sort ( a: b: a < b ) ( lib.unique dirs );
      # Use a `fold' to group dirs in 5s.
      chunk = acc: dir: let
        nl  = {
          i = 0;
          cmd = "${acc.cmd};\n" + ''  ${coreutils}/bin/mkdir -p "${dir}"'';
        };
        cnt = { i = acc.i + 1; cmd = ''${acc.cmd} "${dir}"''; };
      in if 5 <= acc.i then nl else cnt;
      start = { i = 0; cmd = "  ${coreutils}/bin/mkdir -p"; };
    in ( builtins.foldl' chunk start dirs' ).cmd + ";";

    addModDirs = let
      nmp = p: "$node_modules_path/${p}";
    in mkdirs ( map nmp ( builtins.attrNames tree' ) );

    # Run `addCmd' over each module and dump it to the script.
    addMods = let
      addOne = path: ent: addCmd ( getFromdir ent ) ( getTodir path ent );
      cmds = builtins.attrValues ( builtins.mapAttrs addOne tree' );
    in builtins.concatStringsSep "\n  " cmds;

    addBinDirs =
      if haveBin == {} then "" else
      if ignoreSubBins then ["$node_moduels_path/.bin"] else
      map getBindir ( builtins.attrNames haveBin );

    addBins = let
      cmds = builtins.attrValues ( builtins.mapAttrs addBinCmd haveBin );
    in builtins.concatStringsSep "\n  " cmds;

    preHookDef = lib.optionalString ( args ? preNmDir ) ''
      preNmDir() {
        echo "installNodeModules: Running 'preNmDir' hook" >&2;
        ${preNmDir}
      }
      : "''${preNmDirHook=preNmDir}";
    '';
    postHookDef = lib.optionalString ( args ? postNmDir ) ''
      postNmDir() {
        echo "installNodeModules: Running 'postNmDir' hook" >&2;
        ${postNmDir}
      }
      : "''${postNmDirHook=postNmDir}";
    '';
    addBinsDef = lib.optionalString ( haveBin != {} ) ''
      addNodeModulesBins() {
      ${addBinDirs}
        ${addBins}
      }
    '';
  # We must return an attrset for `lib.makeOverridable' to be effective.
  # Since we have an attrset I'm going to tack on some `passthru' and `meta'
  # like you might see on a derivation ( `drvAttrs' ); but none of that
  # is essential ( possibly useful in overrides ).
  in {
    cmd = ''
      ${preHookDef}
      ${postHookDef}
      ${addBinsDef}
      addNodeModules() {
      ${addModDirs}
        ${addMods}
      }
      installNodeModules() {
        # Set `node_modules/' install path if unset.
        # The user can still override this in `preNmDir'.
        : "''${node_modules_path:=$PWD/node_modules}";
        eval "''${preNmDirHook:-:}";
        echo "Installing Node Modules to '$node_modules_path'" >&2;
        addNodeModules;
        ${lib.optionalString ( haveBin != {} ) "addNodeModulesBins;"}
        eval "''${postNmDirHook:-:}";
      }
    '';
    meta = {
      inherit handleBindir ignoreSubBins;
    };
    passthru = {
      inherit tree addCmd addBinCmd preNmDir postNmDir coreutils lndir;
    };
  };

  # Exported form that allows the function result to be overridden; we don't
  # produce a derivation here though so we drop `overrideDerivation' from the
  # resulting attrset.
  # Defining `__functionArgs' is what allows users to run `callPackage' on this
  # function and have it "do what they mean" despite the wrapper.
  mkNmDirCmdWith = {
    __functionArgs = lib.functionArgs _mkNmDirCmdWith;
    __functor = self: args: let
      nmd = lib.callPackageWith globalArgs _mkNmDirCmdWith args;
    in removeAttrs nmd ["overrideDerivation"];
  };


# ---------------------------------------------------------------------------- #

  # Create a `node_modules/' directly using symlinks to store paths.
  # Directories themselves are not linked, only regular files; this helps limit
  # issues cause by Node.js and other tools' efforts to resolve absolute paths
  # during resolution - but it can still cause problems with oddballs like
  # `jest', `tsc', and other tools with bespoke resolution implementations
  # ( because they know SO much better than `Node.js' maintainers... ).
  mkNmDirLinkCmd = {
    tree
  , ignoreSubBins ? false
  , handleBindir  ? true
  , preNmDir      ? ""
  , postNmDir     ? ""
  , coreutils     ? globalArgs.coreutils
  , lndir         ? globalArgs.lndir
  , ...
  } @ args: mkNmDirCmdWith ( { addCmd = _mkNmDirLinkCmd coreutils; } // args );


# ---------------------------------------------------------------------------- #

  # Create a `node_modules/' directly by copying store paths.
  mkNmDirCopyCmd = {
    tree
  , ignoreSubBins ? false
  , handleBindir  ? true
  , preNmDir      ? ""
  , postNmDir     ? ""
  , coreutils     ? globalArgs.coreutils
  , lndir         ? globalArgs.lndir
  , ...
  } @ args: mkNmDirCmdWith ( { addCmd = _mkNmDirCopyCmd coreutils; } // args );


# ---------------------------------------------------------------------------- #

in {
  inherit
    _mkNmDirCopyCmd
    _mkNmDirLinkCmd
    _mkNmDirAddBinWithDirCmd
    _mkNmDirAddBinNoDirsCmd
    _mkNmDirAddBinCmd
    mkNmDirCmdWith
    mkNmDirCopyCmd
    mkNmDirLinkCmd
  ;
}


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
