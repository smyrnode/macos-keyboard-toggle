#!/usr/bin/env bash
# Uninstaller for macos-keyboard-toggle plugin
set -euo pipefail

BINDINGS_FILE="${HOME}/.config/hypr/bindings.lua"

echo "==> Uninstalling macOS Keyboard Toggle..."

# 1. Disable bar widget and restore default
omarchy plugin disable macos-keyboard-toggle >/dev/null 2>&1 || true
omarchy plugin enable omarchy.keyboard-layout --section center --after omarchy.clock >/dev/null 2>&1 || true

# 2. Remove keybinding from bindings.lua
if [[ -f "$BINDINGS_FILE" ]]; then
  sed -i '/omarchy-lang-toggle/d' "$BINDINGS_FILE"
  sed -i '/macOS-style language toggle/d' "$BINDINGS_FILE"
fi

# 3. Reload
hyprctl reload >/dev/null 2>&1 || true

echo "==> Uninstalled successfully."
