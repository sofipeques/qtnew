import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string subtext: ""
    property bool active: false
    property bool hovered: false
    property bool collapsed: false
    readonly property bool isHomeItem: root.label === "Inicio"
    readonly property bool isDownloadsItem: root.label === "Downloads"
    readonly property bool isDuplicatesItem: root.label === "Duplicates"
    readonly property bool isClipboardItem: root.label === "Clipboard"
    readonly property bool isNotepadsItem: root.label === "Notepads"
    readonly property bool useCustomIcon: root.isHomeItem || root.isDownloadsItem || root.isDuplicatesItem || root.isClipboardItem || root.isNotepadsItem
    readonly property color customIconColor: theme.dark
                                             ? Qt.rgba(1, 1, 1, 0.82)
                                             : Qt.rgba(0, 0, 0, 0.72)
    readonly property color softenedGreen: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.88)
    readonly property color softenedOrange: Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.88)
    readonly property color indicatorYellow: "#F5C542"
    readonly property bool systemActive: processRunner.running || processRunner.clipboardRunning || clipMonitor.active || root.duplicatesLongScanVisible
    readonly property bool homeActiveAccent: root.isHomeItem && root.active && root.systemActive
    readonly property bool homeIconActive: root.isHomeItem && root.systemActive
    readonly property bool downloadsRunAccent: root.isDownloadsItem && root.active && processRunner.running && !processRunner.paused
    readonly property bool downloadsPausedAccent: root.isDownloadsItem && root.active && processRunner.running && processRunner.paused
    readonly property bool downloadsClipAccent: root.isDownloadsItem && root.active && processRunner.clipboardRunning
    readonly property bool downloadsPausedIcon: root.isDownloadsItem && processRunner.running && processRunner.paused
    readonly property bool downloadsRunIcon: root.isDownloadsItem && processRunner.running
    readonly property bool downloadsClipIcon: root.isDownloadsItem && processRunner.clipboardRunning
    property bool downloadsErrorPending: false
    property bool downloadsFinishedPending: false
    property bool downloadsRunWasActive: false
    readonly property bool downloadsIndicatorVisible: root.isDownloadsItem && !root.active &&
                                                     (processRunner.running || processRunner.clipboardRunning ||
                                                      root.downloadsErrorPending || root.downloadsFinishedPending)
    readonly property color downloadsBottomIndicatorColor: processRunner.running
                                                          ? (processRunner.paused ? theme.orange : theme.green)
                                                          : (processRunner.clipboardRunning
                                                             ? theme.orange
                                                             : theme.blue)
    readonly property var downloadsIndicatorColors: {
        var colors = []
        if (root.downloadsErrorPending)
            colors.push(theme.red)
        if (processRunner.running || processRunner.clipboardRunning || root.downloadsFinishedPending)
            colors.push(root.downloadsBottomIndicatorColor)
        return colors
    }
    property bool duplicatesLongScanVisible: false
    property bool duplicatesErrorPending: false
    property bool duplicatesWarningPending: false
    property bool duplicatesFinishedPending: false
    property bool duplicatesRunWasVisible: false
    readonly property bool duplicatesActiveAccent: root.isDuplicatesItem && root.active && root.duplicatesLongScanVisible && !dupScanner.paused
    readonly property bool duplicatesPausedAccent: root.isDuplicatesItem && root.active && dupScanner.scanning && dupScanner.paused
    readonly property bool duplicatesPausedIcon: root.isDuplicatesItem && dupScanner.scanning && dupScanner.paused
    readonly property bool duplicatesIconActive: root.isDuplicatesItem && root.duplicatesLongScanVisible
    readonly property bool duplicatesIndicatorVisible: root.isDuplicatesItem && !root.active &&
                                                      (root.duplicatesLongScanVisible ||
                                                       root.duplicatesErrorPending ||
                                                       root.duplicatesWarningPending ||
                                                       root.duplicatesFinishedPending)
    readonly property color duplicatesBottomIndicatorColor: root.duplicatesLongScanVisible
                                                           ? (dupScanner.paused ? theme.orange : theme.green)
                                                           : theme.blue
    readonly property var duplicatesIndicatorColors: {
        var colors = []
        if (root.duplicatesErrorPending)
            colors.push(theme.red)
        if (root.duplicatesWarningPending)
            colors.push(root.indicatorYellow)
        if (root.duplicatesLongScanVisible || root.duplicatesFinishedPending)
            colors.push(root.duplicatesBottomIndicatorColor)
        return colors
    }
    readonly property bool clipboardActiveAccent: root.isClipboardItem && root.active && clipMonitor.active && !clipMonitor.paused
    readonly property bool clipboardPausedAccent: root.isClipboardItem && root.active && clipMonitor.active && clipMonitor.paused
    readonly property bool clipboardPausedIcon: root.isClipboardItem && clipMonitor.active && clipMonitor.paused
    readonly property bool clipboardIconActive: root.isClipboardItem && clipMonitor.active
    property bool clipboardErrorPending: false
    property bool clipboardWarningPending: false
    property bool clipboardFinishedPending: false
    property bool clipboardRunWasActive: false
    readonly property bool clipboardIndicatorVisible: root.isClipboardItem && !root.active &&
                                                     (clipMonitor.active ||
                                                      root.clipboardErrorPending ||
                                                      root.clipboardWarningPending ||
                                                      root.clipboardFinishedPending)
    readonly property color clipboardBottomIndicatorColor: clipMonitor.active
                                                          ? (clipMonitor.paused ? theme.orange : theme.green)
                                                          : theme.blue
    readonly property var clipboardIndicatorColors: {
        var colors = []
        if (root.clipboardErrorPending)
            colors.push(theme.red)
        if (root.clipboardWarningPending)
            colors.push(root.indicatorYellow)
        if (clipMonitor.active || root.clipboardFinishedPending)
            colors.push(root.clipboardBottomIndicatorColor)
        return colors
    }
    readonly property bool navIndicatorVisible: root.downloadsIndicatorVisible || root.duplicatesIndicatorVisible || root.clipboardIndicatorVisible
    readonly property var navIndicatorColors: root.downloadsIndicatorVisible
                                             ? root.downloadsIndicatorColors
                                             : (root.duplicatesIndicatorVisible
                                                ? root.duplicatesIndicatorColors
                                                : (root.clipboardIndicatorVisible ? root.clipboardIndicatorColors : []))
    property real indicatorX: root.collapsed ? 6 : 12
    property real contentLeftMargin: 20 + (!root.collapsed && root.navIndicatorVisible ? 8 : 0)
    readonly property real contentRailWidth: 208
    readonly property color activeAccentColor: root.homeActiveAccent
                                               ? theme.green
                                               : (root.downloadsRunAccent
                                                  ? theme.green
                                                  : (root.downloadsPausedAccent
                                                     ? theme.orange
                                                     : (root.downloadsClipAccent
                                                        ? theme.orange
                                                        : (root.duplicatesActiveAccent
                                                           ? theme.green
                                                           : (root.duplicatesPausedAccent
                                                              ? theme.orange
                                                              : (root.clipboardActiveAccent
                                                                 ? theme.green
                                                                 : (root.clipboardPausedAccent ? theme.orange : theme.accent)))))))
    signal clicked()
    signal hoverStateChanged(bool hoveredNow)

    Connections {
        target: dupScanner
        function onScanningChanged() {
            if (root.isDuplicatesItem) {
                if (dupScanner.scanning) {
                    root.duplicatesRunWasVisible = true
                    root.duplicatesFinishedPending = false
                } else if (root.duplicatesRunWasVisible) {
                    if (!root.active) {
                        if (dupScanner.groups.length > 0)
                            root.duplicatesWarningPending = true
                        else if (!root.duplicatesErrorPending)
                            root.duplicatesFinishedPending = true
                    }
                    root.duplicatesRunWasVisible = false
                }
            }
            if (dupScanner.scanning) {
                hideDupTimer.stop()
                showDupTimer.restart()
            } else {
                showDupTimer.stop()
                if (root.duplicatesLongScanVisible) hideDupTimer.restart()
                else root.duplicatesLongScanVisible = false
            }
        }
        function onLogMessage(msg) {
            if (!root.isDuplicatesItem || root.active)
                return
            var lower = (msg || "").toLowerCase()
            if (lower.indexOf("[err]") >= 0 || lower.indexOf("could not delete") >= 0)
                root.duplicatesErrorPending = true
        }
    }

    Connections {
        target: processRunner
        function onLogLine(line, isError) {
            if (root.isDownloadsItem && isError && !root.active)
                root.downloadsErrorPending = true
        }
        function onClipboardLogLine(line, isError) {
            if (root.isDownloadsItem && isError && !root.active)
                root.downloadsErrorPending = true
        }
        function onRunningChanged() {
            if (!root.isDownloadsItem)
                return
            if (processRunner.running) {
                root.downloadsRunWasActive = true
                root.downloadsFinishedPending = false
                return
            }
            if (root.downloadsRunWasActive) {
                if (processRunner.finished && !root.active)
                    root.downloadsFinishedPending = true
                root.downloadsRunWasActive = false
            }
        }
    }

    Connections {
        target: clipMonitor
        function onLogMessage(msg) {
            if (!root.isClipboardItem || root.active)
                return
            var lower = (msg || "").toLowerCase()
            if (lower.indexOf("[err]") >= 0)
                root.clipboardErrorPending = true
            else if (lower.indexOf("not allowed:") >= 0 || lower.indexOf("skipped duplicate:") >= 0)
                root.clipboardWarningPending = true
        }
        function onActiveChanged() {
            if (!root.isClipboardItem)
                return
            if (clipMonitor.active) {
                root.clipboardRunWasActive = true
                root.clipboardFinishedPending = false
            } else {
                root.clipboardRunWasActive = false
            }
        }
    }

    Connections {
        target: notepadMgr
        function onLogMessage(msg) {
            if (!root.isClipboardItem || root.active)
                return
            var lower = (msg || "").toLowerCase()
            if (lower.indexOf("[err] auto-categorize failed") >= 0)
                root.clipboardErrorPending = true
            else if (lower.indexOf("categorizacion completada.") >= 0)
                root.clipboardFinishedPending = true
        }
    }

    onActiveChanged: {
        if (root.isDownloadsItem && root.active) {
            root.downloadsErrorPending = false
            root.downloadsFinishedPending = false
        }
        if (root.isDuplicatesItem && root.active) {
            root.duplicatesErrorPending = false
            root.duplicatesWarningPending = false
            root.duplicatesFinishedPending = false
        }
        if (root.isClipboardItem && root.active) {
            root.clipboardErrorPending = false
            root.clipboardWarningPending = false
            root.clipboardFinishedPending = false
        }
    }

    Timer {
        id: showDupTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (dupScanner.scanning)
                root.duplicatesLongScanVisible = true
        }
    }

    Timer {
        id: hideDupTimer
        interval: 650
        repeat: false
        onTriggered: root.duplicatesLongScanVisible = false
    }

    color: "transparent"
    clip: true

    // Active indicator bar (left edge)
    Rectangle {
        anchors {
            left: parent.left
            leftMargin: 0
            top: parent.top
            bottom: parent.bottom
        }
        width: 3
        radius: 2
        color: root.activeAccentColor
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // Hover/active background
    Rectangle {
        id: bg
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 6
            topMargin: 2
            bottomMargin: 2
        }
        radius: 8
        color: root.active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : theme.surfaceAlt
        opacity: root.active ? 1.0 : (root.hovered ? 1.0 : 0.0)
        Behavior on opacity { NumberAnimation { duration: root.hovered ? 120 : 0; easing.type: Easing.OutCubic } }
    }

    Item {
        x: root.indicatorX
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 36
        visible: root.navIndicatorVisible || opacity > 0
        opacity: root.navIndicatorVisible ? 1 : 0
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

        Column {
            anchors.centerIn: parent
            spacing: navRepeater.count === 1 ? 0 : 4

            Repeater {
                id: navRepeater
                model: root.navIndicatorColors

                delegate: Rectangle {
                    required property color modelData
                    width: 6
                    height: 6
                    radius: 3
                    color: modelData
                    opacity: 0.78

                    SequentialAnimation on opacity {
                        running: root.navIndicatorVisible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.28; duration: 900; easing.type: Easing.InOutCubic }
                        NumberAnimation { to: 0.92; duration: 900; easing.type: Easing.InOutCubic }
                    }
                }
            }
        }
    }

    Item {
        id: contentRail
        x: root.contentLeftMargin
        width: root.contentRailWidth
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

        // Icon circle
        Rectangle {
            x: 0
            y: Math.round((parent.height - height) / 2)
            width: 36; height: 36; radius: 10
            color: theme.surfaceAlt
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                opacity: root.active ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: root.active ? 180 : 120; easing.type: Easing.InOutCubic } }
            }

            Canvas {
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: root.useCustomIcon
                property color strokeColor: root.homeIconActive
                                           ? root.softenedGreen
                                           : (root.downloadsPausedIcon
                                              ? root.softenedOrange
                                              : (root.downloadsRunIcon
                                              ? root.softenedGreen
                                              : (root.downloadsClipIcon
                                                 ? root.softenedOrange
                                                 : (root.duplicatesPausedIcon
                                                    ? root.softenedOrange
                                                    : (root.duplicatesIconActive
                                                    ? root.softenedGreen
                                                    : (root.clipboardPausedIcon
                                                       ? root.softenedOrange
                                                       : (root.clipboardIconActive ? root.softenedGreen : root.customIconColor)))))))
                onStrokeColorChanged: requestPaint()
                opacity: (root.homeIconActive || root.downloadsRunIcon || root.downloadsClipIcon || root.duplicatesIconActive || root.clipboardIconActive || root.downloadsPausedIcon || root.duplicatesPausedIcon || root.clipboardPausedIcon) ? 0.68 : 0.94
                Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                SequentialAnimation on opacity {
                    running: root.homeIconActive || root.downloadsRunIcon || root.downloadsClipIcon || root.duplicatesIconActive || root.clipboardIconActive || root.downloadsPausedIcon || root.duplicatesPausedIcon || root.clipboardPausedIcon
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.56; duration: 900; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: 0.82; duration: 900; easing.type: Easing.InOutCubic }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 2.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = strokeColor

                    if (root.isHomeItem) {
                        ctx.beginPath()
                        ctx.moveTo(width * 0.08, height * 0.42)
                        ctx.lineTo(width * 0.50, height * 0.10)
                        ctx.lineTo(width * 0.92, height * 0.42)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.23, height * 0.47)
                        ctx.lineTo(width * 0.23, height * 0.86)
                        ctx.lineTo(width * 0.42, height * 0.86)
                        ctx.lineTo(width * 0.42, height * 0.63)
                        ctx.arc(width * 0.50, height * 0.63, width * 0.08, Math.PI, 0, false)
                        ctx.lineTo(width * 0.58, height * 0.86)
                        ctx.lineTo(width * 0.77, height * 0.86)
                        ctx.lineTo(width * 0.77, height * 0.47)
                        ctx.stroke()
                    } else if (root.isDownloadsItem) {
                        ctx.beginPath()
                        ctx.moveTo(width * 0.50, height * 0.14)
                        ctx.lineTo(width * 0.50, height * 0.58)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.35, height * 0.43)
                        ctx.lineTo(width * 0.50, height * 0.58)
                        ctx.lineTo(width * 0.65, height * 0.43)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.18, height * 0.58)
                        ctx.lineTo(width * 0.18, height * 0.75)
                        ctx.arcTo(width * 0.18, height * 0.88, width * 0.32, height * 0.88, width * 0.14)
                        ctx.lineTo(width * 0.68, height * 0.88)
                        ctx.arcTo(width * 0.82, height * 0.88, width * 0.82, height * 0.75, width * 0.14)
                        ctx.lineTo(width * 0.82, height * 0.58)
                        ctx.stroke()
                    } else if (root.isDuplicatesItem) {
                        ctx.beginPath()
                        ctx.moveTo(width * 0.18, height * 0.30)
                        ctx.lineTo(width * 0.18, height * 0.82)
                        ctx.arcTo(width * 0.18, height * 0.90, width * 0.28, height * 0.90, width * 0.08)
                        ctx.lineTo(width * 0.58, height * 0.90)
                        ctx.arcTo(width * 0.66, height * 0.90, width * 0.66, height * 0.82, width * 0.08)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.34, height * 0.18)
                        ctx.lineTo(width * 0.62, height * 0.18)
                        ctx.lineTo(width * 0.78, height * 0.34)
                        ctx.lineTo(width * 0.78, height * 0.74)
                        ctx.arcTo(width * 0.78, height * 0.82, width * 0.70, height * 0.82, width * 0.08)
                        ctx.lineTo(width * 0.42, height * 0.82)
                        ctx.arcTo(width * 0.34, height * 0.82, width * 0.34, height * 0.74, width * 0.08)
                        ctx.lineTo(width * 0.34, height * 0.26)
                        ctx.arcTo(width * 0.34, height * 0.18, width * 0.42, height * 0.18, width * 0.08)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.62, height * 0.18)
                        ctx.lineTo(width * 0.62, height * 0.34)
                        ctx.lineTo(width * 0.78, height * 0.34)
                        ctx.stroke()
                    } else if (root.isClipboardItem) {
                        ctx.beginPath()
                        ctx.moveTo(width * 0.28, height * 0.20)
                        ctx.lineTo(width * 0.34, height * 0.20)
                        ctx.arc(width * 0.50, height * 0.20, width * 0.08, Math.PI, 0, false)
                        ctx.lineTo(width * 0.72, height * 0.20)
                        ctx.arcTo(width * 0.80, height * 0.20, width * 0.80, height * 0.28, width * 0.08)
                        ctx.lineTo(width * 0.80, height * 0.78)
                        ctx.arcTo(width * 0.80, height * 0.86, width * 0.72, height * 0.86, width * 0.08)
                        ctx.lineTo(width * 0.28, height * 0.86)
                        ctx.arcTo(width * 0.20, height * 0.86, width * 0.20, height * 0.78, width * 0.08)
                        ctx.lineTo(width * 0.20, height * 0.28)
                        ctx.arcTo(width * 0.20, height * 0.20, width * 0.28, height * 0.20, width * 0.08)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.36, height * 0.20)
                        ctx.lineTo(width * 0.36, height * 0.10)
                        ctx.lineTo(width * 0.64, height * 0.10)
                        ctx.lineTo(width * 0.64, height * 0.20)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.30, height * 0.34)
                        ctx.lineTo(width * 0.70, height * 0.34)
                        ctx.moveTo(width * 0.30, height * 0.48)
                        ctx.lineTo(width * 0.70, height * 0.48)
                        ctx.moveTo(width * 0.30, height * 0.62)
                        ctx.lineTo(width * 0.70, height * 0.62)
                        ctx.moveTo(width * 0.30, height * 0.76)
                        ctx.lineTo(width * 0.70, height * 0.76)
                        ctx.stroke()
                    } else if (root.isNotepadsItem) {
                        ctx.beginPath()
                        ctx.moveTo(width * 0.26, height * 0.24)
                        ctx.lineTo(width * 0.74, height * 0.24)
                        ctx.arcTo(width * 0.86, height * 0.24, width * 0.86, height * 0.36, width * 0.10)
                        ctx.lineTo(width * 0.86, height * 0.76)
                        ctx.arcTo(width * 0.86, height * 0.88, width * 0.74, height * 0.88, width * 0.10)
                        ctx.lineTo(width * 0.26, height * 0.88)
                        ctx.arcTo(width * 0.14, height * 0.88, width * 0.14, height * 0.76, width * 0.10)
                        ctx.lineTo(width * 0.14, height * 0.36)
                        ctx.arcTo(width * 0.14, height * 0.24, width * 0.26, height * 0.24, width * 0.10)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.30, height * 0.12)
                        ctx.lineTo(width * 0.30, height * 0.24)
                        ctx.moveTo(width * 0.46, height * 0.12)
                        ctx.lineTo(width * 0.46, height * 0.24)
                        ctx.moveTo(width * 0.62, height * 0.12)
                        ctx.lineTo(width * 0.62, height * 0.24)
                        ctx.moveTo(width * 0.78, height * 0.12)
                        ctx.lineTo(width * 0.78, height * 0.24)
                        ctx.moveTo(width * 0.14, height * 0.36)
                        ctx.lineTo(width * 0.86, height * 0.36)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(width * 0.26, height * 0.50)
                        ctx.lineTo(width * 0.68, height * 0.50)
                        ctx.moveTo(width * 0.26, height * 0.62)
                        ctx.lineTo(width * 0.64, height * 0.62)
                        ctx.moveTo(width * 0.26, height * 0.74)
                        ctx.lineTo(width * 0.52, height * 0.74)
                        ctx.stroke()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.useCustomIcon
                text: root.icon
                font.pixelSize: 18
                color: theme.textPrimary
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            }
        }

        Column {
            x: 50
            y: Math.round((parent.height - implicitHeight) / 2)
            width: 142
            visible: !root.collapsed
            opacity: root.collapsed ? 0 : 1
            spacing: 2
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Text {
                text: root.label
                width: parent.width
                elide: Text.ElideRight
                color: (root.homeActiveAccent || root.downloadsRunAccent || root.downloadsPausedAccent ||
                        root.downloadsClipAccent || root.duplicatesActiveAccent || root.duplicatesPausedAccent ||
                        root.clipboardActiveAccent || root.clipboardPausedAccent)
                       ? root.activeAccentColor
                       : (root.active ? theme.accent : theme.textPrimary)
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 13
                    bold: root.active
                    family: "Segoe UI"
                }
            }
            Text {
                text: root.subtext
                width: parent.width
                elide: Text.ElideRight
                color: theme.textMuted
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                font {
                    pixelSize: 11
                    family: "Segoe UI"
                }
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverStateChanged(true)
        onExited: root.hoverStateChanged(false)
        onClicked: root.clicked()
    }
}
