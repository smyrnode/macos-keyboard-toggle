import "KeyboardLayoutModel.js" as Model
import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// macOS-style keyboard layout indicator with a management panel.
// Left-click switches (MRU engine), right-click opens the panel.
Panel {
  id: root

  moduleName: "smyrnode.macos-keyboard-toggle"
  manageIpc: false

  // --- widget state --------------------------------------------------------

  property string layoutFull: ""
  property string keyboardName: ""
  property string typedKeyboardName: ""
  property int keyboardCount: 0
  property bool keyboardUnresolved: false
  property int activeLayoutIndex: 0
  property bool refreshPending: false

  // --- panel state ---------------------------------------------------------

  property bool stateReady: false
  property var managedState: ({
    "version": 1,
    "switchMode": "mru",
    "layouts": [{
      "layout": "us",
      "variant": "",
      "latin": true
    }],
    "switchOption": "grp:ctrl_space_toggle",
    "nonGroupOptions": []
  })
  property var catalog: ({
    "layouts": [],
    "shortcuts": []
  })
  property string view: "main"
  property string selectedLayout: ""
  property string selectedVariant: ""
  property string selectedShortcut: ""
  property int pendingDeleteIndex: -1
  property int editingAliasIndex: -1
  property string selectedAlias: ""
  property string pendingHotkey: ""
  property string statusText: ""
  property bool statusError: false
  property int cursorIndex: 0
  property int phraseIndex: 0

  readonly property var configuredLayouts: {
    var value = Model.normalizeLayouts(managedState.layouts)
    return value.length > 0 ? value : [{
      "layout": "us",
      "variant": "",
      "latin": true
    }]
  }
  readonly property string switchMode: String(managedState.switchMode || "mru")
  readonly property string switchOption: String(managedState.switchOption || "grp:ctrl_space_toggle")
  readonly property string mruHotkey: String(managedState.hotkey || "CTRL + SPACE")
  readonly property var editingAliasLayout: editingAliasIndex >= 0 && editingAliasIndex < configuredLayouts.length ? configuredLayouts[editingAliasIndex] : null
  readonly property string automaticAlias: editingAliasLayout ? Model.labelFor(catalog, editingAliasLayout.layout, editingAliasLayout.variant, "") : ""
  readonly property string aliasPreview: editingAliasLayout ? Model.labelFor(catalog, editingAliasLayout.layout, editingAliasLayout.variant, selectedAlias) : ""
  readonly property string aliasValidationError: Model.aliasError(selectedAlias)
  readonly property string conflictOption: {
    if (switchMode !== "mru") return ""
    var live = String(managedState.groupOption || "")
    return live !== "" ? live : ""
  }
  readonly property string layoutLabel: {
    var item = configuredLayouts[Math.max(0, Math.min(activeLayoutIndex, configuredLayouts.length - 1))]
    return item ? Model.labelFor(catalog, item.layout, item.variant, item.alias) : "KB"
  }
  readonly property string activeDescription: {
    var item = configuredLayouts[Math.max(0, Math.min(activeLayoutIndex, configuredLayouts.length - 1))]
    return item ? Model.descriptionFor(catalog, item.layout, item.variant) : layoutFull
  }
  readonly property string helperCommand: {
    var resolved = String(Qt.resolvedUrl("bin/macos-keyboard-layout"))
    return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
  }
  readonly property int pickerControlHeight: Math.max(Style.spacing.controlHeight, Style.font.body + Style.spacing.inputPaddingY * 2 + Style.space(6))
  readonly property int pickerPopupRowHeight: Math.max(Style.spacing.popupRowHeight, pickerControlHeight + Style.space(4))
  readonly property var heroPhrases: Model.heroPhrases()
  readonly property string heroPhrase: heroPhrases.length > 0 ? heroPhrases[phraseIndex % heroPhrases.length] : ""

  function shortcutLabel(value) {
    var found = catalog.shortcuts.find(function(item) {
      return item.value === value
    })
    return found ? found.label : value
  }

  function typedKeyboards(keyboards) {
    return keyboards.filter(k => Model.isTypedKeyboard(k.name))
  }

  function selectKeyboard(typed) {
    return Model.selectKeyboard(typed, root.typedKeyboardName)
  }

  function toggleLayout() {
    if (!root.bar) return
    if (root.switchMode === "mru") {
      var scriptPath = String(Qt.resolvedUrl("bin/omarchy-lang-toggle")).replace(/^file:\/\//, "")
      root.bar.run(scriptPath)
    } else {
      // XKB mode: sequential cycle, like the stock widget.
      root.switchLayout((activeLayoutIndex + 1) % Math.max(1, configuredLayouts.length))
    }
    refreshTimer.restart()
  }

  function stepLayout(step) {
    if (!root.bar) return
    var count = Math.max(1, configuredLayouts.length)
    if (count < 2) return
    var next = (activeLayoutIndex + step + count) % count
    activeLayoutIndex = next
    root.bar.run(Util.shellQuote(root.helperCommand) + " set " + next)
    refreshTimer.restart()
  }

  function cycleByWheel(delta) {
    if (delta === 0) return
    stepLayout(delta > 0 ? -1 : 1)
  }

  function refresh() {
    if (queryProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    queryProc.running = true
  }

  function refreshState() {
    if (!stateProc.running && !applyProc.running) stateProc.running = true
  }

  function acceptState(text) {
    var parsed
    try {
      parsed = JSON.parse(String(text || "").trim())
    } catch (error) {
      return false
    }
    if (!parsed || Model.normalizeLayouts(parsed.layouts).length === 0) return false
    managedState = parsed
    stateReady = true
    return true
  }

  function openMain() {
    view = "main"
    resetAddEditor()
    resetAliasEditor()
    pendingHotkey = ""
    selectedShortcut = switchOption
    statusText = ""
    cursorIndex = Math.max(0, Math.min(cursorIndex, configuredLayouts.length + 1))
  }

  function startShortcut() {
    view = "shortcut"
    selectedShortcut = switchOption
    shortcutPicker.resetSearch()
    shortcutPicker.setCurrentValue(selectedShortcut)
    statusText = ""
  }

  function startAdd() {
    view = "add"
    resetAddEditor()
    statusText = ""
  }

  function startAlias(index) {
    if (!stateReady || index < 0 || index >= configuredLayouts.length) return
    editingAliasIndex = index
    selectedAlias = String(configuredLayouts[index].alias || "")
    aliasField.text = selectedAlias
    view = "alias"
    statusText = ""
    Qt.callLater(function() {
      aliasField.forceActiveFocus()
      aliasField.selectAll()
    })
  }

  function resetAliasEditor() {
    editingAliasIndex = -1
    selectedAlias = ""
    aliasField.text = ""
  }

  function startHotkey() {
    view = "hotkey"
    pendingHotkey = ""
    statusText = ""
    Qt.callLater(function() {
      hotkeyCatcher.forceActiveFocus()
    })
  }

  function saveAlias() {
    if (!editingAliasLayout) return
    if (aliasValidationError !== "") {
      statusError = true
      statusText = aliasValidationError
      return
    }
    runAction(["alias", String(editingAliasIndex), Model.normalizeAlias(selectedAlias)], "Bar alias updated.")
  }

  function useAutomaticAlias() {
    runAction(["alias", String(editingAliasIndex), ""], "Bar alias cleared.")
  }

  function saveHotkey() {
    if (Model.hotkeyError(pendingHotkey) !== "") return
    runAction(["hotkey", Model.normalizeHotkey(pendingHotkey)], "Hotkey updated. New combo: " + Model.normalizeHotkey(pendingHotkey))
  }

  function hotkeyKeyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1)
    switch (key) {
      case Qt.Key_Space: return "SPACE"
      case Qt.Key_Comma: return "COMMA"
      case Qt.Key_Period: return "PERIOD"
      case Qt.Key_Slash: return "SLASH"
      case Qt.Key_Backslash: return "BACKSLASH"
      case Qt.Key_Semicolon: return "SEMICOLON"
      case Qt.Key_Apostrophe: return "APOSTROPHE"
      case Qt.Key_Minus: return "MINUS"
      case Qt.Key_Equal: return "EQUAL"
      case Qt.Key_BracketLeft: return "BRACKETLEFT"
      case Qt.Key_BracketRight: return "BRACKETRIGHT"
      case Qt.Key_Tab: return "TAB"
      case Qt.Key_Return: return "RETURN"
      case Qt.Key_Backspace: return "BACKSPACE"
      case Qt.Key_Delete: return "DELETE"
      case Qt.Key_Home: return "HOME"
      case Qt.Key_End: return "END"
      case Qt.Key_PageUp: return "PAGEUP"
      case Qt.Key_PageDown: return "PAGEDOWN"
      case Qt.Key_Up: return "UP"
      case Qt.Key_Down: return "DOWN"
      case Qt.Key_Left: return "LEFT"
      case Qt.Key_Right: return "RIGHT"
      default: return ""
    }
  }

  function hotkeyFromKeyEvent(event) {
    var mods = []
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    var key = hotkeyKeyName(event.key)
    if (key === "") return ""
    return mods.concat([key]).join(" + ")
  }

  function resetAddEditor() {
    languagePicker.resetSearch()
    variantPicker.resetSearch()
    selectedLayout = ""
    selectedVariant = ""
  }

  function runAction(actionArguments, message, loadingMessage) {
    if (applyProc.running) return
    if (stateProc.running || !stateReady) {
      statusError = true
      statusText = "Keyboard settings are still loading. Try again in a moment."
      return
    }
    statusError = false
    statusText = loadingMessage || "Applying keyboard settings…"
    applyProc.successMessage = message
    applyProc.command = [root.helperCommand].concat(actionArguments)
    applyProc.pending = true
    applyTimeout.restart()
    applyProc.running = true
  }

  function switchLayout(index) {
    if (!stateReady || index < 0 || index >= configuredLayouts.length) return
    runAction(["set", String(index)], "Keyboard language switched.")
  }

  function moveLanguage(index, step) {
    if (!stateReady) return
    var verdict = Model.canMove(configuredLayouts, index, step)
    if (!verdict.ok) {
      statusError = true
      statusText = verdict.reason
      return
    }
    runAction(["move", String(index), step < 0 ? "up" : "down"], "Language order updated.")
  }

  function requestDelete(index) {
    var verdict = Model.canDelete(configuredLayouts, index)
    if (!verdict.ok) {
      statusError = true
      statusText = verdict.reason
      return
    }
    pendingDeleteIndex = index
    deleteDialog.opened = true
  }

  function deletePending() {
    var index = pendingDeleteIndex
    deleteDialog.opened = false
    pendingDeleteIndex = -1
    runAction(["remove", String(index)], "Keyboard language removed.")
  }

  function addSelected() {
    if (!selectedLayout) {
      statusError = true
      statusText = "Choose a keyboard language first."
      return
    }
    if (Model.duplicate(configuredLayouts, selectedLayout, selectedVariant)) {
      statusError = true
      statusText = "That language and variant is already available."
      return
    }
    runAction(["add", selectedLayout, selectedVariant], "Keyboard language added.", "Checking keyboard compatibility…")
  }

  function saveShortcut() {
    if (!selectedShortcut) {
      statusError = true
      statusText = "Choose a supported switching shortcut."
      return
    }
    runAction(["shortcut", selectedShortcut], "Switching shortcut updated.")
  }

  function toggleSwitchMode() {
    runAction(["mode", switchMode === "mru" ? "xkb" : "mru"], switchMode === "mru" ? "XKB switching enabled." : "macOS-style switching enabled.")
  }

  function activateCursor() {
    if (view !== "main") return
    if (cursorIndex < configuredLayouts.length) switchLayout(cursorIndex)
    else if (cursorIndex === configuredLayouts.length) startShortcut()
    else startAdd()
  }

  function moveCursor(dy) {
    if (view !== "main" || dy === 0) return
    cursorIndex = Math.max(0, Math.min(configuredLayouts.length + 1, cursorIndex + dy))
  }

  Component.onCompleted: {
    setupProc.running = true
    catalogProc.running = true
    refreshState()
    refresh()
  }

  onOpenedChanged: {
    if (opened) {
      openMain()
      refreshState()
      refresh()
    } else {
      resetAddEditor()
      resetAliasEditor()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activelayout") {
        const named = Model.eventKeyboardName(event)
        if (named) root.typedKeyboardName = named
      }
      if (name.indexOf("activelayout") !== -1 || name === "configreloaded") root.refresh()
    }
  }

  // First-run setup: link the toggle script and register the hotkey once.
  Process {
    id: setupProc
    command: [
      "sh", "-c",
      "mkdir -p ~/.local/bin && " +
      "SCRIPT=" + String(Qt.resolvedUrl("bin/omarchy-lang-toggle")).replace(/^file:\/\//, "") + " && " +
      "NEW_SETUP=1 && " +
      "{ [ -e ~/.local/bin/omarchy-lang-toggle ] || [ -L ~/.local/bin/omarchy-lang-toggle ]; } && NEW_SETUP=; " +
      "grep -q 'omarchy-lang-toggle' ~/.config/hypr/bindings.lua 2>/dev/null && NEW_SETUP=; " +
      "ln -sf \"$SCRIPT\" ~/.local/bin/omarchy-lang-toggle && " +
      "if [ -n \"$NEW_SETUP\" ] && [ -f ~/.config/hypr/bindings.lua ]; then " +
      "printf '\\n-- macOS-style language toggle\\no.bind(\"CTRL + SPACE\", \"Toggle language (macOS-style)\", \"~/.local/bin/omarchy-lang-toggle\")\\n' >> ~/.config/hypr/bindings.lua && " +
      "hyprctl reload; fi"
    ]
  }

  Process {
    id: queryProc
    command: ["hyprctl", "-j", "devices"]
    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }
      stallTimer.stop()
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let listed
        try {
          listed = JSON.parse(text || "{}").keyboards
        } catch (e) {
          return
        }
        if (!Array.isArray(listed)) return

        const typed = root.typedKeyboards(listed)
        const kb = root.selectKeyboard(typed)
        if (!kb || !kb.active_keymap) {
          root.keyboardUnresolved = true
          if (typed.length === 0) {
            root.layoutFull = ""
            root.keyboardName = ""
          }
          return
        }

        root.keyboardUnresolved = false
        root.keyboardCount = typed.length
        root.keyboardName = String(kb.name || "")
        root.layoutFull = kb.active_keymap
        root.activeLayoutIndex = Number(kb.active_layout_index || 0)
      }
    }
  }

  Process {
    id: catalogProc
    command: [root.helperCommand, "available"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.catalog = Model.parseCatalog(text)
    }
  }

  Process {
    id: stateProc
    command: [root.helperCommand, "status"]
    onExited: function(exitCode) {
      if (exitCode === 0 && root.acceptState(stateStdout.text)) {
        if (root.statusText.indexOf("Loading") === 0) root.statusText = ""
      } else if (root.opened) {
        root.statusError = true
        root.statusText = String(stateStderr.text || "Keyboard settings could not be loaded. Close and reopen this panel to retry.").trim()
      }
    }
    stdout: StdioCollector {
      id: stateStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: stateStderr
      waitForEnd: true
    }
  }

  Process {
    id: applyProc
    property string successMessage: ""
    property bool pending: false
    onExited: function(exitCode) {
      if (!pending) return
      pending = false
      applyTimeout.stop()
      if (exitCode === 0 && root.acceptState(applyStdout.text)) {
        root.openMain()
        root.statusError = false
        root.statusText = successMessage
        refreshTimer.restart()
      } else {
        root.statusError = true
        root.statusText = String(applyStderr.text || "Keyboard settings could not be applied. Your previous settings are still active.").trim()
      }
    }
    stdout: StdioCollector {
      id: applyStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: applyStderr
      waitForEnd: true
    }
  }

  Timer {
    id: applyTimeout
    interval: 10000
    onTriggered: {
      if (!applyProc.running) return
      applyProc.pending = false
      applyProc.running = false
      root.statusError = true
      root.statusText = "Keyboard helper did not respond. Restart the Omarchy shell and try again."
    }
  }

  Loader {
    id: hudLoader
    source: Qt.resolvedUrl("SwitcherHud.qml")
  }

  IpcHandler {
    target: "smyrnode.macos-keyboard-toggle"
    function ping(): string {
      return "pong"
    }
    function showHud(payloadJson: string): string {
      if (hudLoader.item) {
        hudLoader.item.show(payloadJson)
        return "ok"
      }
      return "not-ready"
    }
    function openPanel(): string {
      root.open()
      return "ok"
    }
    function closePanel(): string {
      root.close()
      return "ok"
    }
    function togglePanel(): string {
      root.toggle()
      return "ok"
    }
    function cycleNext(): string {
      root.stepLayout(1)
      return "ok"
    }
    function cyclePrev(): string {
      root.stepLayout(-1)
      return "ok"
    }
  }

  IpcHandler {
    target: "smyrnode.macos-keyboard-toggle.demo"
    function showMain(): void {
      root.open()
      Qt.callLater(root.openMain)
    }
    function showAdd(): void {
      root.open()
      Qt.callLater(root.startAdd)
    }
    function showShortcut(): void {
      root.open()
      Qt.callLater(root.startShortcut)
    }
    function showHotkey(): void {
      root.open()
      Qt.callLater(root.startHotkey)
    }
    function showAlias(): void {
      root.open()
      Qt.callLater(function() {
        root.startAlias(0)
        aliasField.text = "Work"
        root.selectedAlias = "Work"
      })
    }
  }

  Timer {
    id: refreshTimer
    interval: 300
    onTriggered: root.refresh()
  }

  Timer {
    id: stallTimer
    interval: 5000
    onTriggered: {
      queryProc.running = false
      refreshTimer.restart()
    }
  }

  Timer {
    interval: 10000
    running: !root.keyboardName || root.keyboardUnresolved || root.keyboardCount > 1
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.view === "main" && root.heroPhrases.length > 0
    repeat: true
    triggeredOnStart: false
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.heroPhrases.length
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.activeDescription + "\nLeft-click: switch language\nScroll: cycle languages\nRight-click: manage languages"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) root.toggle()
      else root.toggleLayout()
    }
    onWheelMoved: function(delta) {
      root.cycleByWheel(delta)
    }
  }

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      blocked: languagePicker.popupOpen || variantPicker.popupOpen || shortcutPicker.popupOpen || aliasField.activeFocus || root.view === "hotkey"
      onMoveRequested: function(dx, dy) {
        if (deleteDialog.opened) {
          if (dx !== 0 || dy !== 0) deleteDialog.selectedIndex = deleteDialog.selectedIndex === 0 ? 1 : 0
        } else {
          root.moveCursor(dy)
        }
      }
      onActivateRequested: {
        if (deleteDialog.opened) {
          if (deleteDialog.selectedIndex === 0) deleteDialog.canceled()
          else deleteDialog.confirmed()
        } else {
          root.activateCursor()
        }
      }
      onCloseRequested: {
        if (deleteDialog.opened) deleteDialog.canceled()
        else if (root.view !== "main") root.openMain()
        else root.close()
      }
      onTextKey: function(text) {
        if ((text === "d" || text === "D") && root.view === "main" && root.cursorIndex < root.configuredLayouts.length)
          root.requestDelete(root.cursorIndex)
        else if ((text === "e" || text === "E") && root.view === "main" && root.cursorIndex < root.configuredLayouts.length)
          root.startAlias(root.cursorIndex)
      }

      Flickable {
        id: panelFlick

        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: panelColumn

          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            foreground: Color.foreground
            fontFamily: Style.font.family
            title: root.view === "main" ? root.activeDescription : (root.view === "shortcut" ? "Switch shortcut" : (root.view === "alias" ? "Edit bar alias" : (root.view === "hotkey" ? "macOS-style hotkey" : "Add a language")))
            meta: root.view === "main" ? root.heroPhrase : (root.view === "shortcut" ? "XKB-supported shortcuts" : (root.view === "alias" && root.editingAliasLayout ? Model.descriptionFor(root.catalog, root.editingAliasLayout.layout, root.editingAliasLayout.variant) : (root.view === "hotkey" ? "Key combination to capture" : "Installed XKB layouts")))
            detail: root.view === "main" ? root.layoutLabel : (root.view === "alias" ? root.aliasPreview : (root.view === "hotkey" ? Model.normalizeHotkey(root.pendingHotkey) || root.mruHotkey : ""))

            iconComponent: Component {
              Text {
                text: root.view === "main" ? "󰌌" : (root.view === "shortcut" ? "󰁔" : (root.view === "alias" ? "󰏫" : (root.view === "hotkey" ? "󰌒" : "󰐕")))
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          Column {
            visible: root.view === "main"
            width: parent.width
            spacing: Style.space(6)

            Column {
              visible: root.conflictOption !== ""
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: "XKB shortcut " + root.conflictOption + " is also live in the keymap — one press would switch languages twice."
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Button {
                text: applyProc.running ? "Fixing…" : "Remove XKB conflict"
                leftAlign: true
                focusable: true
                bordered: true
                enabled: root.stateReady && !applyProc.running
                foreground: Color.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                onClicked: root.runAction(["reapply"], "XKB shortcut removed from the keymap.")
              }
            }

            PanelSectionHeader {
              text: "Available languages"
              foreground: Color.foreground
              fontFamily: Style.font.family
            }

            Repeater {
              model: root.configuredLayouts

              CursorSurface {
                required property int index
                required property var modelData

                width: parent.width
                implicitHeight: languageRow.implicitHeight + Style.spacing.md * 2
                current: index === root.activeLayoutIndex
                hasCursor: root.view === "main" && root.cursorIndex === index
                foreground: Color.foreground
                accent: Color.accent

                HoverHandler {
                  onHoveredChanged: {
                    if (hovered) root.cursorIndex = index
                  }
                }

                TapHandler {
                  onTapped: root.switchLayout(index)
                }

                Row {
                  id: languageRow

                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(12)

                  BorderSurface {
                    id: aliasBadge

                    width: Math.max(Style.space(34), aliasText.implicitWidth + Style.spacing.sm * 2)
                    height: Style.space(28)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    borderSpec: Border.controlSpec(index === root.activeLayoutIndex ? "selected" : "normal", Color.foreground, Color.accent)
                    radius: Style.cornerRadius

                    Text {
                      id: aliasText
                      anchors.centerIn: parent
                      text: Model.labelFor(root.catalog, modelData.layout, modelData.variant, modelData.alias)
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  Column {
                    width: Math.max(0, parent.width - aliasBadge.width - editAliasButton.width - moveUpButton.width - moveDownButton.width - deleteButton.width - parent.spacing * 5)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    Text {
                      width: parent.width
                      text: Model.descriptionFor(root.catalog, modelData.layout, modelData.variant)
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: index === root.activeLayoutIndex
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: modelData.layout.toUpperCase() + (modelData.variant ? " · " + modelData.variant : " · DEFAULT")
                      color: Qt.darker(Color.foreground, 1.45)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  PanelActionButton {
                    id: editAliasButton

                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "󰏫"
                    tooltipText: "Edit bar alias"
                    foreground: Color.foreground
                    fontFamily: Style.font.family
                    enabled: root.stateReady && !applyProc.running
                    onClicked: root.startAlias(index)
                  }

                  PanelActionButton {
                    id: moveUpButton

                    readonly property var moveVerdict: Model.canMove(root.configuredLayouts, index, -1)

                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "↑"
                    tooltipText: moveVerdict.ok ? "Move up" : moveVerdict.reason
                    foreground: Color.foreground
                    fontFamily: Style.font.family
                    enabled: root.stateReady && moveVerdict.ok && !applyProc.running
                    onClicked: root.moveLanguage(index, -1)
                  }

                  PanelActionButton {
                    id: moveDownButton

                    readonly property var moveVerdict: Model.canMove(root.configuredLayouts, index, 1)

                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "↓"
                    tooltipText: moveVerdict.ok ? "Move down" : moveVerdict.reason
                    foreground: Color.foreground
                    fontFamily: Style.font.family
                    enabled: root.stateReady && moveVerdict.ok && !applyProc.running
                    onClicked: root.moveLanguage(index, 1)
                  }

                  PanelActionButton {
                    id: deleteButton

                    readonly property var deleteVerdict: Model.canDelete(root.configuredLayouts, index)

                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "󰅙"
                    tooltipText: deleteVerdict.ok ? "Remove language" : deleteVerdict.reason
                    foreground: Color.foreground
                    hoverColor: Color.urgent
                    fontFamily: Style.font.family
                    enabled: root.stateReady && deleteVerdict.ok && !applyProc.running
                    onClicked: root.requestDelete(index)
                  }
                }
              }
            }

            Item {
              width: 1
              height: Style.space(4)
            }

            PanelSeparator {
              width: parent.width
              foreground: Color.foreground
            }

            Toggle {
              width: parent.width
              label: "macOS-style switching"
              description: root.switchMode === "mru" ? "Quick tap toggles between the two most recent languages. Rapid taps cycle all." : "XKB shortcut cycles through all languages."
              checked: root.switchMode === "mru"
              enabled: root.stateReady && !applyProc.running
              foreground: Color.foreground
              accent: Color.accent
              fontFamily: Style.font.family
              onClicked: root.toggleSwitchMode()
            }

            Button {
              width: parent.width
              text: "Switch shortcut"
              iconText: "󰁔"
              leftAlign: true
              focusable: true
              enabled: root.stateReady && !applyProc.running
              foreground: Color.foreground
              fontFamily: Style.font.family
              hasCursor: root.cursorIndex === root.configuredLayouts.length
              onHovered: function(hovered) {
                if (hovered) root.cursorIndex = root.configuredLayouts.length
              }
              onClicked: root.startShortcut()
            }

            Text {
              width: parent.width
              leftPadding: Style.spacing.controlPaddingX
              text: root.shortcutLabel(root.switchOption) + (root.switchMode === "mru" ? " (active in XKB mode)" : "")
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Button {
              width: parent.width
              text: "macOS-style hotkey"
              iconText: "󰌒"
              leftAlign: true
              focusable: true
              enabled: root.stateReady && !applyProc.running
              foreground: Color.foreground
              fontFamily: Style.font.family
              onClicked: root.startHotkey()
            }

            Text {
              width: parent.width
              leftPadding: Style.spacing.controlPaddingX
              text: root.mruHotkey + (root.switchMode === "xkb" ? " (inactive in XKB mode)" : "")
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Button {
              width: parent.width
              text: "Add language"
              iconText: "󰐕"
              leftAlign: true
              focusable: true
              enabled: root.stateReady && !applyProc.running
              foreground: Color.foreground
              fontFamily: Style.font.family
              hasCursor: root.cursorIndex === root.configuredLayouts.length + 1
              onHovered: function(hovered) {
                if (hovered) root.cursorIndex = root.configuredLayouts.length + 1
              }
              onClicked: root.startAdd()
            }
          }

          Column {
            visible: root.view === "shortcut"
            width: parent.width
            spacing: Style.space(12)

            Text {
              width: parent.width
              text: "Choose how languages cycle in XKB mode. Cancel keeps " + root.shortcutLabel(root.switchOption) + "."
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            KeyboardSearchableDropdown {
              id: shortcutPicker

              width: parent.width
              label: "Keyboard shortcut"
              placeholderText: "Search supported shortcuts…"
              emptyText: "No supported shortcut matches"
              foreground: Color.foreground
              fontFamily: Style.font.family
              rowHeight: root.pickerControlHeight
              popupRowHeight: root.pickerPopupRowHeight
              options: root.catalog.shortcuts
              onChanged: function(value) {
                root.selectedShortcut = value
              }
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Button {
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: Color.foreground
                fontFamily: Style.font.family
                onClicked: root.openMain()
              }

              Button {
                text: applyProc.running ? "Applying…" : "Apply"
                focusable: true
                bordered: true
                enabled: root.stateReady && !applyProc.running && root.selectedShortcut !== "" && root.selectedShortcut !== root.switchOption
                foreground: Color.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                onClicked: root.saveShortcut()
              }
            }
          }

          Column {
            visible: root.view === "add"
            width: parent.width
            spacing: Style.space(12)

            Text {
              width: parent.width
              text: "Add an XKB language and optional variant. The new language becomes active immediately."
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            KeyboardSearchableDropdown {
              id: languagePicker

              width: parent.width
              label: "Language"
              placeholderText: "Search languages…"
              emptyText: "No language matches"
              foreground: Color.foreground
              fontFamily: Style.font.family
              rowHeight: root.pickerControlHeight
              popupRowHeight: root.pickerPopupRowHeight
              options: Model.baseLayoutOptions(root.catalog, root.configuredLayouts)
              onChanged: function(value) {
                root.selectedLayout = value
                variantPicker.resetSearch()
                var variants = Model.variantOptions(root.catalog, value, root.configuredLayouts)
                root.selectedVariant = variants.length > 0 ? variants[0].value : ""
                variantPicker.setCurrentValue(root.selectedVariant)
              }
            }

            KeyboardSearchableDropdown {
              id: variantPicker

              width: parent.width
              label: "Variant"
              placeholderText: root.selectedLayout ? "Search variants…" : "Choose a language first"
              emptyText: "No unused variants"
              enabled: root.selectedLayout !== ""
              foreground: Color.foreground
              fontFamily: Style.font.family
              rowHeight: root.pickerControlHeight
              popupRowHeight: root.pickerPopupRowHeight
              options: Model.variantOptions(root.catalog, root.selectedLayout, root.configuredLayouts)
              triggerLabel: root.selectedLayout ? "Default" : ""
              onChanged: function(value) {
                root.selectedVariant = value
              }
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Button {
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: Color.foreground
                fontFamily: Style.font.family
                onClicked: root.openMain()
              }

              Button {
                text: applyProc.running ? "Adding…" : "Add"
                focusable: true
                bordered: true
                enabled: root.stateReady && !applyProc.running && root.selectedLayout !== ""
                foreground: Color.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                onClicked: root.addSelected()
              }
            }
          }

          Column {
            visible: root.view === "alias"
            width: parent.width
            spacing: Style.space(12)

            Text {
              width: parent.width
              text: "Choose a compact label for this language in the bar and HUD. Clear it to return to the automatic \u201C" + root.automaticAlias + "\u201D label."
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            TextField {
              id: aliasField

              width: parent.width
              placeholderText: root.automaticAlias
              foreground: Color.foreground
              accent: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              onTextChanged: root.selectedAlias = text
              onAccepted: {
                if (root.aliasValidationError === "" && Model.normalizeAlias(root.selectedAlias) !== String(root.editingAliasLayout ? root.editingAliasLayout.alias || "" : ""))
                  root.saveAlias()
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.openMain()
                  event.accepted = true
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                width: Math.max(0, parent.width - aliasPreviewBadge.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: root.aliasValidationError !== "" ? root.aliasValidationError : "Preview · " + Model.aliasLength(Model.normalizeAlias(root.selectedAlias)) + " / 6"
                color: root.aliasValidationError !== "" ? Color.urgent : Qt.darker(Color.foreground, 1.45)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              BorderSurface {
                id: aliasPreviewBadge

                width: Math.max(Style.space(34), aliasPreviewText.implicitWidth + Style.spacing.sm * 2)
                height: Style.space(28)
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                borderSpec: Border.controlSpec("selected", Color.foreground, Color.accent)
                radius: Style.cornerRadius

                Text {
                  id: aliasPreviewText
                  anchors.centerIn: parent
                  text: root.aliasPreview
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Button {
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: Color.foreground
                fontFamily: Style.font.family
                onClicked: root.openMain()
              }

              Button {
                text: "Use default"
                focusable: true
                bordered: true
                enabled: root.editingAliasLayout && root.editingAliasLayout.alias !== "" && !applyProc.running
                foreground: Color.foreground
                fontFamily: Style.font.family
                onClicked: root.useAutomaticAlias()
              }

              Button {
                text: applyProc.running ? "Saving…" : "Save"
                focusable: true
                bordered: true
                enabled: root.stateReady && !applyProc.running && root.aliasValidationError === "" && Model.normalizeAlias(root.selectedAlias) !== String(root.editingAliasLayout ? root.editingAliasLayout.alias || "" : "")
                foreground: Color.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                onClicked: root.saveAlias()
              }
            }
          }

          Column {
            visible: root.view === "hotkey"
            width: parent.width
            spacing: Style.space(12)

            Text {
              width: parent.width
              text: "Press the key combination for macOS-style switching. Currently: " + root.mruHotkey + "."
              color: Qt.darker(Color.foreground, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Item {
              id: hotkeyCatcher

              width: parent.width
              height: captureBox.height
              activeFocusOnTab: true
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.openMain()
                  event.accepted = true
                  return
                }
                var combo = root.hotkeyFromKeyEvent(event)
                if (combo === "") return
                root.pendingHotkey = combo
                root.statusText = ""
                root.statusError = false
                event.accepted = true
              }

              BorderSurface {
                id: captureBox

                width: parent.width
                height: Style.spacing.controlHeight + Style.space(12)
                radius: Style.cornerRadius
                color: Style.controlFill(false, true, Color.foreground, Color.accent)
                borderSpec: Border.controlSpec("focus", Color.foreground, Color.accent)

                Text {
                  anchors.centerIn: parent
                  text: root.pendingHotkey === "" ? "Press a key combination…" : Model.normalizeHotkey(root.pendingHotkey)
                  color: root.pendingHotkey === "" ? Qt.darker(Color.foreground, 1.5) : Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }
            }

            Text {
              visible: root.pendingHotkey !== "" && Model.hotkeyError(root.pendingHotkey) !== ""
              width: parent.width
              text: Model.hotkeyError(root.pendingHotkey)
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Button {
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: Color.foreground
                fontFamily: Style.font.family
                onClicked: root.openMain()
              }

              Button {
                text: applyProc.running ? "Saving…" : "Apply"
                focusable: true
                bordered: true
                enabled: root.stateReady && !applyProc.running && Model.hotkeyError(root.pendingHotkey) === "" && Model.normalizeHotkey(root.pendingHotkey) !== root.mruHotkey
                foreground: Color.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                onClicked: root.saveHotkey()
              }
            }
          }

          Text {
            visible: root.statusText !== ""
            width: parent.width
            text: root.statusText
            color: root.statusError ? Color.urgent : Qt.darker(Color.foreground, 1.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }
        }

        QQC.ScrollBar.vertical: QQC.ScrollBar {
          policy: QQC.ScrollBar.AsNeeded
        }
      }

      ConfirmDialog {
        id: deleteDialog

        anchors.fill: parent
        message: root.pendingDeleteIndex >= 0 && root.pendingDeleteIndex < root.configuredLayouts.length ? "Remove " + Model.descriptionFor(root.catalog, root.configuredLayouts[root.pendingDeleteIndex].layout, root.configuredLayouts[root.pendingDeleteIndex].variant) + "?" : "Remove this keyboard language?"
        cancelText: "Keep"
        confirmText: "Remove"
        background: Color.popups.background
        foreground: Color.foreground
        fontFamily: Style.font.family
        onCanceled: {
          opened = false
          root.pendingDeleteIndex = -1
          keyCatcher.forceActiveFocus()
        }
        onConfirmed: root.deletePending()
      }
    }
  }
}
