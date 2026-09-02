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

  function syncPopout() {
    if (!bar || typeof bar.requestPopout !== "function") return
    if (panelOpen) bar.requestPopout(root)
    else if (bar.activePopout === root) bar.releasePopout(root)
  }

  onPanelOpenChanged: syncPopout()
  onBarChanged: syncPopout()
  Component.onCompleted: syncPopout()
  Component.onDestruction: {
    if (bar && bar.activePopout === root && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
  }

  visible: !idleHidden
  implicitWidth: idleHidden ? 0 : (vertical ? barSize : content.implicitWidth + Style.space(14))
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
      text: ""
      color: root.playing
        ? (root.bar ? root.bar.barForeground : Color.bar.text)
        : Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 1.6)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body * 1.1
    }

    Text {
      id: labelText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showText
      width: visible ? Math.min(implicitWidth, root.maxLabelWidth) : 0
      textFormat: Text.PlainText
      text: root.label
      elide: Text.ElideRight
      color: root.bar ? root.bar.barForeground : Color.bar.text
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
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
