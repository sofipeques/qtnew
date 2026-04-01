import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    ListModel { id: copyLogModel }
    function classifyCopyLogKind(msg) {
        var lower = (msg || "").toLowerCase()
        if (lower.indexOf("[err]") >= 0)                            return "error"
        if (lower.indexOf("clipboard stopped.") >= 0)               return "error"
        if (lower.indexOf("not allowed:") >= 0)                     return "error"
        if (lower.indexOf("auto-categorize completed.") >= 0)       return "completed"
        if (lower.indexOf("clipboard paused.") >= 0 ||
            lower.indexOf("skipped duplicate:") >= 0)               return "paused"
        if (lower.indexOf("clipboard started.") >= 0 ||
            lower.indexOf("clipboard resumed.") >= 0 ||
            lower.indexOf("captured url:") >= 0)                    return "started"
        return ""
    }
    function addLog(msg, kind) {
        copyLogModel.append({
            modelData: "[" + Qt.formatTime(new Date(),"HH:mm:ss") + "] " + msg,
            kind: kind || classifyCopyLogKind(msg)
        })
    }

    Connections {
        target: clipMonitor
        function onLogMessage(msg)  { addLog(msg) }
        function onUrlCaptured(url) { }
    }

    Connections {
        target: notepadMgr
        function onLogMessage(msg) {
            if (!msg || msg.toLowerCase().indexOf("categorizacion completada.") >= 0 ||
                    msg.toLowerCase().indexOf("uncategorized.txt quedo vacio") >= 0)
                return
            addLog(msg)
        }
    }

    function formatTime(secs) {
        var m = Math.floor(secs/60).toString().padStart(2,"0")
        var s = (secs%60).toString().padStart(2,"0")
        return m + ":" + s
    }

    Component {
        id: clipboardActivateAction

        AppButton {
            width: 120
            height: 42
            text: "ACTIVATE"
            bgColor: theme.green
            hoverColor: "#00A870"
            enabled: !clipMonitor.active
            onClicked: {
                var outPath = appConfig.notepadPath + "/uncategorized.txt"
                clipMonitor.start(outPath, appConfig.allowedUrls)
            }
        }
    }

    Component {
        id: clipboardRunningActions

        RowLayout {
            spacing: 8

            AppButton {
                width: 106
                height: 42
                text: clipMonitor.paused ? "RESUME" : "PAUSE"
                bgColor: clipMonitor.paused ? theme.green : theme.orange
                hoverColor: clipMonitor.paused ? "#00A870" : "#CC7000"
                enabled: clipMonitor.active
                onClicked: clipMonitor.paused ? clipMonitor.resume() : clipMonitor.pause()
            }

            AppButton {
                width: 92
                height: 42
                text: "STOP"
                bgColor: theme.red
                hoverColor: "#CC2040"
                enabled: clipMonitor.active
                onClicked: {
                    clipMonitor.stop()
                    if (appConfig.autoCategorize) {
                        var result = notepadMgr.categorizeUncategorized()
                        if (result.moved > 0 || result.processed > 0)
                            addLog("Auto-categorize completed. Moved " + result.moved + " URLs.", "completed")
                    }
                    notepadMgr.refresh()
                }
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // ── Status banner ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 72; radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 48; height: 48; radius: 24
                    color: !clipMonitor.active ? theme.surfaceAlt
                         : clipMonitor.paused ? Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.15)
                         : Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.15)
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: clipMonitor.active ? (clipMonitor.paused ? "⏸" : "🔴") : "📋"
                        font.pixelSize: 22
                        SequentialAnimation on opacity {
                            running: clipMonitor.active && !clipMonitor.paused; loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    Text {
                        text: !clipMonitor.active ? "Ready" : (clipMonitor.paused ? "Paused" : "Monitoring clipboard")
                        color: clipMonitor.active ? (clipMonitor.paused ? theme.orange : theme.green) : theme.textMuted
                        font.pixelSize: 14; font.bold: true; font.family: "Segoe UI"
                    }
                    Text {
                        text: clipMonitor.active
                              ? formatTime(clipMonitor.elapsedSeconds) + "  ·  " + clipMonitor.urlCount + " URLs captured"
                              : "Press ACTIVATE to start capturing"
                        color: theme.textSecondary
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 12; font.family: "Segoe UI"
                    }
                }

                Item { Layout.fillWidth: true }

                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    active: true
                    sourceComponent: clipMonitor.active ? clipboardRunningActions : clipboardActivateAction
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 196
                    height: 42
                    radius: 8
                    color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    border.color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.22)
                    border.width: 1
                    opacity: clipMonitor.active ? 0.5 : 1.0
                    enabled: !clipMonitor.active

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6

                        Column {
                            spacing: 0
                            width: 114

                            Text {
                                text: "AUTO-CATEGORIZE"
                                color: theme.textPrimary
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 10; font.bold: true; font.family: "Segoe UI"
                            }

                            Text {
                                text: "Split URLs on stop"
                                color: theme.textMuted
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 8; font.family: "Segoe UI"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        ToggleSwitch {
                            checked: appConfig.autoCategorize
                            enabled: !clipMonitor.active
                            labelOn: "ON"; labelOff: "OFF"
                            onToggled: appConfig.autoCategorize = !appConfig.autoCategorize
                        }
                    }
                }
            }
        }

        // ── Clipboard Log ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            clip: true

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                // Log header
                Rectangle {
                    id: logHeader
                    Layout.fillWidth: true
                    height: 38; radius: 10
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: theme.border
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: clipMonitor.active ? theme.green : theme.textMuted
                            SequentialAnimation on opacity {
                                running: clipMonitor.active && !clipMonitor.paused; loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }

                        Text {
                            text: "Clipboard Log"
                            color: theme.textSecondary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 11; font.bold: true; font.family: "Segoe UI"
                        }

                        Rectangle {
                            height: 20; radius: 10; width: countBadge.implicitWidth + 12
                            color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            Text {
                                id: countBadge; anchors.centerIn: parent
                                text: copyLogModel.count + " entries"
                                color: theme.accent; font.pixelSize: 10; font.family: "Segoe UI"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: clipMonitor.urlCount > 0
                            height: 20; radius: 10; width: urlBadge.implicitWidth + 12
                            color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.12)
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            Text {
                                id: urlBadge; anchors.centerIn: parent
                                text: "🔗 " + clipMonitor.urlCount + " URLs"
                                color: theme.green; font.pixelSize: 10; font.family: "Segoe UI"
                            }
                        }

                        AppButton {
                            width: 72; height: 24; text: "📂 Open"
                            bgColor: theme.surfaceAlt; textColor: theme.textSecondary; textSize: 10
                            onClicked: Qt.openUrlExternally("file:///" + appConfig.notepadPath)
                        }

                        Rectangle {
                            width: 52; height: 24; radius: 6
                            color: clrHov.containsMouse ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent; text: "✕ Clear"
                                color: clrHov.containsMouse ? theme.red : theme.textMuted
                                font.pixelSize: 10; font.family: "Segoe UI"
                            }
                            MouseArea {
                                id: clrHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: copyLogModel.clear()
                            }
                        }
                    }
                }

                // Empty state
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: copyLogModel.count === 0

                    Column {
                        anchors.centerIn: parent; spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: clipMonitor.active ? "🎧" : "📋"
                            font.pixelSize: 52
                            SequentialAnimation on opacity {
                                running: clipMonitor.active; loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: clipMonitor.active
                                  ? "Monitoring clipboard...\nCopy a TSR URL to capture it here."
                                  : "No log entries yet.\nActivate Clipboard to start capturing URLs."
                            color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 13; font.family: "Segoe UI"
                            horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5
                        }
                    }
                }

                // Log list
                ListView {
                    id: copyLogList
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 6
                    visible: copyLogModel.count > 0
                    clip: true; spacing: 1; model: copyLogModel
                    onCountChanged: positionViewAtEnd()

                    delegate: Rectangle {
                        required property string modelData
                        required property string kind
                        required property int index
                        width: copyLogList.width
                        height: logText.implicitHeight + 8
                        radius: 4
                        color: index % 2 === 0 ? "transparent" : Qt.rgba(0,0,0,0.04)

                        Row {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                            spacing: 8

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: kind === "completed" ? theme.green
                                     : kind === "started"   ? theme.blue
                                     : kind === "paused"    ? theme.orange
                                     : kind === "error"     ? theme.red
                                     : theme.textMuted
                            }

                            Text {
                                id: logText
                                width: parent.width - 14
                                text: modelData
                                color: kind === "completed" ? theme.green
                                     : kind === "started"   ? theme.blue
                                     : kind === "paused"    ? theme.orange
                                     : kind === "error"     ? theme.red
                                     : theme.textSecondary
                                font.pixelSize: 11; font.family: "Consolas"
                                wrapMode: Text.WrapAnywhere
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle { radius: 3; color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            opacity: 0.4 }
                    }
                }

                // Bottom status bar
                Rectangle {
                    Layout.fillWidth: true; height: 32
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: theme.border
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 16

                        Row {
                            spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter
                                color: clipMonitor.active ? theme.green : theme.textMuted }
                            Text {
                                text: clipMonitor.active
                                      ? (clipMonitor.paused ? "Paused · " : "Active · ") + formatTime(clipMonitor.elapsedSeconds)
                                      : "Stopped"
                                color: clipMonitor.active ? (clipMonitor.paused ? theme.orange : theme.green) : theme.textMuted
                                font.pixelSize: 11; font.family: "Segoe UI"; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: clipMonitor.urlCount + " URLs captured"
                            color: clipMonitor.urlCount > 0 ? theme.accent : theme.textMuted
                            font.pixelSize: 11; font.family: "Segoe UI"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Output → " + appConfig.notepadPath.split(/[\\/]/).slice(-2).join("/") + "/uncategorized.txt"
                            color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 10; font.family: "Consolas"
                            elide: Text.ElideLeft
                        }
                    }
                }
            }
        }
    }
}
