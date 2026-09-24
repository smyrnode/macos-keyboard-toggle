# macOS Keyboard Toggle for Omarchy

> **macOS-style keyboard layout switcher & status bar indicator for [Omarchy Linux](https://omarchy.org/) (Hyprland).**

---

## Overview

In standard Linux/Hyprland setups, keyboard layout switching with multiple languages cycles sequentially through every single layout in a fixed circular order (e.g., US → Russian → Greek → US).

This plugin brings the intuitive **macOS input switching behavior** to Omarchy:
- **Quick tap (`Ctrl + Space`):** Always toggles between the **last two used layouts** (e.g., English ⇄ Russian), no matter how much time has passed between typing sessions.
- **Rapid presses (within 1 second):** Cycles through **all remaining system layouts** (e.g., English → Russian → Greek → English...). Once you stop on a layout and begin typing, it is pinned as active and pairs with the previous layout.
- **Right-click the bar label** to open the language manager: add or remove XKB languages and variants, pick the XKB switching shortcut, and turn macOS-style switching on or off (off = plain XKB shortcut cycling).

![Plugin Demo](preview.png)

---

## Features

- **macOS-style MRU (Most Recently Used) Switching:**
  - Single tap toggles the active pair.
  - Repeated presses within a 1-second window cycle through the full list of layouts.
- **Status Bar Indicator (Next to Clock):**
  - Compact Quickshell bar widget displaying the current language code (`EN`, `RU`, `EL`, etc.).
  - Placed directly adjacent to the clock in the center section of the Omarchy bar.
  - Left-clicking the widget triggers the macOS-style layout switch.
  - Tooltip shows the full layout description.
- **macOS-style Switcher HUD with Animated Cursor:**
  - When cycling through 3+ languages (rapid presses), a centered floating card HUD appears displaying square tiles for all configured languages.
  - A highlighted selection cursor smoothly slides between the language tiles as you cycle (`US` → `RU` → `GR`...).
  - Fast single-tap toggling between the last two layouts remains completely silent without showing any popup.
- **Fully Dynamic (Zero Hardcoding):**
  - Automatically queries Hyprland for whatever layouts are configured in your system.
  - Works with any number of languages (2, 3, 4, or more).
  - Only manages switching logic — never alters or overwrites your keyboard layout options or variants.
- **Language Manager Panel (right-click):**
  - Add languages and variants from the installed XKB catalog with searchable pickers.
  - Remove languages safely (Latin-first enforced, confirmation required, rollback on failure).
  - Changes apply live through Hyprland IPC without reloading the session.
- **Switching Modes:**
  - *macOS-style (default):* MRU toggling between the two recent languages; the XKB `grp:` shortcut is kept out of the keymap so nothing double-switches.
  - *XKB:* the chosen `grp:` shortcut cycles all languages sequentially, like stock setups.

---

## Installation

Install and enable the plugin with a single command (or via Omarchy Menu → Plugins):

```bash
omarchy plugin add https://github.com/smyrnode/macos-keyboard-toggle --enable
```

Once enabled, the status bar widget mounts automatically, links the binary to `~/.local/bin/omarchy-lang-toggle`, and registers the `Ctrl + Space` keybinding in Hyprland.

For development, clone the repository into `~/.config/omarchy/plugins/smyrnode.macos-keyboard-toggle` and run `./install.sh`.

---

## Keybinding Configuration

The installer automatically adds the following shortcut to `~/.config/hypr/bindings.lua`:

```lua
-- macOS-style language toggle: quick tap toggles last 2, rapid taps cycle all
o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")
```

> **Note:** While the panel manages languages it applies `kb_layout`/`kb_options` via a generated toggle that overrides `~/.config/hypr/input.lua`. Keep XKB group-toggle options (such as `grp:ctrl_space_toggle`) out of `input.lua` — the panel owns them.

---

## Architecture

```
smyrnode.macos-keyboard-toggle/
├── manifest.json              # Omarchy shell plugin manifest (schemaVersion 1)
├── BarWidget.qml              # Bar widget + right-click management panel
├── SwitcherHud.qml            # Centered macOS switcher HUD with animated cursor
├── KeyboardLayoutModel.js     # Catalog parsing, labels, validation helpers
├── KeyboardSearchableDropdown.qml  # Bounded searchable XKB pickers
├── preview.png                # Plugin card preview / demo screenshot
├── bin/
│   ├── omarchy-lang-toggle    # MRU switching engine with IPC HUD support
│   └── macos-keyboard-layout  # Layout/state manager with safe apply + rollback
├── tests/
│   ├── smoke.sh               # Helper tests against a stubbed hyprctl
│   └── uninstall-smoke.sh     # Uninstall cleanup test
├── install.sh                 # One-step installation script
├── uninstall.sh               # Complete uninstallation script
├── README.md                  # Documentation
└── LICENSE                    # MIT License
```

### State files

Mutable data lives outside the Git checkout:

```
~/.local/state/omarchy/settings/smyrnode-macos-keyboard-toggle.json   # source of truth
~/.local/state/omarchy/toggles/hypr/smyrnode-macos-keyboard-toggle.lua # generated, do not edit
~/.local/state/omarchy-lang-toggle.json                               # MRU switching state
```

The JSON document is the source of truth; the Lua file is generated for
Omarchy's user-toggle loader and applies `kb_layout`/`kb_variant`/`kb_options`
on top of `~/.config/hypr/input.lua`.

---

## Uninstallation

To remove the plugin and restore the default keyboard layout widget:

```bash
~/.config/omarchy/plugins/smyrnode.macos-keyboard-toggle/uninstall.sh
```

This removes the keybinding, the `~/.local/bin/omarchy-lang-toggle` symlink,
all state files and the generated toggle, then reloads Hyprland so
`~/.config/hypr/input.lua` is authoritative again.

---

## License

[MIT License](LICENSE) © 2026 Dmitry Smyrnov
