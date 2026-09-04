#!/usr/bin/env bash
# Installer for macos-keyboard-toggle plugin
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
BINDINGS_FILE="${HOME}/.config/hypr/bindings.lua"

echo "==> Installing macOS Keyboard Toggle for Omarchy..."

# 1. Install toggle binary
mkdir -p "$BIN_DIR"
cp -f "${PLUGIN_DIR}/bin/omarchy-lang-toggle" "${BIN_DIR}/omarchy-lang-toggle"
chmod +x "${BIN_DIR}/omarchy-lang-toggle"
echo "  [x] Installed omarchy-lang-toggle to ${BIN_DIR}/omarchy-lang-toggle"

# 2. Configure Hyprland keybinding in bindings.lua if not already present
if [[ -f "$BINDINGS_FILE" ]]; then
  if ! grep -q "omarchy-lang-toggle" "$BINDINGS_FILE"; then
    echo "" >> "$BINDINGS_FILE"
    echo "-- macOS-style language toggle: quick tap toggles last 2, hold/repeat cycles all" >> "$BINDINGS_FILE"
    echo 'o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")' >> "$BINDINGS_FILE"
    echo "  [x] Added CTRL+SPACE binding to ${BINDINGS_FILE}"
  else
    echo "  [x] CTRL+SPACE binding already present in ${BINDINGS_FILE}"
  fi
fi

# 3. Enable bar widget in Omarchy shell (place next to clock)
echo "  [x] Enabling bar widget next to clock..."
if omarchy plugin list | grep -q "omarchy.keyboard-layout.*enabled"; then
  omarchy plugin disable omarchy.keyboard-layout >/dev/null 2>&1 || true
fi
omarchy plugin enable macos-keyboard-toggle --section center --after omarchy.clock >/dev/null 2>&1 || true

# 4. Reload Hyprland & Omarchy shell
echo "  [x] Reloading Hyprland configuration..."
hyprctl reload >/dev/null 2>&1 || true

echo "==> Installation complete! Press Ctrl+Space to toggle languages."
