#!/usr/bin/env bash
# Sandboxed uninstall test: plant every file the plugin creates, run
# uninstall.sh against a fake HOME with stub omarchy/hyprctl, assert cleanup.
set -euo pipefail

cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export STUB_LOG="$WORK/stub.log"
mkdir -p "$HOME/.config/hypr" "$HOME/.local/bin" \
         "$HOME/.local/state/omarchy/settings" \
         "$HOME/.local/state/omarchy/toggles/hypr" \
         "$HOME/.cache" "$WORK/bin"

# Plant user config: our lines plus a foreign binding that must survive.
printf '%s\n' \
  '-- keep me' \
  '' \
  '-- macOS-style language toggle' \
  'o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")' \
  'o.bind("SUPER + E", "Editor", "nvim")' >"$HOME/.config/hypr/bindings.lua"

ln -sf /bin/true "$HOME/.local/bin/omarchy-lang-toggle"
touch "$HOME/.local/state/omarchy-lang-toggle.json" \
      "$HOME/.local/state/omarchy-lang-toggle.json.lock" \
      "$HOME/.local/state/omarchy-lang-toggle.json.tmp" \
      "$HOME/.cache/omarchy-lang-toggle.json" \
      "$HOME/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.json" \
      "$HOME/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.lock" \
      "$HOME/.local/state/omarchy/toggles/hypr/smyrnode-macos-keyboard-toggle.lua" \
      "$HOME/.local/state/omarchy/settings/.smyrnode-kb-state.ABC123" \
      "$HOME/.local/state/omarchy/toggles/hypr/.smyrnode-kb-toggle.XYZ789"

for stub in omarchy hyprctl; do
  cat >"$WORK/bin/$stub" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\$STUB_LOG"
exit 0
EOF
  chmod +x "$WORK/bin/$stub"
done
export PATH="$WORK/bin:$PATH"

./uninstall.sh >/dev/null

fail=0
check() {
  local name=$1
  shift
  if "$@"; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    fail=1
  fi
}

gone() { [[ ! -e $1 && ! -L $1 ]]; }

check "symlink removed" gone "$HOME/.local/bin/omarchy-lang-toggle"
check "settings removed" gone "$HOME/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.json"
check "settings lock removed" gone "$HOME/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.lock"
check "generated toggle removed" gone "$HOME/.local/state/omarchy/toggles/hypr/smyrnode-macos-keyboard-toggle.lua"
check "mru state removed" gone "$HOME/.local/state/omarchy-lang-toggle.json"
check "mru lock removed" gone "$HOME/.local/state/omarchy-lang-toggle.json.lock"
check "mru tmp removed" gone "$HOME/.local/state/omarchy-lang-toggle.json.tmp"
check "legacy cache removed" gone "$HOME/.cache/omarchy-lang-toggle.json"
check "helper temp litter removed" \
  bash -c '! compgen -G "$HOME/.local/state/omarchy/settings/.smyrnode-kb-*" >/dev/null && ! compgen -G "$HOME/.local/state/omarchy/toggles/hypr/.smyrnode-kb-*" >/dev/null'
check "binding removed" bash -c '! grep -q "omarchy-lang-toggle" "$HOME/.config/hypr/bindings.lua"'
check "foreign bindings kept" grep -q "SUPER + E" "$HOME/.config/hypr/bindings.lua"
check "plugin disabled" grep -q "plugin disable smyrnode.macos-keyboard-toggle" "$STUB_LOG"
check "stock widget restored" grep -q "plugin enable omarchy.keyboard-layout" "$STUB_LOG"
check "hyprland reloaded" grep -q "^reload$" "$STUB_LOG"

if [[ $fail -eq 0 ]]; then
  echo "ALL TESTS PASSED"
else
  exit 1
fi
