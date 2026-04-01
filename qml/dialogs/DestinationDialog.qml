import QtQuick
import "../components"
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: destPopup
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 440
    height: 280
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        radius: 14
        color: theme.surface
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        border {
            color: theme.border
            width: 1
        }
        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

        ThemeTransition { anchors.fill: parent; radius: parent.radius }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 52; radius: 14
            color: theme.surfaceAlt
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 8; color: parent.color
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            }
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 1; color: theme.border
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            }
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 20
                    rightMargin: 16
                }
                Text {
                    text: "📁  Download Destination"
                    color: theme.textPrimary
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    font {
                        pixelSize: 16
                        bold: true
                        family: "Segoe UI"
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: dCls.containsMouse ? theme.red : theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent; text: "✕"
                        color: dCls.containsMouse ? "white" : theme.textMuted
                        Behavior on color { ColorAnimation { duration: 120 } }
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: dCls; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: destPopup.close()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 12

            Text {
                text: "Current path:"
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 11
                    family: "Segoe UI"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36; radius: 8
                color: theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border {
                    color: theme.border
                    width: 1
                }
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Text {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    verticalAlignment: Text.AlignVCenter
                    text: appConfig.downloadRootPath
                    color: theme.accent
                    font {
                        pixelSize: 11
                        family: "Consolas"
                    }
                    elide: Text.ElideLeft
                }
            }

            // Manual input
            Rectangle {
                Layout.fillWidth: true
                height: 36; radius: 8
                color: theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border {
                    color: theme.border
                    width: 1
                }
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                TextInput {
                    id: manualInput
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.textPrimary
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    font {
                        pixelSize: 12
                        family: "Consolas"
                    }
                }
                Text {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    verticalAlignment: Text.AlignVCenter
                    text: "Or type path manually..."
                    color: theme.textMuted
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    font {
                        pixelSize: 12
                        family: "Consolas"
                    }
                    visible: manualInput.text.length === 0 && !manualInput.activeFocus
                }
            }

            RowLayout {
                spacing: 8
                AppButton {
                    Layout.fillWidth: true
                    text: "📂  Browse Folder"
                    bgColor: theme.accent
                    onClicked: {
                        var win = root.Window.window
                        if (win) win.openDownloadRootPicker()
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    text: "✍  Apply Manual"
                    bgColor: theme.orange
                    hoverColor: "#CC7000"
                    enabled: manualInput.text.trim() !== ""
                    onClicked: {
                        appConfig.downloadRootPath = manualInput.text.trim()
                        manualInput.text = ""
                        destPopup.close()
                    }
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
