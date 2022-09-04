{ writeTextFile, coreutils, findutils, gnused, bash }: writeTextFile {
  name = "patch-shebangs.sh";
  executable = true;
  destination = "/bin/patch-shebangs";
  text = ''
#! ${bash}/bin/bash
# ============================================================================ #
#
# XXX: Expropriated from Nixpkgs. Per COPYING terms:
#
# Original Source: <nixpkgs>/pkgs/build-support/setup-hooks/patch-shebangs.sh
#
# Some unnecessary routines were removed, others slightly modified.
#
# ---------------------------------------------------------------------------- #
#
# Copyright (c) 2003-2022 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# ---------------------------------------------------------------------------- #
#
# This setup hook causes the fixup phase to rewrite all script
# interpreter file names (`#!  /path') to paths found in $PATH.  E.g.,
# /bin/sh will be rewritten to /nix/store/<hash>-some-bash/bin/sh.
# /usr/bin/env gets special treatment so that ".../bin/env python" is
# rewritten to /nix/store/<hash>/bin/python.  Interpreters that are
# already in the store are left untouched.
# A script file must be marked as executable, otherwise it will not be
# considered.

# Run patch shebangs on a directory or file.
# Can take multiple paths as arguments.
# patchShebangs [--build | --host] PATH...

# Flags:
# --build : Lookup commands available at build-time
# --host  : Lookup commands available at runtime

# Example use cases,
# $ patchShebangs --host /nix/store/...-hello-1.0/bin
# $ patchShebangs --build configure


# ---------------------------------------------------------------------------- #

: "''${SED:=${gnused}/bin/sed}"
: "''${TOUCH:=${coreutils}/bin/touch}"
: "''${STAT:=${coreutils}/bin/stat}"
: "''${FIND:=${findutils}/bin/find}"


# ---------------------------------------------------------------------------- #

# Return success if the specified file is a script (i.e. starts with
# "#!").
isScript() {
  local fn="$1"
  local fd
  local magic
  exec {fd}< "$fn"
  read -r -n 2 -u "$fd" magic
  exec {fd}<&-
  if [[ "$magic" =~ \#! ]]; then
    return 0
  else
    return 1
  fi
}


# ---------------------------------------------------------------------------- #

patchShebangs() {
  local pathName

  if [[ "$1" == "--host" ]]; then
    pathName=HOST_PATH
    shift
  elif [[ "$1" == "--build" ]]; then
    pathName=PATH
    shift
  fi

  echo "patching script interpreter paths in $@"
  local f
  local oldPath
  local newPath
  local arg0
  local args
  local oldInterpreterLine
  local newInterpreterLine

  if [[ $# -eq 0 ]]; then
    echo "No arguments supplied to patchShebangs" >&2
    return 0
  fi

  local f
  while IFS= read -r -d $'\0' f; do
    isScript "$f"||continue

    read -r oldInterpreterLine < "$f"
    read -r oldPath arg0 args <<< "''${oldInterpreterLine:2}"

    if [[ -z "$pathName" ]]; then
      if [[ -n $strictDeps && $f == "$NIX_STORE"* ]]; then
        pathName=HOST_PATH
      else
        pathName=PATH
      fi
    fi

    if [[ "$oldPath" == *"/bin/env" ]]; then
      # Check for unsupported 'env' functionality:
      # - options: something starting with a '-'
      # - environment variables: foo=bar
      if [[ $arg0 == "-"* || $arg0 == *"="* ]]; then
        echo "$f: unsupported interpreter directive \"$oldInterpreterLine\" (set dontPatchShebangs=1 and handle shebang patching yourself)" >&2
        exit 1
      fi

      newPath="$( PATH="''${!pathName}" command -v "$arg0"||:; )"
    else
      if [[ -z $oldPath ]]; then
        # If no interpreter is specified linux will use /bin/sh. Set
        # oldpath="/bin/sh" so that we get /nix/store/.../sh.
        oldPath="/bin/sh"
      fi

      newPath="$( PATH="''${!pathName}" command -v "''${oldPath##*/}"||:; )"

      args="$arg0 $args"
    fi

    # Strip trailing whitespace introduced when no arguments are present
    newInterpreterLine="$newPath $args"
    newInterpreterLine=''${newInterpreterLine%''${newInterpreterLine##*[![:space:]]}}

    if [[ -n "$oldPath" && "''${oldPath:0:''${#NIX_STORE}}" != "$NIX_STORE" ]]; then
      if [[ -n "$newPath" && "$newPath" != "$oldPath" ]]; then
        echo "$f: interpreter directive changed from \"$oldInterpreterLine\" to \"$newInterpreterLine\""
        # escape the escape chars so that sed doesn't interpret them
        escapedInterpreterLine=''${newInterpreterLine//\\/\\\\}

        # Preserve times, see: https://github.com/NixOS/nixpkgs/pull/33281
        timestamp=$( $STAT --printf "%y" "$f"; )
        $SED -i -e "1 s|.*|#\!$escapedInterpreterLine|" "$f"
        $TOUCH --date "$timestamp" "$f"
      fi
    fi
  done < <( $FIND "$@" -type f -perm -0100 -print0; )
}

# ---------------------------------------------------------------------------- #

patchShebangs "$@"


# ---------------------------------------------------------------------------- #
#
#
# ============================================================================ #
'';
}

# patchShebangsAuto () {
#   if [[ -z "''${dontPatchShebangs-}" && -e "$prefix" ]]; then
#
#     # Dev output will end up being run on the build platform. An
#     # example case of this is sdl2-config. Otherwise, we can just
#     # use the runtime path (--host).
#     if [[ "$output" != out && "$output" = "$outputDev" ]]; then
#       patchShebangs --build "$prefix"
#     else
#       patchShebangs --host "$prefix"
#     fi
#   fi
# }


# ---------------------------------------------------------------------------- #
