# macOS Keyboard Toggle for Omarchy

> **macOS-style keyboard layout switcher & status bar indicator for [Omarchy Linux](https://omarchy.org/) (Hyprland).**

[English](#features) | [Русский](#возможности)

---

## Возможности

- **Переключение как в macOS (MRU — Most Recently Used):**
  - **Одиночное нажатие (`Ctrl+Space`):** всегда переключает между **двумя последними** используемыми языками (например, `EN` ⇄ `RU`), сколько бы времени ни прошло между нажатиями.
  - **Быстрое повторное нажатие / удержание (в течение 1 секунды):** запускает циклическое переключение по **всем остальным языкам** системы (`EN` → `RU` → `GR` → `EN`...). Как только вы остановились на нужном языке и начали печатать, он фиксируется в паре с предыдущим.
- **Индикатор в статус-баре (возле часов):**
  - Компактный виджет бара Omarchy (`EN`, `RU`, `EL` и т.д.), размещаемый рядом с часами.
  - При клике на виджет срабатывает переключение языка в стиле macOS.
  - Всплывающая подсказка с полным названием активной раскладки.
- **Всплывающее OSD-уведомление:**
  - При каждом переключении или прокрутке языков на экране появляется нативное OSD-окно Omarchy с названием языка.
- **Полная динамичность (Zero hardcoding):**
  - Не привязан к конкретным языкам. Плагин автоматически считывает любые раскладки, настроенные в вашем `~/.config/hypr/input.lua` (2, 3, 4 и более языков).
  - Затрагивает **только логику переключения**, не перезаписывая ваши настройки раскладок и вариантов.

---

## Features

- **macOS-style MRU (Most Recently Used) switching:**
  - **Single tap (`Ctrl+Space`):** always toggles between the **last two** active layouts (e.g. `EN` ⇄ `RU`), no matter how much time passed.
  - **Rapid press / hold (within 1 second):** cycles through **all remaining layouts** (`EN` → `RU` → `GR` → `EN`...). When you stop and resume typing, the selected layout becomes active and pairs with the previous one.
- **Bar indicator next to the clock:**
  - Clean Omarchy status bar widget displaying the current language code (`EN`, `RU`, `EL`, etc.).
  - Clicking the widget toggles layouts macOS-style.
  - Tooltip with the full layout name.
- **On-Screen Display (OSD):**
  - Native Omarchy OSD popup showing the active language name whenever you switch.
- **Completely dynamic (Zero hardcoding):**
  - Automatically queries Hyprland for whatever layouts are configured in your system. Works with any combination of 2, 3, 4+ languages.

---

## Установка / Installation

### Способ 1: Через менеджер плагинов Omarchy (рекомендуется)

```bash
omarchy plugin add https://github.com/smyrnode/macos-keyboard-toggle --enable
```

Затем запустите установщик для настройки бинарника и горячей клавиши:
```bash
~/.config/omarchy/plugins/macos-keyboard-toggle/install.sh
```

### Способ 2: Вручную через Git

```bash
git clone https://github.com/smyrnode/macos-keyboard-toggle.git ~/.config/omarchy/plugins/macos-keyboard-toggle
cd ~/.config/omarchy/plugins/macos-keyboard-toggle
./install.sh
```

---

## Настройка горячей клавиши / Keybinding

Установщик автоматически добавляет привязку в `~/.config/hypr/bindings.lua`:

```lua
-- macOS-style language toggle: quick tap toggles last 2, hold/repeat cycles all
o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")
```

> **Важно:** Убедитесь, что в вашем `~/.config/hypr/input.lua` отключён переключатель XKB `grp:..._toggle`, чтобы он не конфликтовал со скриптом:
> ```lua
> kb_options = "compose:caps,shift:both_capslock_cancel",
> ```

---

## Структура плагина / Architecture

```
macos-keyboard-toggle/
├── manifest.json              # Манифест плагина Omarchy shell (schemaVersion 1)
├── BarWidget.qml              # Виджет статус-бара Quickshell
├── KeyboardLayoutModel.js     # Форматирование и сопоставление кодов языков (xkbcli)
├── bin/
│   └── omarchy-lang-toggle    # Динамический Python-скрипт переключения и OSD
├── install.sh                 # Скрипт быстрой установки
├── uninstall.sh               # Скрипт удаления
├── README.md
└── LICENSE                    # MIT License
```

---

## Лицензия / License

MIT License © 2026 Dmitry Smyrnov
