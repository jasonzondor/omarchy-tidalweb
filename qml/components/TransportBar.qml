import QtQuick
import qs.Commons

// The transport strip shared by every overlay view: it should not vanish just
// because you switched to lyrics or the queue.
Item {
  id: root

  property var svc: null
  property color foreground: Color.menu.text
  property string fontFamily: Style.font.menuFamily

  implicitHeight: Style.space(58)

  readonly property bool playing: svc ? svc.playing : false

  Column {
    anchors.fill: parent
    spacing: Style.space(4)

    SeekBar {
      width: parent.width
      svc: root.svc
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Item {
      width: parent.width
      height: Style.space(30)

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)

        IconButton {
          glyph: ""
          foreground: root.foreground
          glyphSize: Style.font.subtitle
          onActivated: if (root.svc) root.svc.previous()
        }
        IconButton {
          glyph: root.playing ? "" : ""
          foreground: root.foreground
          glyphSize: Style.font.title
          diameter: Style.space(40)
          onActivated: if (root.svc) root.svc.playPause()
        }
        IconButton {
          glyph: ""
          foreground: root.foreground
          glyphSize: Style.font.subtitle
          onActivated: if (root.svc) root.svc.next()
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        IconButton {
          glyph: ""
          foreground: root.foreground
          glyphSize: Style.font.bodySmall
          onActivated: if (root.svc) root.svc.favorite()
        }
        IconButton {
          glyph: ""
          foreground: root.foreground
          glyphSize: Style.font.bodySmall
          onActivated: if (root.svc) root.svc.showWeb()
        }
      }
    }
  }
}
