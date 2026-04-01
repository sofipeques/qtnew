import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property bool checked: false
    property string labelOn: "ON"
    property string labelOff: "OFF"
    signal toggled()

    width: 60; height: 30; radius: 15
    clip: true
    color: root.checked ? theme.accent : theme.surfaceAlt
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    Rectangle {
        id: knob
        width: 22; height: 22; radius: 11
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4
        color: "white"

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 7
        text: root.labelOn
        color: "white"
        opacity: root.checked ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutCubic } }
        font { pixelSize: 12 }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 7
        text: root.labelOff
        color: theme.textMuted
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        opacity: root.checked ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutCubic } }
        font { pixelSize: 12 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
