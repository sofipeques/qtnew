import QtQuick
import "../components"
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string selectedPath: ""
    property int    selectedIndex: -1

    RowLayout {
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 12

        // ── Left: file list ───────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border {
                color: theme.border
                width: 1
            }
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            clip: true

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 48; radius: 10
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 1; color: theme.border
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    }
                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        Text {
                            text: "📝 Files"
                            color: theme.textSecondary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font { pixelSize: 13; bold: true; family: "Segoe UI" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: notepadMgr.files.length + " files"
                            color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font { pixelSize: 11; family: "Segoe UI" }
                        }
                    }
                }

                ListView {
                    id: filesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 6
                    clip: true
                    spacing: 2
                    model: notepadMgr.files

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: filesList.width
                        height: 36; radius: 8
                        color: root.selectedIndex === index
                               ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                               : (hov3.containsMouse ? theme.surfaceAlt : "transparent")
                        border {
                            color: root.selectedIndex === index ? theme.accent : "transparent"
                            width: 1
                        }
                        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8

                            Text { text: "📄"; font.pixelSize: 14 }

                            Column {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    color: root.selectedIndex === index ? theme.accent : theme.textPrimary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font {
                                        pixelSize: 11
                                        bold: root.selectedIndex === index
                                        family: "Segoe UI"
                                    }
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }

                        MouseArea {
                            id: hov3
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index
                                root.selectedPath  = modelData.path
                                contentArea.text   = notepadMgr.readFile(modelData.path)
                                lineLbl.text = "Lines: " + notepadMgr.lineCount(modelData.path)
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            radius: 3; color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            opacity: 0.4
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1; color: theme.border
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    spacing: 6
                    AppButton {
                        Layout.fillWidth: true
                        height: 30
                        text: "↻ Refresh"
                        bgColor: theme.surfaceAlt
                        textColor: theme.textPrimary
                        textSize: 11
                        onClicked: {
                            notepadMgr.refresh()
                            root.selectedIndex = -1
                            root.selectedPath = ""
                            contentArea.text = ""
                            lineLbl.text = "Lines: --"
                        }
                    }
                    AppButton {
                        Layout.fillWidth: true
                        height: 30
                        text: "📂 Open"
                        bgColor: theme.surfaceAlt
                        textColor: theme.textPrimary
                        textSize: 11
                        onClicked: Qt.openUrlExternally("file:///" + appConfig.notepadPath)
                    }
                }
            }
        }

        // ── Right: content viewer ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border {
                color: theme.border
                width: 1
            }
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            clip: true

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Toolbar
                Rectangle {
                    Layout.fillWidth: true
                    height: 48; radius: 10
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 1; color: theme.border
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 16

                        Text {
                            text: root.selectedPath !== ""
                                  ? ("📄 " + root.selectedPath.split(/[\\/]/).pop())
                                  : "No file selected"
                            color: root.selectedPath !== "" ? theme.textPrimary : theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font { pixelSize: 13; bold: true; family: "Segoe UI" }
                        }

                        Text {
                            id: lineLbl
                            text: "Lines: --"
                            color: theme.accent
                            font { pixelSize: 12; bold: true; family: "Segoe UI" }
                        }

                        Item { Layout.fillWidth: true }

                        AppButton {
                            width: 140; height: 30
                            text: "🗑  Delete Notepad"
                            bgColor: theme.red
                            hoverColor: "#CC2040"
                            textSize: 12
                            enabled: root.selectedPath !== ""
                            onClicked: {
                                if (notepadMgr.deleteFile(root.selectedPath)) {
                                    contentArea.text = ""
                                    lineLbl.text = "Lines: --"
                                    root.selectedPath = ""
                                    root.selectedIndex = -1
                                }
                            }
                        }
                    }
                }

                // Content
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    TextArea {
                        id: contentArea
                        readOnly: true
                        color: theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        background: null
                        font { pixelSize: 12; family: "Consolas" }
                        wrapMode: TextArea.Wrap
                        padding: 14
                        placeholderText: "← Select a .txt file to preview its contents"
                        placeholderTextColor: theme.textMuted
                    }
                }
            }
        }
    }
}
