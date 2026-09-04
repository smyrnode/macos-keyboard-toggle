# macOS Keyboard Toggle for Omarchy

> **macOS-style keyboard layout switcher & status bar indicator for [Omarchy Linux](https://omarchy.org/) (Hyprland).**

---

## Overview

In standard Linux/Hyprland setups, keyboard layout switching with multiple languages cycles sequentially through every single layout in a fixed circular order (e.g., US → Russian → Greek → US).

This plugin brings the intuitive **macOS input switching behavior** to Omarchy:
- **Quick tap (`Ctrl + Space`):** Always toggles between the **last two used layouts** (e.g., English ⇄ Russian), no matter how much time has passed between typing sessions.
- **Rapid press / hold (within 1 second):** Cycles through **all remaining system layouts** (e.g., English → Russian → Greek → English...). Once you stop on a layout and begin typing, it is pinned as active and pairs with the previous layout.

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
- **On-Screen Display (OSD):**
  - Native Omarchy OSD popup displaying the active language name whenever the layout changes.
- **Fully Dynamic (Zero Hardcoding):**
  - Automatically queries Hyprland for whatever layouts are configured in your system.
  - Works with any number of languages (2, 3, 4, or more).
  - Only manages switching logic — never alters or overwrites your keyboard layout options or variants.

---

## Installation

### Method 1: Via Omarchy Shell (Recommended)

Install and enable the plugin in one command (or via Omarchy Menu → Plugins):

```bash
omarchy plugin add https://github.com/smyrnode/macos-keyboard-toggle --enable
```

**That's it!** Once enabled, the status bar widget mounts automatically, links the binary to `~/.local/bin/omarchy-lang-toggle`, and registers the `Ctrl + Space` keybinding in Hyprland.

---

### Method 2: Manual Installation via Git

If you prefer to install manually:

```bash
git clone https://github.com/smyrnode/macos-keyboard-toggle.git ~/.config/omarchy/plugins/macos-keyboard-toggle
cd ~/.config/omarchy/plugins/macos-keyboard-toggle
./install.sh
```

---

## Keybinding Configuration

The installer automatically adds the following shortcut to `~/.config/hypr/bindings.lua`:

```lua
-- macOS-style language toggle: quick tap toggles last 2, hold/repeat cycles all
o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")
```

> **Important:** Ensure that any XKB group toggle option (such as `grp:ctrl_space_toggle` or `grp:alt_shift_toggle`) is removed from `kb_options` in `~/.config/hypr/input.lua` to prevent conflicts:
> ```lua
> kb_options = "compose:caps,shift:both_capslock_cancel",
> ```

---

## Architecture

```
macos-keyboard-toggle/
├── manifest.json              # Omarchy shell plugin manifest (schemaVersion 1)
├── BarWidget.qml              # Quickshell status bar widget
├── KeyboardLayoutModel.js     # Language code formatting and xkbcli brief mapping
├── bin/
│   └── omarchy-lang-toggle    # Dynamic Python switcher script with OSD support
├── install.sh                 # One-step installation script
├── uninstall.sh               # Complete uninstallation script
├── README.md                  # Documentation
└── LICENSE                    # MIT License
```

---

## Uninstallation

To remove the plugin and restore the default keyboard layout widget:

```bash
~/.config/omarchy/plugins/macos-keyboard-toggle/uninstall.sh
```

---

## License

[MIT License](LICENSE) © 2026 Dmitry Smyrnov
