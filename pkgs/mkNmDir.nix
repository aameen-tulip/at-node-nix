# ============================================================================ #
#
# FIXME:
# This depends on `idealTreeMetaSetPlockV2' to basically fill in `outPath' for
# `pkgSet' keys; but honestly this is as simple as `pkgEnt.prepared.outPath'.
# I haven't merged that routine yet but I'm adding this immediately to share as
# a reference implementation.
#
# ---------------------------------------------------------------------------- #

{
  name  ? "node_modules"
, tree  # result of `idealTreeMetaSetPlockV2 { pkgSet = ...; }'
        # Basically just an attrs of `{ "node_modules/<NAME>" = `pkgEnt'; ... }'
        # You can also just use `path -> outPath' or `path -> drv' attrs.
        # See implementation below for details ( search "pent.prepared" )

# true --> `buildCommand' will be returned instead of derivation ( used to
# build the `node_modules/' directory ).
# This is particularly useful to avoid redundant copies when
# `symlink = false'is being used to add the `node_modules/' directory into a
# builder, or if you are creating a `devShell' which wants to copy the
# `node_modules/'directory to paths outside of the Nix Store.
, emitScript ? false

, symlink  ? true
, cmdArgs  ? if symlink then ["-silent"]
                        else ["-r" "--reflink=auto"]
, lib
, lndir     # nixpkgs.xorg.lndir
, coreutils
, findutils
, gnused
, emptyDirectory
, snapDerivation
, nodejs
, patch-shebangs
}: let
  isEmpty = ( builtins.attrNames tree ) == [];
  # Helper functions needed by `patchShebangs'.
  # Taken from `nixpkgs/pkgs/stdenv/generic/setup.sh'
  cargs = builtins.concatStringsSep " " cmdArgs;

  haveBin = lib.filterAttrs ( _: v: v.meta.hasBin or false ) tree;
  bindirFor = dir: v: let
    dof = dirOf dir;
    nmd = if v.meta.scoped then dirOf dof else dof;
  in lib.libpath.stripComponents 1 "${nmd}/.bin";

  dirnames = let
    mods = let
      do = lib.unique ( map dirOf ( builtins.attrNames tree ) );
      doc = map ( lib.libpath.stripComponents 1 ) do;
      dos = builtins.sort ( a: b: a < b ) doc;
      fs  = map ( lib.libpath.stripComponents 1 )
                ( builtins.attrNames tree );
    in if symlink then fs else dos;
    bins = let
      inherit (builtins) attrNames attrValues mapAttrs;
      bmods = attrNames haveBin;
      nmds  = lib.unique ( attrValues ( mapAttrs bindirFor haveBin ) );
    in nmds;
  in mods ++ bins;

  mkdirs = out: let
    chunk = acc: dir:
      if 5 <= acc.i
      then { i = 0; cmd = acc.cmd + ";\n" + ''mkdir -p "${out}/${dir}"''; }
      else { i = acc.i + 1; cmd = acc.cmd + " " + '' "${out}/${dir}"''; };
    dft = { i = 0; cmd = "\nmkdir -p"; };
  in ( builtins.foldl' chunk dft dirnames ).cmd + ";\n\n";

  addModTo = out: dir: pent: let
    # FIXME
    from = pent.prepared.outPath or pent.outPath or pent;
    to   = "${out}/${lib.libpath.stripComponents 1 dir}";
    mod  = if symlink
          then ''lndir ${cargs} "${from}" "${to}";''
          else ''cp ${cargs} -T "${from}" "${to}";'';
  in mod;

  mods = out: let
    mas = builtins.mapAttrs ( addModTo out ) tree;
  in builtins.concatStringsSep "\n" ( builtins.attrValues mas );

  addBinsTo = out: dir: pent: let
    bd  = bindirFor dir pent;
    sDir = lib.libpath.stripComponents 1 dir;
    inherit (pent.meta) bin;
    froms = if bin ? __DIR__ then ["${sDir}/${bin.__DIR__}"] else
            map ( f: "${sDir}/${f}" ) ( builtins.attrValues bin );
    setPerms = let
      mr = if bin ? __DIR__ then "-R" else "";
      fs = builtins.concatStringsSep " " ( map ( f: "${out}/${f}" ) froms );
    in if symlink then "" else ''
      chmod ${mr} +wrx -- ${fs};
      chmod -R +wr ${dirOf fs};
      if test "''${dontPatchShebangs:-0}" -ne 1; then
        $PATCH_SHEBANGS -- ${fs};
      fi
    '' + "\n";
    linkCmd = let
      link1 = bkey: from: let
        t = if bkey == "__DIR__" then ''-t "${out}/${bd}"'' else
            ''"${out}/${bd}/${bkey}"'';
        f = if bkey == "__DIR__" then ''-f "${out}/${sDir}/${from}/"*'' else
            ''"${out}/${sDir}/${from}"'';
        check = if bkey == "__DIR__" then "" else ''test -r ${t}||'';
      in ''${check}ln -sr ${f} ${t};'';
      cmds = builtins.attrValues ( builtins.mapAttrs link1 bin );
    in builtins.concatStringsSep "\n" cmds;
  in setPerms + linkCmd;

  bins = out: let
    bas = builtins.mapAttrs ( addBinsTo out ) haveBin;
  in builtins.concatStringsSep "\n" ( builtins.attrValues bas );

  PATH = lib.makeBinPath [
    coreutils
    lndir
    findutils
    nodejs
    gnused
    patch-shebangs
  ];

  # A shell script which installs the `node_modules/' directory as a subdir
  # of the environment variable `$node_modules_path'.
  # In the context of a derivation this
  buildCommand = let
    injectOut = body: routine: body + ( routine "$node_modules_path" );
    setFallback = ''
      : "''${node_modules_path:=$PWD/node_modules}";
      export node_modules_path;
      if test "''${PATH_SHEBANGS:+y}" != "y"; then
        if declare -F patchShebangs; then
          : "''${PATCH_SHEBANGS:=patchShebangs}";
        else
          : "''${PATCH_SHEBANGS:=patch-shebangs}";
        fi
      fi
      export PATCH_SHEBANGS;
    '';
    script =
      builtins.foldl' injectOut "\n" [mkdirs mods bins];
  in setFallback + script;

  nmBuilder = snapDerivation {
    inherit name PATH buildCommand;
    # Must be set so that `buildCommand' will install `node_modules/' to
    # "$out" directory.
    node_modules_path = builtins.placeholder "out";
    passAsFile = ["buildCommand"];
  };
  extraAttrs = {
    passthru = { inherit tree patch-shebangs; nmBuildCmd = buildCommand; };
    meta     = { inherit name symlink; };
  };
  drv = ( if isEmpty then emptyDirectory else nmBuilder ) // extraAttrs;
  setPath = ''
    export PATH="''${PATH:+$PATH:}${PATH}";
  '';
in if emitScript then setPath + buildCommand else drv

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
