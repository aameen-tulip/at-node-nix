# ============================================================================ #
#
# Given an NM tree represented as an attrset of `{ <NM-PATH> = PKG; }'
# entries, produce a shell script which builds a `node_modules/' directory.
#
# The `PKG' value can be a `pkgEnt' attrset, or an attset with the fields
# `outPath' and ( if required ) `bin' ( normalized, see example below ), or in
# its simplest form a store path ( string, `outPath' of a prepared module ).
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
# NOTE: See additional documentation in `./README.org'.
#
# ---------------------------------------------------------------------------- #
{ lib
, coreutils
, lndir           # From `nixpkgs.xorg.lndir'
, ...
} @ globalArgs: let

  yt = lib.ytypes // lib.ytypes.Core // lib.ytypes.Prim // lib.ytypes.PkgInfo;

# ---------------------------------------------------------------------------- #

  # This will read an optional argument `copy = true|false' defaulting
  # to symlinks.
  # This is to make it less of a headache in the event you want to override a
  # symlinked command to be copying.
  _mkNmDirCmdWith = {
  # A map of { "node_modules/@foo/bar" = <PKG-ENT>|<STORE-PATH>|<KEY>; }
    tree

  # A function taking `from' and `to' as arguments, which should produce a shell
  # command that "adds" ( copies/links ) module FROM source directory TO
  # module directory.
  # See examples above.
  # NOTE: Use absolute paths to utilities, this command may be nested as a
  # hook in other derivations and you are NOT guaranteed to have `stdenv'
  # default path available - not even `coreutils'.
  # Your function may return a string, or list of strings ( allocation speed )
  # expected to be concatenated with no delimiter between args.
  , addCmd ? ( from: to: ["pjsAddMod \"" from "\" \"" to "\";"] )
  # Same deal as `addCmd' but for handling bin links.
  # This is exposed in case you need to do something wonky like create wrapper
  # scripts; but I think it's unlikely that you'll need to.
  # Ex:  pjsAddBin "./unpacked/bin/quux" "$out/bin/quux"
  # Ex:  pjsAddBin "./unpacked/bin/quux" "$out/bin"
  # Ex:  pjsAddBin "./unpacked" "$out/bin"
  , addBinCmd ? ( from: to: ["installBinsNm \"" from "\" \"" to "\";"] )

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
  , handleBindir ? true  # FIXME: this broke migrating to `pjsUtils'
  , assumeHasBin ? true

  # Hooks
  , preNmDir  ? ""
  , postNmDir ? ""
  # Input Drvs
  , coreutils     ? globalArgs.coreutils
  , lndir         ? globalArgs.lndir
  , flocoPackages ? {}
  , flocoFetch
  , flocoUnpack
  # Floco Env
  , pure
  , ifd
  , allowedPaths
  , ...
  } @ args: let

    fenv = { inherit pure ifd allowedPaths; };

    # FIXME: you did `binPairs' in `haveBin' and you opened up a real can of
    # worms by possibly coercing PJS from tarballs in `lib'.
    # Change it to actually `hasBin' and don't fuck with IFD for now.
    # Do IFD as an optimization later.

    # Accepts an attrset with `{ bin = { "foo" = "./bar/quux.js"; } }' pairs, or
    # a pathlike string, in which case we defer to build time checking.
    # If `assumeHasBin = false' we will not perform build time checks, and the
    # module will not have bins installed ( if it defined any ).
    haveBin = let
      hasBin = _: from: let
        checkPjs = lib.libpkginfo.pjsHasBin' { inherit pure ifd allowedPaths; };
        fpkg     = lib.getFlocoPkg flocoPackages from;
        fmeta    = if fpkg == null then null else lib.getMetaEnt fpkg;
        tryMeta  = builtins.tryEval checkPjs.fmeta;
        yfields  = fmeta.hasBin or fmeta.bin or fmeta.directories.bin or null;
        fromKey  =
          if fmeta == null then assumeHasBin else
          if yfields != null then ! ( builtins.elem yfields [false {}] ) else
          if tryMeta.success then tryMeta.value else assumeHasBin;
      in if from ? bin then ( from.bin or {} ) != {} else
         if yt.PkgInfo.key.check from then fromKey else assumeHasBin;
    in lib.filterAttrs hasBin tree;

    asDollarPath = to: let
      m = builtins.match "($node_modules_path|node_modules)/(.*)" to;
    in if m == null then "$node_modules_path/" + to else
       if ( builtins.substring 0 1 ( builtins.head m ) ) == "$" then to else
       "$node_modules_path/" + ( builtins.elemAt m 1 );

    pnm = lib.yank "(((.*/)?node_modules|$node_modules_path))/(@[^@/]+/)?[^@/]+";

    # Run `addCmd' over each module and dump it to the script.
    # `to' is a "node_modules/@foo/bar/node_modules/baz" path, and
    # `from' is the package entry, a package key, or pathlike.
    addMods = let
      coerceModule = x: let
        pkgFromKey    = lib.getFlocoPkg flocoPackages x;
        pkg = if yt.PkgInfo.Strings.key.check x then pkgFromKey else
              if ( builtins.isString x ) || ( builtins.isPath x ) then null else
              x;
        moduleFromPkg = lib.getFlocoPkgModule flocoPackages pkg;
      in if pkg == null then x else moduleFromPkg;
      addOne = to: from: let
        sub  = asDollarPath ( pnm to );
        line = addCmd ( toString ( coerceModule from ) ) sub;
      in ["  "] ++ line ++ ["\n"];
      cmds = builtins.attrValues ( builtins.mapAttrs addOne tree );
    in builtins.concatLists cmds;


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

    # Run `addBinCmd' over each module and dump it to the script.
    # `to' is a "node_modules/@foo/bar/node_modules/baz" path, and
    # `from' is the package entry, a package key, or pathlike.
    addBins = let
      addOne = to: from: let
        sub = asDollarPath ( pnm to );
      in ["  "] ++ ( addBinCmd ( asDollarPath to ) sub ) ++ ["\n"];
      # TODO: fill script names when `binPairs' is available.
      cmds = builtins.attrValues ( builtins.mapAttrs addOne haveBin );
    in builtins.concatLists cmds;

    addBinsDef = let
      asFn = ["\naddNodeModulesBins() {\n  "] ++ addBins ++ ["\n}\n"];
    in lib.optionalString ( haveBin != {} )
                          ( builtins.concatStringsSep "" asFn );

  # We must return an attrset for `lib.makeOverridable' to be effective.
  # Since we have an attrset I'm going to tack on some `passthru' and `meta'
  # like you might see on a derivation ( `drvAttrs' ); but none of that
  # is essential ( possibly useful in overrides ).
  in {
    cmd = ''
      . ${builtins.path {
        path      = ../build-support/setup-hooks/pjs-util.sh;
        recursive = false;
      }}
      ${preHookDef}
      ${postHookDef}
      ${addBinsDef}

      addNodeModules() {
      ${builtins.concatStringsSep "" addMods}
      }

      installNodeModules() {
        local pdir;
        # Set `node_modules/' install path if unset.
        # The user can still override this in `preNmDir'.
        if test "$#" -gt 0; then
          node_modules_path="$1";
          shift;
        fi
        if test -z "''${node_modules_path:-}"; then
          if test -r ./package.json; then
            pdir="$PWD";
          elif test -n "''${sourceRoot+y}" &&                 \
              test -r "$PWD/$sourceRoot/package.json"; then
            pdir="$PWD/$sourceRoot";
          else
            printf '%s'                                                       \
              "Could not locate a package.json, and no 'node_modules_path' "  \
              "var was set.\nFalling back to installation in PWD." >&2;
            pdir="$PWD";
          fi
          node_modules_path="$pdir/node_modules";
          unset pdir;
        fi
        eval "''${preNmDirHook:-:}";
        echo "Installing Node Modules to '$node_modules_path'" >&2;
        addNodeModules;
        ${lib.optionalString ( haveBin != {} ) "addNodeModulesBins;"}
        eval "''${postNmDirHook:-:}";
      }
    '';
    passthru = {
      inherit handleBindir ignoreSubBins;
      inherit addCmd addBinCmd preNmDir postNmDir coreutils lndir;
      # Original input tree.
      fullTree = tree;
    };
  };

  # Defining `__functionArgs' is what allows users to run `callPackage' on this
  # function and have it "do what they mean" despite the wrapper.
  mkNmDirCmdWith = {
    __functionArgs = lib.functionArgs _mkNmDirCmdWith;
    __functor = self: args: let
      nmd = lib.callPackageWith globalArgs _mkNmDirCmdWith args;
    in nmd;
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
  , assumeHasBin  ? false
  , handleBindir  ? true
  , preNmDir      ? ""
  , postNmDir     ? ""
  , coreutils     ? globalArgs.coreutils
  , lndir         ? globalArgs.lndir
  , ...
  } @ args: mkNmDirCmdWith ( {
    inherit ignoreSubBins assumeHasBin handleBindir postNmDir;
    inherit coreutils lndir;
    preNmDir = ''
      ADD_MOD=pjsAddModLink;
      ${args.preNmDir or ""}
    '';
  } // args );


# ---------------------------------------------------------------------------- #

  # Create a `node_modules/' directly by copying store paths.
  mkNmDirCopyCmd = {
    tree
  , ignoreSubBins ? false
  , assumeHasBin  ? false
  , handleBindir  ? true
  , preNmDir      ? ""
  , postNmDir     ? ""
  , coreutils     ? globalArgs.coreutils
  , lndir         ? globalArgs.lndir
  , ...
  } @ args: mkNmDirCmdWith ( {
    inherit ignoreSubBins assumeHasBin handleBindir postNmDir;
    inherit coreutils lndir;
    preNmDir = ''
      ADD_MOD=pjsAddModCopy;
      ${args.preNmDir or ""}
    '';
  } // args );


# ---------------------------------------------------------------------------- #

in {
  inherit
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
