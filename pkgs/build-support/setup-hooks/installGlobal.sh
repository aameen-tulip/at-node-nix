
postInstallPhases+=" installModuleGlobalNodeModule"

installGlobalNodeModule() {
  local _prefix;
  if [[ ! -r ./package.json ]]; then
    echo "$PWD: Cannot locate Node Package to be installed" >&2;
    return 1;
  fi
  _prefix="${global:-$out}";
  echo "Installing Node Module Globally to output: $_prefix";
  bindir="$_prefix/bin" installModuleGlobal "$PWD" "$_prefix";
  # FIXME: install deps
}