import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Popup {
    id: catDialog
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 400
    height: 500
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var selectedFiles: []
    signal confirmed(var files)

    background: Rectangle {
        radius: 14
        color: theme.surface
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        border.color: theme.border
        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        border.width: 1

        ThemeTransition { anchors.fill: parent; radius: parent.radius }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 52
            radius: 14
            color: theme.surfaceAlt
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 8
                color: parent.color
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: theme.border
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Text {
                    text: "☰  Select Categories"
                    color: theme.textPrimary
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "Segoe UI"
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: cHov.containsMouse ? theme.red : theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: cHov.containsMouse ? "white" : theme.textMuted
                        Behavior on color { ColorAnimation { duration: 120 } }
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: cHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: catDialog.close()
                    }
                }
            }
        }

        // File list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            clip: true
            spacing: 4
            model: notepadMgr.files

            delegate: Rectangle {
                required property var modelData
                required property int index
                property bool chkd: catDialog.selectedFiles.includes(modelData.relPath)

                width: ListView.view.width
                height: 40
                radius: 8
                color: chkd ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: chkd ? theme.accent : theme.border
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 5
                        color: chkd ? theme.accent : "transparent"
                        border.color: chkd ? theme.accent : theme.border
                        border.width: 2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            visible: chkd
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Text {
                        text: "📄 " + modelData.name
                        color: theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 12
                        font.family: "Segoe UI"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let arr = catDialog.selectedFiles.slice()
                        let i = arr.indexOf(modelData.relPath)
                        if (i >= 0) arr.splice(i, 1)
                        else arr.push(modelData.relPath)
                        catDialog.selectedFiles = arr
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    radius: 3
                    color: theme.textMuted
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    opacity: 0.4
                }
            }
        }

        // Bottom bar
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 8

            Text {
                text: catDialog.selectedFiles.length + " selected"
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font.pixelSize: 12
                font.family: "Segoe UI"
                Layout.fillWidth: true
            }
            AppButton {
                width: 100
                text: "Cancel"
                bgColor: theme.surfaceAlt
                textColor: theme.textPrimary
                onClicked: catDialog.close()
            }
            AppButton {
                width: 120
                text: "✓  Confirm"
                bgColor: theme.green
                enabled: catDialog.selectedFiles.length > 0
                onClicked: {
                    catDialog.confirmed(catDialog.selectedFiles)
                    catDialog.close()
                }
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutBack }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130 }
    }
}
