import QtQuick
import qs.Commons

// The play queue, read from the TIDAL web player by the bridge. Double-click a
// row and the bridge asks the web player to jump there.
Item {
  id: root

  property var svc: null
  property color foreground: Color.menu.text
  property string fontFamily: Style.font.menuFamily

  readonly property var tracks: svc ? svc.queue : []

  ListView {
    id: list
    anchors.fill: parent
    anchors.margins: Style.space(6)
    model: root.tracks
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    delegate: Rectangle {
      width: list.width
      height: Style.space(40)
      radius: Style.space(4)
      color: rowHover.hovered
        ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        : "transparent"

      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: 0

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: modelData.title || ""
          elide: Text.ElideRight
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width
          visible: (modelData.artist || "") !== ""
          textFormat: Text.PlainText
          text: modelData.artist || ""
          elide: Text.ElideRight
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      HoverHandler { id: rowHover }
      TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: if (root.svc) root.svc.playQueueIndex(modelData.index !== undefined ? modelData.index : index)
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.tracks.length === 0
    width: parent.width - Style.space(60)
    textFormat: Text.PlainText
    text: "The queue is empty, or the TIDAL web player has not opened its queue panel yet."
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    color: Color.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
