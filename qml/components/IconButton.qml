import QtQuick
import qs.Commons

// A round, glyph-only button. Nerd Font glyph in, click out.
Rectangle {
  id: root

  property string glyph: ""
  property real glyphSize: Style.font.body
  property color foreground: Color.menu.text
  property bool active: false
  property bool interactive: true
  property real diameter: Style.space(34)

  signal activated()

  implicitWidth: diameter
  implicitHeight: diameter
  radius: diameter / 2
  color: active
    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
    : (hover.hovered && interactive
       ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
       : "transparent")
  opacity: interactive ? 1 : 0.35

  Behavior on color { ColorAnimation { duration: 120 } }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    textFormat: Text.PlainText
    color: root.active ? Color.accent : root.foreground
    font.family: Style.font.family
    font.pixelSize: root.glyphSize
  }

  HoverHandler { id: hover; enabled: root.interactive }

  TapHandler {
    enabled: root.interactive
    onTapped: root.activated()
  }
}
