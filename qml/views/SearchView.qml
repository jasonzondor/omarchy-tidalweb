import QtQuick
import qs.Commons

// Search is deep-linked, not reimplemented: type a query, the bridge navigates
// the existing TIDAL window to its search page and reveals it. The quick links
// do the same for the other discovery pages.
Item {
  id: root

  property var svc: null
  property color foreground: Color.menu.text
  property string fontFamily: Style.font.menuFamily

  function submit() {
    if (!root.svc) return
    root.svc.search(field.text)
    field.text = ""
  }

  function focusField() { field.forceActiveFocus() }

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(14)

    Rectangle {
      width: parent.width
      height: Style.space(40)
      radius: Style.space(6)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      border.width: field.activeFocus ? 1 : 0
      border.color: Color.accent

      TextInput {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        clip: true
        selectByMouse: true
        onAccepted: root.submit()

        Text {
          anchors.fill: parent
          visible: field.text === "" && !field.activeFocus
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
          text: "Search TIDAL…"
          color: Color.muted
          font: field.font
        }
      }
    }

    Flow {
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: [
          { label: "Home", path: "/" },
          { label: "Explore", path: "/explore" },
          { label: "My Collection", path: "/my-collection/tracks" },
          { label: "Playlists", path: "/my-collection/playlists" },
          { label: "Albums", path: "/my-collection/albums" }
        ]
        delegate: Rectangle {
          radius: Style.space(5)
          height: Style.space(30)
          width: linkText.implicitWidth + Style.space(20)
          color: linkHover.hovered
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

          Text {
            id: linkText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          HoverHandler { id: linkHover }
          TapHandler { onTapped: if (root.svc) root.svc.openPath(modelData.path) }
        }
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      text: "Results open in the TIDAL window on its own workspace. Playback, lyrics and the queue then show up here."
      color: Color.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
