#!/usr/bin/env bash
# Uninstaller for smyrnode.macos-keyboard-toggle plugin
set -euo pipefail

BINDINGS_FILE="${HOME}/.config/hypr/bindings.lua"
SETTINGS_FILE="${HOME}/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.json"
LOCK_FILE="${HOME}/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.lock"
TOGGLE_FILE="${HOME}/.local/state/omarchy/toggles/hypr/smyrnode-macos-keyboard-toggle.lua"

echo "==> Uninstalling macOS Keyboard Toggle..."

# 1. Disable bar widget and restore default
omarchy plugin disable smyrnode.macos-keyboard-toggle >/dev/null 2>&1 || true
omarchy plugin enable omarchy.keyboard-layout --section center --after omarchy.clock >/dev/null 2>&1 || true

# 2. Remove keybinding from bindings.lua
if [[ -f "$BINDINGS_FILE" ]]; then
  sed -i '/omarchy-lang-toggle/d' "$BINDINGS_FILE"
  sed -i '/macOS-style language toggle/d' "$BINDINGS_FILE"
fi

# 3. Remove symlink, generated configs, and state
rm -f "${HOME}/.local/bin/omarchy-lang-toggle"
rm -f "$SETTINGS_FILE" "$LOCK_FILE" "$TOGGLE_FILE"
rm -f "${HOME}/.local/state/omarchy-lang-toggle.json" \
      "${HOME}/.local/state/omarchy-lang-toggle.json.lock" \
      "${HOME}/.local/state/omarchy-lang-toggle.json.tmp" \
      "${HOME}/.cache/omarchy-lang-toggle.json"
# Leftover temp files from an interrupted helper run
rm -f "${HOME}/.local/state/omarchy/settings"/.smyrnode-kb-* \
      "${HOME}/.local/state/omarchy/toggles/hypr"/.smyrnode-kb-*

# 4. Reload so the removed toggle no longer overrides ~/.config/hypr/input.lua
hyprctl reload >/dev/null 2>&1 || true

echo "==> Uninstalled successfully."
