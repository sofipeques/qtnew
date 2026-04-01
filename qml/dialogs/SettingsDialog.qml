import QtQuick
import "../components"
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: settingsPopup
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 480
    height: 500
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
        layer.enabled: true

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
                    text: "⚙  Settings"
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
                    color: closeHov.containsMouse ? theme.red : theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHov.containsMouse ? "white" : theme.textMuted
                        Behavior on color { ColorAnimation { duration: 120 } }
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: closeHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsPopup.close()
                    }
                }
            }
        }

        // Settings list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            padding: 16

            ColumnLayout {
                width: parent.width
                spacing: 4

                function settingRow(icon, title, sub, checked, onChange) {}

                Repeater {
                    model: [
                        { icon: "🌙", title: "Dark Mode",              sub: "Switch between light and dark UI",  prop: "darkMode",          val: theme.dark },
                        { icon: "🔊", title: "Sound on Finish",        sub: "Beep when download batch completes", prop: "soundOnFinish",     val: appConfig.soundOnFinish },
                        { icon: "📌", title: "Always on Top",          sub: "Keep window above all others",       prop: "alwaysOnTop",       val: appConfig.alwaysOnTop },
                        { icon: "💬", title: "Popup on Finish",        sub: "Show dialog when process ends",      prop: "popupOnFinish",     val: appConfig.popupOnFinish },
                        { icon: "🔍", title: "Auto-Scan Duplicates",   sub: "Scan for duplicates after download", prop: "autoScanDuplicates",val: appConfig.autoScanDuplicates },
                        { icon: "🗂", title: "Auto-Categorize URLs",   sub: "Auto-sort URLs by category on stop", prop: "autoCategorize",    val: appConfig.autoCategorize },
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 60; radius: 10
                        color: rowHov.containsMouse ? theme.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border {
                            color: theme.border
                            width: 1
                        }
                        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                        ThemeTransition { anchors.fill: parent; radius: parent.radius }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 16
                                rightMargin: 16
                            }
                            spacing: 12

                            Rectangle {
                                width: 36; height: 36; radius: 8
                                color: theme.surfaceAlt
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 18
                                }
                            }

                            Column {
                                spacing: 2
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.title
                                    color: theme.textPrimary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font {
                                        pixelSize: 13
                                        bold: true
                                        family: "Segoe UI"
                                    }
                                }
                                Text {
                                    text: modelData.sub
                                    color: theme.textMuted
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font {
                                        pixelSize: 11
                                        family: "Segoe UI"
                                    }
                                }
                            }

                            ToggleSwitch {
                                checked: modelData.val
                                onToggled: {
                                    let p = modelData.prop
                                    if      (p === "darkMode")          theme.toggle()
                                    else if (p === "soundOnFinish")     appConfig.soundOnFinish     = !appConfig.soundOnFinish
                                    else if (p === "alwaysOnTop")       appConfig.alwaysOnTop       = !appConfig.alwaysOnTop
                                    else if (p === "popupOnFinish")     appConfig.popupOnFinish     = !appConfig.popupOnFinish
                                    else if (p === "autoScanDuplicates")appConfig.autoScanDuplicates= !appConfig.autoScanDuplicates
                                    else if (p === "autoCategorize")    appConfig.autoCategorize    = !appConfig.autoCategorize
                                }
                            }
                        }

                        MouseArea {
                            id: rowHov
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                            onClicked: mouse.accepted = false
                        }
                    }
                }

                // Version info
                Item { height: 12 }
                Rectangle {
                    Layout.fillWidth: true
                    height: 44; radius: 10
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    border {
                        color: theme.border
                        width: 1
                    }
                    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                    ThemeTransition { anchors.fill: parent; radius: parent.radius }

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 14
                        }
                        Text {
                            text: "📦 TRS4 Sims Orchestrator"
                            color: theme.textSecondary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font {
                                pixelSize: 12
                                family: "Segoe UI"
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "v1.0.0 Qt6 Edition"
                            color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font {
                                pixelSize: 11
                                family: "Consolas"
                            }
                        }
                    }
                }
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        NumberAnimation { property: "scale";  from: 0.92; to: 1; duration: 200; easing.type: Easing.OutBack }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
        NumberAnimation { property: "scale";  from: 1; to: 0.95; duration: 150 }
    }
}
