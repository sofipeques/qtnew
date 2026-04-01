import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: headerRoot
    color: theme.surface
    clip: true
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    readonly property var pageTitles: [
        "Inicio", "Downloads", "Duplicates", "Clipboard", "Notepads"
    ]
    readonly property var pageSubs: [
        "Overview, actions and live system health",
        "Run the downloader and monitor packages in real time",
        "Scan, review and clean duplicate package files",
        "Capture URLs from clipboard and route them to notepads",
        "Browse and manage generated text collections"
    ]

    property int currentTabIndex: 0

    ThemeTransition{
        // <-- 2. REEMPLAZAR anchors.fill: parent POR ESTO:
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            left: parent.left
            leftMargin: -2 // Empuja el borde izquierdo fuera del área visible
        }
        radius: 0
    }
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: theme.border
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 24
            rightMargin: 20
        }
        spacing: 16

        Column {
            spacing: 2

            Text {
                text: headerRoot.pageTitles[headerRoot.currentTabIndex] ?? "Inicio"
                color: theme.textPrimary
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 20
                    bold: true
                    family: "Segoe UI"
                }
            }

            Text {
                text: headerRoot.pageSubs[headerRoot.currentTabIndex] ?? ""
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 12
                    family: "Segoe UI"
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: processRunner.running
            height: 28
            radius: 14
            color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.15)
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            width: runRow.implicitWidth + 24

            RowLayout {
                id: runRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: theme.green
                    SequentialAnimation on opacity {
                        running: processRunner.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: "Running"
                    color: theme.green
                    font {
                        pixelSize: 12
                        bold: true
                        family: "Segoe UI"
                    }
                }
            }
        }

        Rectangle {
            visible: processRunner.clipboardRunning
            height: 28
            radius: 14
            color: Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.15)
            width: clipRunRow.implicitWidth + 24

            RowLayout {
                id: clipRunRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: theme.orange
                    SequentialAnimation on opacity {
                        running: processRunner.clipboardRunning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: "Running"
                    color: theme.orange
                    font {
                        pixelSize: 12
                        bold: true
                        family: "Segoe UI"
                    }
                }
            }
        }

        Rectangle {
            visible: clipMonitor.active
            height: 28
            radius: 14
            color: Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.15)
            width: copyboardRow.implicitWidth + 24

            RowLayout {
                id: copyboardRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: theme.orange
                    SequentialAnimation on opacity {
                        running: clipMonitor.active
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: "Clipboard - " + clipMonitor.urlCount + " URLs"
                    color: theme.orange
                    font {
                        pixelSize: 12
                        bold: true
                        family: "Segoe UI"
                    }
                }
            }
        }

        ToggleSwitch {
            checked: theme.dark
            labelOn: "ON"
            labelOff: "OFF"
            onToggled: theme.toggle()
        }
    }
}
