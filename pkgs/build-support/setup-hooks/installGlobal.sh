
preFixupPhases+=" installGlobalNodeModule";

installGlobalNodeModule_setup() {
  if [[ ! -r ./package.json ]]; then
    echo "$PWD: Cannot locate Node Package to be installed" >&2;
    return 1;
  fi

  _prefix="${global:-$out}";
  pdir="$PWD";
  nmdir="$_prefix/lib/node_modules";
  idir="$nmdir/$( $JQ -r ".name" ./package.json; )";
  bindir="$_prefix/bin";
  export _prefix nmdir pdir bindir;

  echo "Installing Node Module Globally to output: $_prefix";
  echo "prefix: $_prefix";
  echo "nmdir:  $nmdir";
  echo "idir:   $idir";
  echo "bindir: $bindir";
}

installGlobalNodeModule_symlink_bins() {
  # Install relative symlinks into parent `$nmdir'.
  _IFS="$IFS";
  IFS=$'\n';
  for bp in $( cd "$idir" >/dev/null; pjsBinPairs "$pdir/package.json"; ); do
    f="${bp##* }";
    t="${bp%% *}";
    if [[ -n "${f%%/*}" ]]; then
      bf="$idir/$f"
    fi
    if [[ -n "${t%%/*}" ]]; then
      bt="$bindir/$t";
    fi
    IFS="$_IFS";
    pjsAddBin "${bf:-$f}" "${bt:-$t}";
  done
}

installGlobalNodeModule_runNmDirCmd() {
  local _old_nmp;

  # Push original value;
  if [[ -n "${node_modules_path+y}" ]]; then
    _old_nmp="$node_modules_path";
  fi

  export node_modules_path="$idir/node_modules";

  if test -n "${nmDirCmdPath:-}"; then
    mkdir -p "$node_modules_path";
    source "$nmDirCmdPath";
  else
    mkdir -p "$node_modules_path";
    eval "${nmDirCmd:-:}";
    if [[ "$?" -ne 0 ]]; then
      echo "Failed to execute nmDirCmd: \"$nmDirCmd\"" >&2;
      exit 1;
    fi
  fi

  # Restore original value;
  if [[ -n "${_old_nmp=+y}" ]]; then
    export node_modules_path="$_old_nmp";
  fi
}

installGlobalNodeModule() {
  installGlobalNodeModule_setup;
  runHook preInstallGlobalNodeModule;
  pjsAddMod . "$idir";
  installGlobalNodeModule_symlink_bins;
  installGlobalNodeModule_runNmDirCmd;
  runHook postInstallGlobalNodeModule;
}
