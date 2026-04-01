import QtQuick
import QtQuick.Controls

Rectangle {
    id: btn
    property string text: "Button"
    property color  bgColor: theme.accent
    property color  hoverColor: theme.accentHover
    property color  textColor: "white"
    property bool   enabled: true
    property int    textSize: 13
    property string icon: ""
    signal clicked()

    height: 36
    radius: 8
    color: !btn.enabled
           ? theme.surfaceAlt
           : (ma.containsMouse ? btn.hoverColor : btn.bgColor)
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    opacity: btn.enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: btn.icon !== ""
            text: btn.icon
            font.pixelSize: btn.textSize
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: btn.text
            color: !btn.enabled ? theme.textMuted : btn.textColor
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            font {
                pixelSize: btn.textSize
                bold: true
                family: "Segoe UI"
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
