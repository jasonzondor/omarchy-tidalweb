import QtQuick
import qs.Ui
import qs.Commons
import "components"
import "lib/Format.js" as Format

// TIDAL for the Omarchy bar.
//
//   left / right click = drop the TIDAL window down (or tuck it away)
//   middle click       = play / pause
//   scroll             = previous / next
//
// Now-playing is read from the plugin's service (bound to Chromium over MPRIS),
// so this never polls and never talks to Chromium itself.
BarWidget {
  id: root
  moduleName: "com.zondor.tidalweb"

  readonly property var svc: bar?.shell?.serviceFor("com.zondor.tidalweb") ?? null

  readonly property bool hasTrack: svc ? svc.hasTrack : false
  readonly property bool playing: svc ? svc.playing : false
  readonly property string title: svc ? svc.title : ""
  readonly property string artist: svc ? svc.artist : ""
  readonly property string artUrl: svc ? svc.artUrl : ""

  readonly property real maxLabelWidth: setting("maxLabelWidth", 260)
  readonly property bool showLabel: setting("showLabel", true)
  // Off by default: the widget is the way into TIDAL, so it stays in the bar
  // even when nothing is playing.
  readonly property bool hideWhenPaused: setting("hideWhenPaused", false)

  readonly property string label: Format.trackLabel(title, artist)
  readonly property bool showArt: !vertical && artUrl !== "" && showLabel && hasTrack
  readonly property bool showText: showLabel && !vertical && hasTrack && label !== ""
  readonly property bool idleHidden: hideWhenPaused && !hasTrack

  // ---- panel state ----
  //
  // The drop-down is a real Chromium window, not a Quickshell popout, so the
  // bar's own popout coordinator does not know about it. We register with it
  // by hand whenever the service says the panel is showing: that both draws the
  // accent under-line and lets opening any other bar popup close this one.
  readonly property bool panelOpen: svc ? svc.panelVisible : false
  readonly property bool opened: panelOpen
  readonly property real openPanelIndicatorWidth: content.implicitWidth

  function open() { if (svc) svc.showWeb() }
  function close() { if (svc) svc.hideWeb() }
  function closeForPopoutSwitch() { if (svc) svc.hideWeb() }
  function toggle() { if (svc) svc.toggleWeb() }

  // One Service, one shared bar popout slot — but a widget instance per monitor
  // bar, and every instance runs syncPopout() when the panel opens. If the
  // second instance also calls requestPopout(), the bar evicts the first and
  // the eviction fires the first instance's closeForPopoutSwitch() -> hideWeb(),
  // slamming shut the panel that was just opened. So an instance registers only
  // when no sibling (same moduleName, other monitor) already holds the slot.
  // Single-monitor: one instance, no sibling, no fight — which is why this only
  // ever broke with 2+ monitors.
  function siblingHoldsPopout() {
    return !!(bar && bar.activePopout && bar.activePopout !== root
      && bar.activePopout.moduleName === moduleName)
  }

  function syncPopout() {
    if (!bar || typeof bar.requestPopout !== "function") return
    if (panelOpen) {
      if (bar.activePopout !== root && !siblingHoldsPopout()) bar.requestPopout(root)
    } else if (bar.activePopout === root) {
      bar.releasePopout(root)
    }
  }

  // The bar's own drag-to-reorder MouseArea sits on top of every module and
  // claims the left button (to tell a click from a drag), so a plain MouseArea
  // on the widget never sees a left-click any more. The bar instead looks up a
  // registered click target under the cursor and calls `triggerPress` on it —
  // the same contract Ui/WidgetButton.qml implements — so this widget has to
  // register itself and implement `triggerPress` to get its left-click back.
  // Right-click/middle-click/wheel aren't claimed by that MouseArea and still
  // reach the MouseArea below untouched.
  property var registeredBar: null

  function triggerPress(button) {
    if (bar) bar.hideTooltip(root)
    if (!svc) return
    if (button === Qt.MiddleButton) svc.playPause()
    else svc.toggleWeb()
  }

  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    registeredBar = bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(root)
  }

  onPanelOpenChanged: syncPopout()
  onBarChanged: { syncPopout(); syncClickRegistration() }
  Component.onCompleted: { syncPopout(); syncClickRegistration() }
  Component.onDestruction: {
    if (bar && bar.activePopout === root && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
  }

  readonly property color fg: bar ? bar.barForeground : Color.bar.text
  readonly property string barFont: bar ? bar.fontFamily : Style.font.family

  visible: !idleHidden
  // Never collapse to nothing: even with no track the widget is a clickable
  // entry point and must stay findable in the bar.
  implicitWidth: idleHidden
    ? 0
    : (vertical ? barSize : Math.max(Math.round(barSize * 0.9), content.implicitWidth + Style.space(14)))
  implicitHeight: vertical ? content.implicitHeight + Style.space(10) : barSize

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(7)

    RoundedImage {
      anchors.verticalCenter: parent.verticalCenter
      width: visible ? Math.round(root.barSize * 0.58) : 0
      height: width
      radius: Style.space(2)
      decodeSize: 64
      visible: root.showArt
      source: root.artUrl
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.showArt
      textFormat: Text.PlainText
      text: "󰝚"
      color: root.playing ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.75)
      font.family: root.barFont
      font.pixelSize: Style.font.icon
    }

    Text {
      id: labelText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showText
      width: visible ? Math.min(implicitWidth, root.maxLabelWidth) : 0
      textFormat: Text.PlainText
      text: root.label
      elide: Text.ElideRight
      color: root.fg
      font.family: root.barFont
      font.pixelSize: Style.font.body
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (!root.svc) return
      if (mouse.button === Qt.MiddleButton) root.svc.playPause()
      else root.svc.toggleWeb()
    }

    onWheel: function (wheel) {
      if (!root.svc) return
      if (wheel.angleDelta.y > 0) root.svc.previous()
      else if (wheel.angleDelta.y < 0) root.svc.next()
    }
  }
}
