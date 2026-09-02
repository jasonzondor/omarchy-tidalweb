import QtQuick
import qs.Commons

// Lyrics scraped from the TIDAL web player by the bridge. Lines arrive as plain
// text with an active-line index when TIDAL highlights one; there is no
// per-line timing, so the view follows that index and does not interpolate.
Item {
  id: root

  property var svc: null
  property color foreground: Color.menu.text
  property string fontFamily: Style.font.menuFamily

  readonly property var lines: svc ? svc.lyricsLines : []
  readonly property int active: svc ? svc.lyricsActive : -1

  onActiveChanged: if (active >= 0) list.positionViewAtIndex(active, ListView.Center)

  ListView {
    id: list
    anchors.fill: parent
    anchors.margins: Style.space(8)
    model: root.lines
    clip: true
    spacing: Style.space(6)
    boundsBehavior: Flickable.StopAtBounds

    delegate: Text {
      width: list.width
      textFormat: Text.PlainText
      text: modelData
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      color: index === root.active ? Color.accent : root.foreground
      opacity: root.active < 0 ? 0.85 : (index === root.active ? 1 : 0.45)
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.weight: index === root.active ? Font.DemiBold : Font.Normal
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.lines.length === 0
    width: parent.width - Style.space(60)
    textFormat: Text.PlainText
    text: "No lyrics here.\nOpen the browser, show the TIDAL lyrics panel, and they will appear."
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    color: Color.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
