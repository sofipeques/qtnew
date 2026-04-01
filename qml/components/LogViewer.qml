import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property alias model: listView.model
    property string title: "Log"

    color: theme.bg
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    radius: 8
    border.color: theme.border
    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    border.width: 1
    clip: true

    ThemeTransition { anchors.fill: parent; radius: parent.radius }

    function rowColor(entryText, entryKind) {
        if (entryKind === "completed" || entryKind === "all-completed"
                || entryText.indexOf("Completed download for:") >= 0
                || entryText.indexOf("All downloads have been completed") >= 0)
            return theme.green

        if (entryKind === "started" || entryText.indexOf("Starting download for:") >= 0)
            return theme.blue

        if (entryKind === "paused")
            return theme.orange

        if (entryKind === "error" || entryText.indexOf("[ERR]") >= 0)
            return theme.red

        return theme.textSecondary
    }

    function rowVisible(entryText) {
        return entryText.indexOf("Getting 'tsrdlticket' cookie") < 0
                && entryText.indexOf("Queue is now empty") < 0
                && entryText.indexOf("Moved ") < 0
                && entryText.indexOf("from queue to downloading") < 0
    }

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        radius: 8
        color: theme.surfaceAlt
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            color: parent.color
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: theme.border
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: theme.textSecondary
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            font.pixelSize: 11
            font.family: "Segoe UI"
            font.bold: true
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear"
            color: theme.textMuted
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            font.pixelSize: 10
            font.family: "Segoe UI"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.model)
                        root.model.clear()
                }
            }
        }
    }

    ListView {
        id: listView
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        clip: true
        spacing: 1
        verticalLayoutDirection: ListView.TopToBottom
        onCountChanged: positionViewAtEnd()

        delegate: Text {
            required property string modelData
            width: listView.width
            leftPadding: 8
            property string entryKind: typeof model.kind !== "undefined" ? model.kind : ""
            text: modelData
            visible: root.rowVisible(modelData)
            color: root.rowColor(modelData, entryKind)
            font.pixelSize: 11
            font.family: "Consolas"
            wrapMode: Text.WrapAnywhere
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: 3
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                opacity: 0.5
            }
        }
    }
}
