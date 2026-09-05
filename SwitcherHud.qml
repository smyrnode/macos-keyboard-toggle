import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: hudWindow

  property bool opened: false
  property var layouts: ["US", "RU", "GR"]
  property var names: ["English", "Русский", "Ελληνικά"]
  property int activeIndex: 0
  property int duration: 1200

  visible: opened
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.namespace: "macos-keyboard-toggle-hud"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}

  function show(payloadJson) {
    try {
      var data = JSON.parse(payloadJson || "{}")
      if (Array.isArray(data.layouts) && data.layouts.length > 0) {
        hudWindow.layouts = data.layouts
      }
      if (Array.isArray(data.names) && data.names.length > 0) {
        hudWindow.names = data.names
      }
      if (typeof data.activeIndex === "number") {
        hudWindow.activeIndex = data.activeIndex
      }
      hudWindow.opened = true
      hideTimer.restart()
    } catch (e) {
      console.error("SwitcherHud parse error:", e)
    }
  }

  function close() {
    hudWindow.opened = false
  }

  Timer {
    id: hideTimer
    interval: hudWindow.duration
    onTriggered: hudWindow.opened = false
  }

  // Centered Floating HUD Container
  BorderSurface {
    id: card
    anchors.centerIn: parent
    color: Util.alpha(Color.background, 0.94)
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius * 1.5
    opacity: hudWindow.opened ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
    }

    readonly property int squareSize: Style.space(88)
    readonly property int squareSpacing: Style.space(10)
    readonly property int padding: Style.space(14)
    readonly property int count: Math.max(1, hudWindow.layouts.length)

    width: padding * 2 + (count * squareSize) + ((count - 1) * squareSpacing)
    height: padding * 2 + squareSize

    Item {
      anchors.fill: parent
      anchors.margins: card.padding

      // Selection Cursor (Smooth animated highlight rectangle)
      Rectangle {
        id: selectionCursor
        width: card.squareSize
        height: card.squareSize
        radius: Style.cornerRadius
        color: Util.alpha(Color.accent, 0.22)
        border.color: Color.accent
        border.width: 2
        z: 2

        x: Math.min(hudWindow.activeIndex, card.count - 1) * (card.squareSize + card.squareSpacing)

        Behavior on x {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }
      }

      // Row of language square blocks
      Row {
        id: squaresRow
        anchors.fill: parent
        spacing: card.squareSpacing

        Repeater {
          model: hudWindow.layouts

          Item {
            id: squareItem
            required property int index
            required property string modelData
            width: card.squareSize
            height: card.squareSize

            readonly property bool isSelected: index === hudWindow.activeIndex
            readonly property string displayName: (hudWindow.names && hudWindow.names[index]) ? hudWindow.names[index] : modelData

            // Background of each square
            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: Util.alpha(Color.popups.text, 0.05)
              border.color: Util.alpha(Color.popups.border, 0.25)
              border.width: 1

              Behavior on color {
                ColorAnimation { duration: 120 }
              }
            }

            // Square Content: Big Code + Name
            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)
              width: parent.width - Style.space(8)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: squareItem.modelData
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
                color: squareItem.isSelected ? Color.accent : Color.popups.text

                Behavior on color {
                  ColorAnimation { duration: 120 }
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: squareItem.displayName
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: squareItem.isSelected ? Color.popups.text : Util.alpha(Color.popups.text, 0.55)
                elide: Text.ElideRight
                width: parent.width
                horizontalAlignment: Text.AlignHCenter

                Behavior on color {
                  ColorAnimation { duration: 120 }
                }
              }
            }
          }
        }
      }
    }
  }
}
