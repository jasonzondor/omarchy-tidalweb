import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "components"
import "views"

// The plugin's single summoned surface. A plugin only gets ONE panel-kind
// entry point, so the player, lyrics, queue and search are views here rather
// than separate surfaces, chosen by the summon payload:
//
//   omarchy-shell shell summon com.zondor.tidalweb '{"view":"lyrics"}'
//
// keepLoaded is set in the manifest, so this window and its state survive
// between summons.
Item {
  id: root

  // Injected by the shell host.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var service: null

  readonly property string pluginId: "com.zondor.tidalweb"
  readonly property var svc: service || (shell ? shell.serviceFor(pluginId) : null)

  property bool opened: false
  property string currentView: "player"
  property var targetScreen: null

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color borderColor: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property string fontFamily: Style.font.menuFamily

  readonly property bool showsTransport: currentView !== "search"

  function open(payloadJson) {
    var args = {}
    if (payloadJson) {
      try { args = JSON.parse(payloadJson) || {} } catch (e) { args = {} }
    }
    var view = String(args.view || "player")
    if (["player", "lyrics", "queue", "search"].indexOf(view) === -1) view = "player"
    root.currentView = view
    root.targetScreen = root.pickScreen()
    root.opened = true
    if (view === "search") Qt.callLater(function () { searchView.focusField() })
    if (root.svc) root.svc.ensureWeb()
  }

  function close() { root.opened = false }

  function pickScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === name) return screens[i]
    }
    return null
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tidalweb"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: root.opened
      Keys.onEscapePressed: root.close()
      Keys.onPressed: function (event) {
        if (!root.svc) return
        if (event.key === Qt.Key_Space) { root.svc.playPause(); event.accepted = true }
        else if (event.key === Qt.Key_L) { root.currentView = "lyrics"; event.accepted = true }
        else if (event.key === Qt.Key_Q) { root.currentView = "queue"; event.accepted = true }
        else if (event.key === Qt.Key_P) { root.currentView = "player"; event.accepted = true }
        else if (event.key === Qt.Key_Slash) { root.currentView = "search"; event.accepted = true }
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(520), parent.width - Style.gapsOut * 6)
        height: Math.min(Style.space(660), parent.height - Style.gapsOut * 6)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(10)
        color: root.background
        border.width: Math.max(1, Style.space(1))
        border.color: root.borderColor

        MouseArea { anchors.fill: parent }

        // ---- header ----
        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(16)
          height: Style.space(30)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "TIDAL"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            IconButton {
              glyph: ""
              foreground: root.foreground
              active: root.currentView === "player"
              glyphSize: Style.font.bodySmall
              onActivated: root.currentView = "player"
            }
            IconButton {
              glyph: ""
              foreground: root.foreground
              active: root.currentView === "lyrics"
              glyphSize: Style.font.bodySmall
              onActivated: root.currentView = "lyrics"
            }
            IconButton {
              glyph: ""
              foreground: root.foreground
              active: root.currentView === "queue"
              glyphSize: Style.font.bodySmall
              onActivated: root.currentView = "queue"
            }
            IconButton {
              glyph: ""
              foreground: root.foreground
              active: root.currentView === "search"
              glyphSize: Style.font.bodySmall
              onActivated: root.currentView = "search"
            }
            IconButton {
              glyph: ""
              foreground: root.foreground
              glyphSize: Style.font.bodySmall
              onActivated: if (root.svc) root.svc.showWeb()
            }
          }
        }

        Rectangle {
          id: rule
          anchors.top: header.bottom
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          color: root.borderColor
          opacity: 0.5
        }

        // ---- views ----
        Item {
          id: body
          anchors.top: rule.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: transport.visible ? transport.top : parent.bottom
          anchors.margins: Style.space(8)

          PlayerView {
            anchors.fill: parent
            visible: root.currentView === "player"
            svc: root.svc
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          LyricsView {
            anchors.fill: parent
            visible: root.currentView === "lyrics"
            svc: root.svc
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          QueueView {
            anchors.fill: parent
            visible: root.currentView === "queue"
            svc: root.svc
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          SearchView {
            id: searchView
            anchors.fill: parent
            visible: root.currentView === "search"
            svc: root.svc
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
        }

        TransportBar {
          id: transport
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          anchors.bottomMargin: Style.space(8)
          visible: root.showsTransport
          svc: root.svc
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }
    }
  }
}
