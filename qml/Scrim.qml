import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Click-away dismissal for the TIDAL drop-down.
//
// The panel is a real Chromium window, so it can't use Quickshell's normal
// popup scrim / HyprlandFocusGrab. Instead this is a full-screen, transparent
// layer-shell surface above the windows, with its input region punched out
// over the panel (clicks there fall through to Chromium) and over the bar
// (so other bar widgets stay clickable). A press anywhere else tucks the
// panel away — an actual click, not hover.
Item {
  id: root

  // Injected by the shell host.
  property var service: null
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property string omarchyPath: ""

  readonly property var svc: service
  readonly property rect r: svc ? svc.panelRect : Qt.rect(0, 0, 0, 0)
  readonly property bool showScrim: svc && svc.panelVisible && r.width > 0 && r.height > 0

  // Never summoned; it lives off the service's panelVisible. Stubs keep the
  // shell's panel routing happy.
  property bool opened: false
  function open() {}
  function close() {}

  function pickScreen() {
    var mon = Hyprland.focusedMonitor
    var name = mon ? String(mon.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (String(screens[i].name) === name) return screens[i]
    return null
  }

  PanelWindow {
    id: scrim
    visible: root.showScrim
    screen: root.pickScreen()
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "omarchy-tidalweb-scrim"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      width: scrim.width
      height: scrim.height

      // The panel itself — clicks here pass through to Chromium.
      Region {
        x: Math.round(root.r.x) - 1
        y: Math.round(root.r.y) - 1
        width: Math.round(root.r.width) + 2
        height: Math.round(root.r.height) + 2
        intersection: Intersection.Subtract
      }
      // The bar strip — leave other bar widgets clickable.
      Region {
        x: 0
        y: 0
        width: scrim.width
        height: root.svc ? root.svc.barHeight : 0
        intersection: Intersection.Subtract
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onPressed: if (root.svc) root.svc.hideWeb()
    }
  }
}
