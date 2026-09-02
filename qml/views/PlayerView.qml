import QtQuick
import qs.Commons
import "../components"

// Now playing: sleeve, the three lines of metadata, and the stream-quality
// badge when the bridge could read one.
Item {
  id: root

  property var svc: null
  property color foreground: Color.menu.text
  property string fontFamily: Style.font.menuFamily

  readonly property bool hasTrack: svc ? svc.hasTrack : false

  Column {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(40), Style.space(360))
    spacing: Style.space(16)

    RoundedImage {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, Style.space(300))
      height: width
      radius: Style.space(6)
      decodeSize: 640
      source: root.svc ? root.svc.artUrl : ""
    }

    Column {
      width: parent.width
      spacing: Style.space(3)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.svc && root.svc.title ? root.svc.title : "Nothing playing"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        visible: root.svc && root.svc.artist !== ""
        textFormat: Text.PlainText
        text: root.svc ? root.svc.artist : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        visible: root.svc && root.svc.album !== ""
        textFormat: Text.PlainText
        text: root.svc ? root.svc.album : ""
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.svc && root.svc.qualityLabel !== ""
      width: qualityText.implicitWidth + Style.space(12)
      height: qualityText.implicitHeight + Style.space(5)
      radius: Style.space(4)
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)

      Text {
        id: qualityText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.svc ? root.svc.qualityLabel : ""
        color: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: !root.hasTrack
      textFormat: Text.PlainText
      text: "Open the browser and start something on TIDAL"
      color: Color.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
