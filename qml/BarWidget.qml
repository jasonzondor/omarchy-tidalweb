import QtQuick
import qs.Ui
import qs.Commons
import "components"
import "lib/Format.js" as Format

// TIDAL now-playing for the Omarchy bar.
//
//   left click  = open the player       right click = open lyrics
//   middle click = play / pause         scroll      = previous / next
//
// State is read from the plugin's service (bound to Chromium over MPRIS), so
// this never polls and never speaks to Chromium itself.
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
  // Off by default: the widget is the way into the player, so it stays in the
  // bar even when nothing is playing. On for anyone who only wants it while
  // music is going.
  readonly property bool hideWhenPaused: setting("hideWhenPaused", false)

  readonly property string label: Format.trackLabel(title, artist)

  // The sleeve stands in for the mark only while it has one to show.
  readonly property bool showArt: !vertical && artUrl !== "" && showLabel && hasTrack
  readonly property bool showText: showLabel && !vertical && hasTrack && label !== ""

  readonly property bool idleHidden: hideWhenPaused && !playing

  // No own panel: the plugin's overlay is its panel surface, and the shell
  // routes summons there. These keep the bar's hotkey plumbing happy.
  readonly property bool opened: false
  function open() { if (svc) svc.openView("player") }
  function close() {}
  function toggle() { if (svc) svc.openView("player") }

  visible: !idleHidden
  implicitWidth: idleHidden
    ? 0
    : (vertical ? barSize : content.implicitWidth + Style.space(14))
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
      text: ""
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
      if (mouse.button === Qt.LeftButton) root.svc.openView("player")
      else if (mouse.button === Qt.RightButton) root.svc.openView("lyrics")
      else if (mouse.button === Qt.MiddleButton) root.svc.playPause()
    }

    onWheel: function (wheel) {
      if (!root.svc) return
      if (wheel.angleDelta.y > 0) root.svc.previous()
      else if (wheel.angleDelta.y < 0) root.svc.next()
    }
  }
}
