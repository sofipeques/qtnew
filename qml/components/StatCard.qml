import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ── Single stat card ─────────────────────────────────────────────────────────
Rectangle {
    id: card
    property string icon: "📦"
    property string value: "0"
    property string label: "Label"
    property color  accentColor: theme.accent

    radius: 10
    color: theme.surface
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    ThemeTransition { anchors.fill: parent; radius: parent.radius }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.06)
    }

    // Top accent line
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 3; radius: 2
        color: card.accentColor
        opacity: 0.8
    }

    // Border
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: "transparent"
        border {
            color: theme.border
            width: 1
        }
        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    }

    RowLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 10

        Text {
            text: card.icon
            font.pixelSize: 26
        }

        Column {
            spacing: 2
            Text {
                text: card.value
                color: card.accentColor
                font {
                    pixelSize: 20
                    bold: true
                    family: "Segoe UI"
                }
            }
            Text {
                text: card.label
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 11
                    family: "Segoe UI"
                }
            }
        }
    }
}
