import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    property var checkedPaths: []
    property bool scanLogExpanded: false
    property string viewingScanLog: ""
    property var scanGroupLogs: ({})
    property var deletedGroupKeys: []
    property bool scanProgressVisible: false
    property bool scanBannerShownOnce: false
    readonly property int headerControlHeight: 42

    ListModel { id: dupLogModel }
    function classifyDuplicateLogKind(msg) {
        var lower = (msg || "").toLowerCase()
        if (lower.indexOf("could not delete:") >= 0)               return "error"
        if (lower.indexOf("no duplicate groups found.") >= 0 ||
            lower.indexOf("deleted:") >= 0 ||
            lower.indexOf("scan complete.") >= 0)                  return "completed"
        if (lower.indexOf("duplicate groups found.") >= 0)         return "warning"
        if (lower.indexOf("scanning:") >= 0 ||
            lower.indexOf("found ") >= 0)                          return "started"
        return ""
    }
    function addLog(msg) {
        dupLogModel.append({
            modelData: "[" + Qt.formatTime(new Date(),"HH:mm:ss") + "] " + msg,
            kind: classifyDuplicateLogKind(msg)
        })
    }
    function ensureScanGroupModel(key) {
        if (!root.scanGroupLogs[key]) {
            var m = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', root)
            var copy = root.scanGroupLogs
            copy[key] = m
            root.scanGroupLogs = copy
        }
        return root.scanGroupLogs[key]
    }
    function scanLogGroupKeys() { return root.deletedGroupKeys.slice() }
    function appendDeletedLogs(paths) {
        for (var i = 0; i < dupScanner.groups.length; i++) {
            var group = dupScanner.groups[i]
            var key = "G" + group.id
            for (var j = 0; j < group.files.length; j++) {
                var file = group.files[j]
                if (paths.indexOf(file.path) < 0) continue
                var model = ensureScanGroupModel(key)
                model.append({
                    modelData: "[" + Qt.formatTime(new Date(), "HH:mm:ss") + "] Deleted: " + file.name + " (" + file.folder + ")",
                    kind: "completed"
                })
                if (root.deletedGroupKeys.indexOf(key) < 0) {
                    var keys = root.deletedGroupKeys.slice()
                    keys.push(key); keys.sort()
                    root.deletedGroupKeys = keys
                }
            }
        }
    }

    Connections {
        target: dupScanner
        function onLogMessage(msg)  { addLog(msg) }
        function onGroupsChanged()  { root.checkedPaths = [] }
        function onScanningChanged() {
            if (dupScanner.scanning) {
                hideScanBannerTimer.stop()
                scanBannerShownOnce = false
                showScanBannerTimer.restart()
            } else {
                showScanBannerTimer.stop()
                if (scanProgressVisible) hideScanBannerTimer.restart()
                else scanProgressVisible = false
            }
        }
    }

    Timer { id: showScanBannerTimer; interval: 220; repeat: false
        onTriggered: { if (dupScanner.scanning) { root.scanProgressVisible = true; root.scanBannerShownOnce = true } }
    }
    Timer { id: hideScanBannerTimer; interval: 650; repeat: false
        onTriggered: root.scanProgressVisible = false
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // ── Scan path bar ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 72; radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            RowLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    Text {
                        text: "SCAN PATH"; color: theme.textMuted
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 10; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1
                    }
                    Text {
                        text: dupScanner.scanPath !== "" ? dupScanner.scanPath : appConfig.downloadRootPath
                        color: theme.accent; font.pixelSize: 11; font.family: "Consolas"
                        elide: Text.ElideLeft
                        Layout.fillWidth: true
                        Layout.maximumWidth: 250
                    }
                }

                Item { Layout.fillWidth: true }

                AppButton {
                    Layout.preferredWidth: 100
                    Layout.alignment: Qt.AlignVCenter
                    height: root.headerControlHeight
                    text: "Change Path"; bgColor: theme.orange; hoverColor: "#CC7000"
                    onClicked: { var win = root.Window.window; if (win) win.openDuplicatePathPicker() }
                }
                AppButton {
                    Layout.preferredWidth: 108
                    Layout.alignment: Qt.AlignVCenter
                    height: root.headerControlHeight
                    text: "Use Default"; bgColor: theme.surfaceAlt; textColor: theme.textPrimary
                    onClicked: dupScanner.scanPath = appConfig.downloadRootPath
                }
                Loader {
                    Layout.preferredWidth: (dupScanner.scanning && root.scanProgressVisible) ? 198 : 154
                    Layout.preferredHeight: root.headerControlHeight
                    Layout.alignment: Qt.AlignVCenter
                    opacity: (dupScanner.scanning && !root.scanProgressVisible) ? 0.92 : 1
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                    sourceComponent: (dupScanner.scanning && root.scanProgressVisible) ? scanRunningActions : scanStartAction
                }

                Rectangle {
                    Layout.preferredWidth: 175
                    Layout.preferredHeight: root.headerControlHeight
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
                    border.width: 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Column {
                            spacing: 1; Layout.fillWidth: true
                            Text { text: "AUTO-SCAN"; color: theme.textPrimary
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 10; font.bold: true; font.family: "Segoe UI" }
                            Text {
                                text: "Run after downloads"; color: theme.textMuted
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 9; font.family: "Segoe UI"
                                elide: Text.ElideRight; width: parent.width
                            }
                        }
                        ToggleSwitch {
                            checked: appConfig.autoScanDuplicates
                            labelOn: "ON"; labelOff: "OFF"
                            onToggled: appConfig.autoScanDuplicates = !appConfig.autoScanDuplicates
                        }
                    }
                }
            }
        }

        // ── Progress banner ───────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.scanProgressVisible ? 48 : 0
            Layout.maximumHeight: Layout.preferredHeight
            opacity: root.scanProgressVisible ? 1 : 0
            clip: true
            visible: Layout.preferredHeight > 0 || opacity > 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: theme.surface
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.color: theme.border; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                ThemeTransition { anchors.fill: parent; radius: parent.radius }

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 4

                    RowLayout {
                        Text {
                            text: dupScanner.progressText; color: theme.textSecondary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 11; font.family: "Segoe UI"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(dupScanner.progress * 100) + "%"
                            color: dupScanner.scanning ? theme.blue : theme.green
                            font.pixelSize: 11; font.bold: true; font.family: "Consolas"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3
                        color: theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        Rectangle {
                            id: progressFill
                            height: parent.height; radius: parent.radius
                            color: dupScanner.scanning ? theme.blue : theme.green
                            width: parent.width * dupScanner.progress
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Rectangle {
                                visible: dupScanner.scanning && dupScanner.progress > 0 && dupScanner.progress < 1
                                anchors { top: parent.top; bottom: parent.bottom }
                                width: 80; radius: parent.radius; x: -width
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.3) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                                SequentialAnimation on x {
                                    running: parent.visible; loops: Animation.Infinite
                                    NumberAnimation { to: progressFill.width + 80; duration: 1200; easing.type: Easing.InOutSine }
                                    PauseAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Main content: log + groups ────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

            // Scan log panel
            Rectangle {
                Layout.preferredWidth: 300; Layout.fillHeight: true
                radius: 8
                color: theme.bg
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.color: theme.border; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                clip: true

                ThemeTransition { anchors.fill: parent; radius: parent.radius }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32; radius: 8
                        color: theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1; color: theme.border
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10

                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: scanArrowHover.containsMouse ? theme.surface : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: root.scanLogExpanded ? "^" : "v"
                                    color: theme.textMuted
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: scanArrowHover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.scanLogExpanded = !root.scanLogExpanded
                                }
                            }

                            Text {
                                text: root.viewingScanLog === "" ? "Scan Log" : root.viewingScanLog
                                color: theme.textSecondary
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 11; font.family: "Segoe UI"; font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Clear"; color: theme.textMuted
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 10; font.family: "Segoe UI"
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.viewingScanLog === "") dupLogModel.clear()
                                        else if (root.scanGroupLogs[root.viewingScanLog]) root.scanGroupLogs[root.viewingScanLog].clear()
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.scanLogExpanded ? scanLogFlow.implicitHeight + 12 : 0
                        Layout.maximumHeight: Layout.preferredHeight
                        opacity: root.scanLogExpanded ? 1 : 0
                        clip: true
                        visible: height > 0 || opacity > 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        Flow {
                            id: scanLogFlow
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                            spacing: 6

                            Rectangle {
                                height: 24; radius: 6; width: scanGlobalText.implicitWidth + 14
                                color: root.viewingScanLog === "" ? theme.accent : theme.surface
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: root.viewingScanLog === "" ? theme.accent : theme.border
                                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.width: 1
                                Text {
                                    id: scanGlobalText; anchors.centerIn: parent
                                    text: "Global"
                                    color: root.viewingScanLog === "" ? "white" : theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 10; font.family: "Segoe UI"
                                }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.viewingScanLog = ""
                                }
                            }

                            Repeater {
                                model: scanLogGroupKeys()
                                delegate: Rectangle {
                                    required property string modelData
                                    height: 24; radius: 6; width: groupLogText.implicitWidth + 14
                                    color: root.viewingScanLog === modelData ? theme.red : theme.surface
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    border.color: root.viewingScanLog === modelData ? theme.red : theme.border
                                    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    border.width: 1
                                    Text {
                                        id: groupLogText; anchors.centerIn: parent
                                        text: modelData
                                        color: root.viewingScanLog === modelData ? "white" : theme.textSecondary
                                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                        font.pixelSize: 10; font.family: "Segoe UI"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.viewingScanLog = modelData
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 4
                        clip: true; spacing: 1
                        model: root.viewingScanLog === "" ? dupLogModel : (root.scanGroupLogs[root.viewingScanLog] || dupLogModel)
                        onCountChanged: positionViewAtEnd()

                        delegate: Text {
                            required property string modelData
                            required property string kind
                            width: ListView.view.width; leftPadding: 8
                            color: kind === "completed" ? theme.green
                                   : kind === "started" ? theme.blue
                                   : kind === "warning" ? theme.orange
                                   : kind === "error"   ? theme.red
                                   : theme.textSecondary
                            font.pixelSize: 11; font.family: "Consolas"
                            wrapMode: Text.WrapAnywhere
                            text: modelData
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                radius: 3; color: theme.textMuted
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                opacity: 0.5
                            }
                        }
                    }
                }
            }

            // ── Groups panel ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 10
                color: theme.surface
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.color: theme.border; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                clip: true

                ThemeTransition { anchors.fill: parent; radius: parent.radius }

                ColumnLayout {
                    anchors.fill: parent; spacing: 0

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: theme.border
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            Text {
                                text: "Duplicate Groups: " + dupScanner.groups.length
                                color: dupScanner.groups.length > 0 ? theme.red : theme.green
                                font.pixelSize: 12; font.bold: true; font.family: "Segoe UI"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: root.checkedPaths.length > 0
                                text: root.checkedPaths.length + " selected for deletion"
                                color: theme.red; font.pixelSize: 11; font.family: "Segoe UI"
                            }
                            AppButton {
                                width: 180; height: 24
                                text: "Delete Selected (" + root.checkedPaths.length + ")"
                                bgColor: theme.red; hoverColor: "#CC2040"; enabled: root.checkedPaths.length > 0
                                textSize: 10
                                onClicked: {
                                    appendDeletedLogs(root.checkedPaths)
                                    dupScanner.deleteFiles(root.checkedPaths)
                                    root.checkedPaths = []
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: dupScanner.groups.length === 0
                        Column {
                            anchors.centerIn: parent; spacing: 12
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dupScanner.scanning ? "..." : "OK"
                                color: theme.dark ? "white" : theme.textPrimary
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 52
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dupScanner.scanning ? "Scanning files..." : "No duplicates found.\nPress 'Scan for Duplicates' to begin."
                                color: theme.textMuted
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 14; font.family: "Segoe UI"
                                horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                            }
                        }
                    }

                    ListView {
                        id: groupsList
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 10
                        visible: dupScanner.groups.length > 0; clip: true; spacing: 10
                        model: dupScanner.groups

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: groupsList.width
                            height: groupColumn.implicitHeight + 20
                            radius: 10
                            color: theme.surfaceAlt
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            border.color: theme.border; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                            ThemeTransition { anchors.fill: parent; radius: parent.radius }

                            Column {
                                id: groupColumn
                                anchors { fill: parent; margins: 10 }
                                spacing: 6

                                Rectangle {
                                    width: parent.width; height: 28; radius: 6
                                    color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.08)
                                    Row {
                                        anchors { fill: parent; leftMargin: 10 }
                                        spacing: 8
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Group " + modelData.id; color: theme.red; font.pixelSize: 12; font.bold: true; font.family: "Segoe UI" }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "· " + modelData.name; color: theme.textSecondary
                                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                            font.pixelSize: 12; font.family: "Segoe UI" }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "(" + modelData.files.length + " copies)"; color: theme.textMuted
                                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                            font.pixelSize: 11; font.family: "Segoe UI" }
                                    }
                                }

                                Repeater {
                                    model: modelData.files
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        property bool isChecked: root.checkedPaths.includes(modelData.path)

                                        width: groupColumn.width; height: 38; radius: 7
                                        color: isChecked
                                               ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.10)
                                               : (rowHov.containsMouse ? theme.surfaceAlt : theme.surface)
                                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                        border.color: isChecked ? theme.red : theme.border; border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                                            spacing: 10

                                            Rectangle {
                                                width: 20; height: 20; radius: 5
                                                color: isChecked
                                                       ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.85)
                                                       : Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.04)
                                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                                border.color: isChecked ? theme.red : theme.border; border.width: 2
                                                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                                Text { visible: isChecked; anchors.centerIn: parent; text: "X"; color: "white"; font.pixelSize: 12; font.bold: true }
                                            }

                                            Rectangle {
                                                visible: index === 0
                                                width: 58; height: 18; radius: 4
                                                color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.15)
                                                Text { anchors.centerIn: parent; text: "ORIGINAL"; color: theme.green; font.pixelSize: 9; font.bold: true; font.family: "Segoe UI" }
                                            }

                                            Text { text: "PKG " + modelData.name; color: theme.textPrimary
                                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                                font.pixelSize: 11; font.family: "Segoe UI"; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Text { text: "📁 " + modelData.folder; color: theme.textSecondary
                                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                                font.pixelSize: 11; font.family: "Segoe UI" }
                                            Text { text: modelData.sizeKb.toFixed(0) + " KB"; color: theme.textMuted
                                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                                font.pixelSize: 11; font.family: "Consolas" }
                                        }

                                        MouseArea {
                                            id: rowHov; anchors.fill: parent
                                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var arr = root.checkedPaths.slice()
                                                var i = arr.indexOf(modelData.path)
                                                if (i >= 0) arr.splice(i, 1)
                                                else arr.push(modelData.path)
                                                root.checkedPaths = arr
                                            }
                                        }
                                    }
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
                }
            }
        }
    }

    Component {
        id: scanStartAction
        AppButton {
            height: root.headerControlHeight
            text: "Scan for Duplicates"
            bgColor: theme.accent
            onClicked: dupScanner.startScan()
        }
    }

    Component {
        id: scanRunningActions
        RowLayout {
            spacing: 6
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            AppButton {
                Layout.preferredWidth: 96
                Layout.alignment: Qt.AlignVCenter
                height: root.headerControlHeight
                text: dupScanner.paused ? "Resume" : "Pause"
                bgColor: dupScanner.paused ? theme.green : theme.orange
                hoverColor: dupScanner.paused ? "#00A870" : "#CC7000"
                onClicked: {
                    if (dupScanner.paused) dupScanner.resumeScan()
                    else dupScanner.pauseScan()
                }
            }
            AppButton {
                Layout.preferredWidth: 96
                Layout.alignment: Qt.AlignVCenter
                height: root.headerControlHeight
                text: "Stop"
                bgColor: theme.red
                hoverColor: "#CC2040"
                onClicked: dupScanner.stopScan()
            }
        }
    }
}
