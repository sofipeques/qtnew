import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    function goToTab(index) {
        var win = root.Window.window
        if (win && win.setCurrentTab) win.setCurrentTab(index)
    }
    function openDownloadsFolder() { Qt.openUrlExternally("file:///" + appConfig.downloadRootPath) }
    function openNotepadsFolder()  { Qt.openUrlExternally("file:///" + appConfig.notepadPath) }
    function liveStatusText(label) {
        if (label === "Downloads")
            return (processRunner.running || processRunner.clipboardRunning) ? "Running" : "Standby"
        if (label === "Clipboard")
            return clipMonitor.active ? (clipMonitor.paused ? "Paused" : "Capturing") : "Off"
        if (label === "Duplicate scan")
            return dupScanner.scanning ? "Scanning" : (dupScanner.groups.length > 0 ? (dupScanner.groups.length + " groups") : "Clean")
        return ""
    }
    function liveStatusColor(label) {
        if (label === "Downloads")
            return processRunner.running ? theme.green : (processRunner.clipboardRunning ? theme.orange : theme.textMuted)
        if (label === "Clipboard")
            return clipMonitor.active ? (clipMonitor.paused ? theme.orange : theme.green) : theme.textMuted
        if (label === "Duplicate scan")
            return dupScanner.scanning ? theme.orange : (dupScanner.groups.length > 0 ? theme.red : theme.green)
        return theme.textMuted
    }
    function liveStatusHistory(label) {
        if (label === "Duplicate scan" && root.historyEntry)
            return root.historyEntry.dupGroups + " groups"
        return ""
    }
    function isSystemActive() {
        return processRunner.running || processRunner.clipboardRunning || clipMonitor.active || root.duplicatesLongScanActive
    }

    property string historyViewDate: ""
    property var    historyEntry: null
    property var fileCountHistory:  []
    property var sessionMbHistory:  []
    property var urlCountHistory:   []
    property var dupGroupsHistory:  []
    property var fileCountTimes:  []
    property var sessionMbTimes:  []
    property var urlCountTimes:   []
    property var dupGroupsTimes:  []
    property string sessionStartedAt: new Date().toISOString()
    property bool duplicatesLongScanActive: false

    Connections {
        target: dupScanner
        function onScanningChanged() {
            if (dupScanner.scanning) {
                hideDupActiveTimer.stop()
                showDupActiveTimer.restart()
            } else {
                showDupActiveTimer.stop()
                if (root.duplicatesLongScanActive) hideDupActiveTimer.restart()
                else root.duplicatesLongScanActive = false
            }
        }
    }

    Timer {
        id: showDupActiveTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (dupScanner.scanning)
                root.duplicatesLongScanActive = true
        }
    }

    Timer {
        id: hideDupActiveTimer
        interval: 650
        repeat: false
        onTriggered: root.duplicatesLongScanActive = false
    }

    Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: {
            var now = Qt.formatTime(new Date(), "HH:mm:ss")
            function push(arr, val) { var a = arr.slice(); a.push(val); if (a.length > 60) a.shift(); return a; }
            root.fileCountHistory  = push(root.fileCountHistory,  dlStats.fileCount)
            root.sessionMbHistory  = push(root.sessionMbHistory,  dlStats.sessionMb)
            root.urlCountHistory   = push(root.urlCountHistory,   clipMonitor.urlCount)
            root.dupGroupsHistory  = push(root.dupGroupsHistory,  dupScanner.groups.length)
            root.fileCountTimes    = push(root.fileCountTimes,    now)
            root.sessionMbTimes    = push(root.sessionMbTimes,    now)
            root.urlCountTimes     = push(root.urlCountTimes,     now)
            root.dupGroupsTimes    = push(root.dupGroupsTimes,    now)
            historyMgr.recordPoint(dlStats.fileCount, dlStats.sessionMb, clipMonitor.urlCount, dupScanner.groups.length, new Date().toISOString())
            if (root.chartVisible) root.refreshChartRange()
        }
    }

    property string chartTitle:   ""
    property var    chartData:    []
    property var    chartTimes:   []
    property string chartUnit:    ""
    property color  chartColor:   theme.accent
    property bool   chartVisible: false
    property string chartMetricKey: ""
    property int    chartRangeDays: 0
    property string chartRangeLabel: "Session"

    function metricSeries(metricKey) {
        if (metricKey === "fileCount")   return { data: root.fileCountHistory,  times: root.fileCountTimes }
        if (metricKey === "sessionMb")   return { data: root.sessionMbHistory,  times: root.sessionMbTimes }
        if (metricKey === "urlCaptured") return { data: root.urlCountHistory,   times: root.urlCountTimes }
        if (metricKey === "dupGroups")   return { data: root.dupGroupsHistory,  times: root.dupGroupsTimes }
        return { data: [], times: [] }
    }
    function refreshChartRange() {
        if (chartMetricKey === "") return
        if (chartRangeDays === 0) { var s = metricSeries(chartMetricKey); chartData = s.data; chartTimes = s.times; chartRangeLabel = "Session"; return }
        var rows = historyMgr.seriesForRange(chartMetricKey, chartRangeDays)
        var data = [], times = []
        for (var i = 0; i < rows.length; i++) { data.push(Number(rows[i].value)); times.push(rows[i].timeLabel) }
        chartData = data; chartTimes = times; chartRangeLabel = chartRangeDays + " days"
    }
    function showChart(title, metricKey, color, unit) {
        chartMetricKey = metricKey; chartTitle = title; chartColor = color; chartUnit = unit || ""; chartRangeDays = 0
        refreshChartRange()
        if (!chartData || chartData.length === 0) { chartRangeDays = 7; refreshChartRange() }
        if (!chartData || chartData.length === 0) { chartRangeDays = 30; refreshChartRange() }
        if (!chartData || chartData.length === 0) return
        chartVisible = true
    }

    ScrollView {
        anchors.fill: parent; clip: true; contentWidth: availableWidth

        ColumnLayout {
            width: root.width; spacing: 14
            Item { height: 4 }

            // ── Hero ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20
                implicitHeight: heroContent.implicitHeight + 44
                radius: 18
                color: theme.surface
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.color: theme.border; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                clip: true

                ThemeTransition { anchors.fill: parent; radius: parent.radius }

                Rectangle { anchors.fill: parent; radius: parent.radius; gradient: Gradient {
                    GradientStop { position: 0.0;  color: Qt.rgba(theme.accent.r,  theme.accent.g,  theme.accent.b,  0.14) }
                    GradientStop { position: 0.55; color: Qt.rgba(theme.blue.r,    theme.blue.g,    theme.blue.b,    0.10) }
                    GradientStop { position: 1.0;  color: "transparent" }
                }}
                Rectangle { width: 220; height: 220; radius: 110; x: parent.width - width - 24; y: -72; color: Qt.rgba(theme.accent.r,theme.accent.g,theme.accent.b,0.06) }
                Rectangle { width: 160; height: 160; radius: 80;  x: parent.width - width-48; y: 82; color: Qt.rgba(theme.orange.r,theme.orange.g,theme.orange.b,0.08) }

                RowLayout {
                    id: heroContent; anchors { fill: parent; margins: 22 } spacing: 18

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        RowLayout { spacing: 8
                            Rectangle {
                                implicitWidth: statusRow.implicitWidth + 18; implicitHeight: 28; radius: 14
                                color: root.isSystemActive() ? Qt.rgba(theme.green.r,theme.green.g,theme.green.b,0.18) : Qt.rgba(theme.textMuted.r,theme.textMuted.g,theme.textMuted.b,0.10)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                RowLayout { id: statusRow; anchors.centerIn: parent; spacing: 8
                                    Rectangle { width: 8; height: 8; radius: 4; color: root.isSystemActive()?theme.green:theme.textMuted
                                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                        SequentialAnimation on opacity { running: root.isSystemActive(); loops: Animation.Infinite
                                            NumberAnimation { to: 0.35; duration: 520 } NumberAnimation { to: 1.0; duration: 520 } } }
                                    Text { text: root.isSystemActive()?"System active":"System idle"; color: root.isSystemActive()?theme.green:theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                                }
                            }
                        }
                        Text { text: "Control Center"; color: theme.textPrimary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 30; font.bold: true; font.family: "Segoe UI" }
                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                            text: "Inicio concentra el estado del downloader, accesos rápidos y monitores vivos."
                            color: theme.textSecondary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 13; font.family: "Segoe UI" }
                        RowLayout { spacing: 8
                            AppButton { Layout.preferredWidth: 160; text: "Open Downloads"; bgColor: theme.accent; hoverColor: "#3ea7e0"; textSize: 12; onClicked: root.goToTab(1) }
                            AppButton { Layout.preferredWidth: 150; text: "Open Clipboard";  bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.goToTab(3) }
                            AppButton { Layout.preferredWidth: 140; text: "Open Folder";     bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.openDownloadsFolder() }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 290; implicitHeight: summaryCol.implicitHeight + 32; radius: 16
                        color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.42)
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        border.color: theme.border; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        ThemeTransition { anchors.fill: parent; radius: parent.radius }

                        ColumnLayout {
                            id: summaryCol; anchors { fill: parent; margins: 16 } spacing: 8
                            property bool summaryExpanded: true

                            RowLayout {
                                Text { text: "Live Status"; color: theme.textMuted
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 24; height: 24; radius: 12; color: expandHov.containsMouse ? theme.surfaceAlt : "transparent"; Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: summaryExpanded ? "▲" : "▼"; color: theme.textMuted; font.pixelSize: 10 }
                                    MouseArea { id: expandHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: summaryExpanded = !summaryExpanded } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; visible: summaryCol.summaryExpanded && historyMgr.entries.length > 0
                                height: 28; radius: 8
                                color: root.historyViewDate !== "" ? Qt.rgba(theme.orange.r,theme.orange.g,theme.orange.b,0.15) : theme.surfaceAlt
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: root.historyViewDate !== "" ? theme.orange : "transparent"; border.width: 1
                                RowLayout { anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text { text: root.historyViewDate !== "" ? ("Viewing: "+root.historyViewDate) : "History"; color: root.historyViewDate !== "" ? theme.orange : theme.textMuted; font.pixelSize: 10; font.bold: true; font.family: "Segoe UI" }
                                    Item { Layout.fillWidth: true }
                                    Text { visible: root.historyViewDate !== ""; text: "← Live"; color: theme.accent; font.pixelSize: 10; font.bold: true
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.historyViewDate = ""; root.historyEntry = null } } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; propagateComposedEvents: true; onClicked: historyPopup.open() }
                            }

                            Repeater {
                                model: ["Downloads", "Clipboard", "Duplicate scan"]
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    color: theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    visible: summaryCol.summaryExpanded
                                    RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        Text { text: modelData; color: theme.textSecondary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 12; font.family: "Segoe UI" }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.historyEntry && root.liveStatusHistory(modelData) !== "" ? root.liveStatusHistory(modelData) : root.liveStatusText(modelData); color: root.historyEntry && root.liveStatusHistory(modelData) !== "" ? theme.orange : root.liveStatusColor(modelData); Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 12; font.bold: true; font.family: "Segoe UI" }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Stat cards ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.preferredHeight: 96; spacing: 12
                Repeater {
                    model: [
                        { icon: "📦", label: "New Files",        unit: "files",  metricKey: "fileCount",   val: root.historyEntry?root.historyEntry.fileCount.toString():dlStats.fileCount.toString(), color: theme.accent,  hist: root.fileCountHistory, times: root.fileCountTimes },
                        { icon: "💾", label: "Downloaded Size",  unit: "MB",     metricKey: "sessionMb",   val: root.historyEntry?(root.historyEntry.sessionMb.toFixed(1)+" MB"):(dlStats.sessionMb.toFixed(1)+" MB"), color: theme.orange, hist: root.sessionMbHistory, times: root.sessionMbTimes },
                        { icon: "🔗", label: "URLs Captured",    unit: "URLs",   metricKey: "urlCaptured", val: root.historyEntry?root.historyEntry.urlCaptured.toString():clipMonitor.urlCount.toString(), color: theme.green, hist: root.urlCountHistory, times: root.urlCountTimes },
                        { icon: "♻",  label: "Duplicate Groups", unit: "groups", metricKey: "dupGroups",   val: root.historyEntry?root.historyEntry.dupGroups.toString():dupScanner.groups.length.toString(), color: theme.red, hist: root.dupGroupsHistory, times: root.dupGroupsTimes },
                    ]
                    delegate: Rectangle {
                        required property var modelData; required property int index
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                        color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        border.color: cardHov.containsMouse ? modelData.color : theme.border; border.width: cardHov.containsMouse ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on border.width  { NumberAnimation { duration: 150 } }

                        ThemeTransition { anchors.fill: parent; radius: parent.radius }

                        property bool hasData: (modelData.hist && modelData.hist.length > 0) || historyMgr.seriesForRange(modelData.metricKey, 30).length > 0
                        property bool zeroValue: index === 0 && Number(root.historyEntry ? root.historyEntry.fileCount : dlStats.fileCount) === 0

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 3; radius: 2
                            color: theme.transitioning
                                   ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.9)
                                   : modelData.color
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            opacity: theme.transitioning ? 0.95 : 0.8
                            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        }
                        Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(modelData.color.r,modelData.color.g,modelData.color.b, zeroValue?0.03:(cardHov.containsMouse?0.10:0.06)); Behavior on color { ColorAnimation { duration: 150 } } }

                        RowLayout { anchors { fill: parent; margins: 14 } spacing: 12
                            Text { text: modelData.icon; font.pixelSize: 26 }
                            Column { spacing: 2
                                Text { text: modelData.val; color: modelData.color; font.pixelSize: 20; font.bold: true; font.family: "Segoe UI" }
                                Text { text: modelData.label; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 11; font.family: "Segoe UI" }
                            }
                            Item { Layout.fillWidth: true }
                            Column { spacing: 2; visible: hasData; opacity: cardHov.containsMouse ? 1.0 : 0.5; Behavior on opacity { NumberAnimation { duration: 150 } }
                                Canvas {
                                    width: 52; height: 28; property var sparkData: modelData.hist
                                    onSparkDataChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                        if (!sparkData || sparkData.length < 2) return
                                        var max = Math.max.apply(null, sparkData); if (max === 0) max = 1
                                        var col = modelData.color; var step = width / (sparkData.length - 1)
                                        ctx.beginPath(); ctx.moveTo(0, height - (sparkData[0]/max)*height)
                                        for (var i=1; i<sparkData.length; i++) ctx.lineTo(i*step, height - (sparkData[i]/max)*height)
                                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                                        ctx.fillStyle = Qt.rgba(col.r,col.g,col.b,0.2); ctx.fill()
                                        ctx.beginPath(); ctx.strokeStyle = Qt.rgba(col.r,col.g,col.b,0.9); ctx.lineWidth = 1.5
                                        ctx.moveTo(0, height-(sparkData[0]/max)*height)
                                        for (var j=1; j<sparkData.length; j++) ctx.lineTo(j*step, height-(sparkData[j]/max)*height)
                                        ctx.stroke()
                                    }
                                    Connections { target: root
                                        function onFileCountHistoryChanged()  { if (index===0) parent.requestPaint() }
                                        function onSessionMbHistoryChanged()  { if (index===1) parent.requestPaint() }
                                        function onUrlCountHistoryChanged()   { if (index===2) parent.requestPaint() }
                                        function onDupGroupsHistoryChanged()  { if (index===3) parent.requestPaint() }
                                    }
                                }
                                Text { text: "📈 Chart"; color: modelData.color; font.pixelSize: 9; font.family: "Segoe UI"; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                        MouseArea { id: cardHov; anchors.fill: parent; hoverEnabled: true; cursorShape: hasData ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { if (hasData) root.showChart(modelData.label, modelData.metricKey, modelData.color, modelData.unit) } }
                    }
                }
            }

            // ── Quick Actions + Workspace ─────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; spacing: 14

                Rectangle {
                    id: quickActionsCard; Layout.fillWidth: true; Layout.preferredWidth: 2; Layout.alignment: Qt.AlignTop
                    radius: 16; color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    property bool expanded: appConfig.homeQuickActionsExpanded
                    implicitHeight: expanded ? qaInner.implicitHeight + 32 : 64
                    Behavior on implicitHeight { NumberAnimation { duration: 180 } } clip: true
                    ThemeTransition { anchors.fill: parent; radius: parent.radius }

                    ColumnLayout { id: qaInner; anchors { fill: parent; margins: 16 } spacing: 14
                        RowLayout {
                            Text { text: "Quick Actions"; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 16; font.bold: true; font.family: "Segoe UI" }
                            Item { Layout.fillWidth: true }
                            AppButton { width: 80; height: 26; text: quickActionsCard.expanded?"Hide":"Show"; bgColor: theme.surfaceAlt; textColor: theme.textSecondary; textSize: 10; onClicked: appConfig.homeQuickActionsExpanded = !quickActionsCard.expanded }
                        }
                        GridLayout {
                            Layout.fillWidth: true; visible: quickActionsCard.expanded; opacity: quickActionsCard.expanded ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } }
                            columns: 2; rowSpacing: 10; columnSpacing: 10
                            AppButton { Layout.fillWidth: true; text: "Go to Downloads";   bgColor: theme.accent;    textSize: 12; onClicked: root.goToTab(1) }
                            AppButton { Layout.fillWidth: true; text: "Go to Duplicates";  bgColor: theme.orange;    hoverColor: "#CC7000"; textSize: 12; onClicked: root.goToTab(2) }
                            AppButton { Layout.fillWidth: true; text: clipMonitor.active?"Open Clipboard":"Activate Clipboard"; bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.goToTab(3) }
                            AppButton { Layout.fillWidth: true; text: "Open Notepads";     bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.goToTab(4) }
                            AppButton { Layout.fillWidth: true; text: "Downloads Folder";  bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.openDownloadsFolder() }
                            AppButton { Layout.fillWidth: true; text: "Notepads Folder";   bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 12; onClicked: root.openNotepadsFolder() }
                        }
                    }
                }

                Rectangle {
                    id: modulesCard; Layout.fillWidth: true; Layout.preferredWidth: 3; Layout.alignment: Qt.AlignTop
                    radius: 16; color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    property bool expanded: appConfig.homeModulesExpanded
                    implicitHeight: expanded ? modInner.implicitHeight + 32 : 64
                    Behavior on implicitHeight { NumberAnimation { duration: 180 } } clip: true
                    ThemeTransition { anchors.fill: parent; radius: parent.radius }

                    ColumnLayout { id: modInner; anchors { fill: parent; margins: 16 } spacing: 14
                        RowLayout {
                            Text { text: "Workspace"; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 16; font.bold: true; font.family: "Segoe UI" }
                            Item { Layout.fillWidth: true }
                            AppButton { width: 96; height: 26; text: modulesCard.expanded?"Hide":"Show"; bgColor: theme.surfaceAlt; textColor: theme.textSecondary; textSize: 10; onClicked: appConfig.homeModulesExpanded = !modulesCard.expanded }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; visible: modulesCard.expanded; opacity: modulesCard.expanded ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } spacing: 10
                            Repeater {
                                model: [
                                    { label: "Clipboard monitor", val: clipMonitor.urlCount+" URLs",                  color: theme.green  },
                                    { label: "Notepads indexed",  val: notepadMgr.files.length.toString(),            color: theme.accent },
                                    { label: "Root destination",  val: appConfig.downloadRootPath.split(/[\\/]/).pop(), color: theme.orange },
                                ]
                                delegate: Rectangle {
                                    required property var modelData; Layout.fillWidth: true; height: 36; radius: 10
                                    color: theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    RowLayout { anchors { fill: parent; margins: 12 }
                                        Text { text: modelData.label; color: theme.textSecondary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 12; font.family: "Segoe UI" }
                                        Item { Layout.fillWidth: true }
                                        Text { text: modelData.val; color: modelData.color; font.pixelSize: 12; font.bold: true; font.family: "Segoe UI" }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 8 }
        }
    }

    // ── History Popup ─────────────────────────────────────────────────────
    Popup {
        id: historyPopup; modal: true; anchors.centerIn: Overlay.overlay
        width: 340; height: Math.min(520, historyMgr.entries.length * 62 + 100); padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { radius: 14; color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } ThemeTransition { anchors.fill: parent; radius: parent.radius } }
        ColumnLayout { anchors.fill: parent; spacing: 0
            Rectangle { Layout.fillWidth: true; height: 48; radius: 14; color: theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 8; color: parent.color }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
                RowLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                    Text { text: "📅  Session History"; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 14; font.bold: true; font.family: "Segoe UI" }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 26; height: 26; radius: 6; color: hClose.containsMouse ? theme.red : "transparent"; Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "✕"; color: hClose.containsMouse ? "white" : theme.textMuted; font.pixelSize: 13 }
                        MouseArea { id: hClose; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: historyPopup.close() } }
                }
            }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 10; clip: true; spacing: 6; model: historyMgr.entries
                delegate: Rectangle {
                    required property var modelData; required property int index
                    property bool isSelected: root.historyViewDate === modelData.date
                    width: ListView.view.width; height: 52; radius: 10
                    color: isSelected ? Qt.rgba(theme.accent.r,theme.accent.g,theme.accent.b,0.12) : theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 150 } }
                    border.color: isSelected ? theme.accent : theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                        Rectangle { width: 44; height: 36; radius: 8; color: Qt.rgba(theme.accent.r,theme.accent.g,theme.accent.b,0.15); Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            Text { anchors.centerIn: parent; text: modelData.dateLabel||modelData.date.slice(8); color: theme.accent; font.pixelSize: 13; font.bold: true; font.family: "Segoe UI" } }
                        Column { spacing: 2
                            Text { text: modelData.date; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                            Text { text: (modelData.fileCount||0)+" files · "+Number(modelData.sessionMb||0).toFixed(1)+" MB · "+(modelData.urlCaptured||0)+" URLs"; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: "Segoe UI" }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 50; height: 24; radius: 6; color: isSelected ? theme.accent : theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: isSelected?"✓ Active":"View"; color: isSelected?"white":theme.textSecondary; font.pixelSize: 10; font.bold: true; font.family: "Segoe UI" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (isSelected) { root.historyViewDate=""; root.historyEntry=null } else { root.historyViewDate=modelData.date; root.historyEntry=modelData }; historyPopup.close() } }
                        }
                    }
                }
                Text { visible: historyMgr.entries.length === 0; anchors.centerIn: parent; text: "No history yet.\nData saves when the app runs."; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 12; font.family: "Segoe UI"; horizontalAlignment: Text.AlignHCenter }
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutBack } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130 } }
    }

    // ── Chart Popup ───────────────────────────────────────────────────────
    Popup {
        id: chartPopup; modal: true; parent: Overlay.overlay
        x: Math.max(24, ((parent?parent.width:root.width)-width)/2)
        y: Math.max(20, ((parent?parent.height:root.height)-height)/2)
        width: Math.min((parent?parent.width:root.width)-48, 1180)
        height: Math.min((parent?parent.height:root.height)-40, 760)
        padding: 0; visible: root.chartVisible
        onVisibleChanged: if (!visible) root.chartVisible = false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { radius: 20; color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } ThemeTransition { anchors.fill: parent; radius: parent.radius } }

        QtObject {
            id: chartMath
            property real maxValue: { var d=root.chartData; if(!d||d.length===0) return 1; var m=Math.max.apply(null,d); return m>0?m:1 }
            property real minValue: { var d=root.chartData; if(!d||d.length===0) return 0; return Math.min.apply(null,d) }
            property real avgValue: { var d=root.chartData; if(!d||d.length===0) return 0; return d.reduce(function(a,b){return a+b},0)/d.length }
            function formatValue(v) { if(v===undefined||v===null) return '--'; return root.chartUnit==='MB'?Number(v).toFixed(1)+' '+root.chartUnit:Math.round(v).toString()+' '+root.chartUnit }
        }

        ColumnLayout { anchors.fill: parent; spacing: 0
            Rectangle { Layout.fillWidth: true; height: 76; radius: 20; color: theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 20; color: parent.color }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
                RowLayout { anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 18; spacing: 14
                    Rectangle { width: 42; height: 42; radius: 12; color: Qt.rgba(root.chartColor.r,root.chartColor.g,root.chartColor.b,0.14); border.color: Qt.rgba(root.chartColor.r,root.chartColor.g,root.chartColor.b,0.28); border.width: 1
                        Text { anchors.centerIn: parent; text: 'CH'; color: root.chartColor; font.pixelSize: 12; font.bold: true; font.family: 'Segoe UI' } }
                    Column { spacing: 4
                        Text { text: root.chartTitle; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 18; font.bold: true; font.family: 'Segoe UI' }
                        Text { text: root.chartRangeLabel+' - live view - '+root.chartData.length+' points'; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: 'Segoe UI' }
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout { spacing: 8
                        Repeater { model: [{lbl:'Last',val:root.chartData.length>0?root.chartData[root.chartData.length-1]:0},{lbl:'Min',val:chartMath.minValue},{lbl:'Max',val:chartMath.maxValue},{lbl:'Avg',val:chartMath.avgValue}]
                            delegate: Rectangle { required property var modelData; height: 40; radius: 10; width: statC.implicitWidth+22; color: Qt.rgba(root.chartColor.r,root.chartColor.g,root.chartColor.b,0.10); border.color: Qt.rgba(root.chartColor.r,root.chartColor.g,root.chartColor.b,0.18); border.width: 1
                                Column { id: statC; anchors.centerIn: parent; spacing: 2
                                    Text { text: modelData.lbl; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 9; font.family: 'Segoe UI'; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: chartMath.formatValue(modelData.val); color: root.chartColor; font.pixelSize: 11; font.bold: true; font.family: 'Segoe UI'; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                        }
                    }
                    Rectangle { width: 34; height: 34; radius: 9; color: closeChartHov.containsMouse?theme.red:'transparent'; Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: 'X'; color: closeChartHov.containsMouse?'white':theme.textMuted; font.pixelSize: 13; font.bold: true }
                        MouseArea { id: closeChartHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chartVisible = false } }
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 20
                ColumnLayout { anchors.fill: parent; spacing: 14
                    RowLayout { Layout.fillWidth: true; spacing: 10
                        Text { text: 'Range'; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.bold: true; font.family: 'Segoe UI' }
                        Repeater { model: [{label:'Session',days:0},{label:'3D',days:3},{label:'7D',days:7},{label:'15D',days:15},{label:'30D',days:30}]
                            delegate: Rectangle { required property var modelData; height: 28; radius: 8; width: rT.implicitWidth+18
                                color: root.chartRangeDays===modelData.days?root.chartColor:(rHov.containsMouse?theme.surface:theme.surfaceAlt); Behavior on color { ColorAnimation { duration: 150 } }
                                border.color: root.chartRangeDays===modelData.days?root.chartColor:theme.border; border.width: 1
                                Text { id: rT; anchors.centerIn: parent; text: modelData.label; color: root.chartRangeDays===modelData.days?'white':theme.textSecondary; Behavior on color { ColorAnimation { duration: 150 } } font.pixelSize: 10; font.family: 'Segoe UI' }
                                MouseArea { id: rHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.chartRangeDays=modelData.days; root.refreshChartRange() } }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 16
                        color: Qt.rgba(theme.bg.r,theme.bg.g,theme.bg.b,0.48); Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        clip: true
                        ThemeTransition { anchors.fill: parent; radius: parent.radius }

                        Item { anchors.fill: parent; anchors.margins: 18
                            Column { id: yAxis; anchors { left: parent.left; top: parent.top; bottom: xAxisRow.top; bottomMargin: 8 } width: 54; spacing: 0
                                Repeater { model: 5; delegate: Item { width: yAxis.width; height: yAxis.height/4; visible: index<5
                                    Text { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.top } text: { var v=chartMath.maxValue*(1-index/4); return root.chartUnit==='MB'?Number(v).toFixed(1):Math.round(v).toString() } color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: 'Consolas' }
                                }}
                            }
                            Item { id: chartStage; anchors { left: yAxis.right; leftMargin: 8; right: parent.right; top: parent.top; bottom: xAxisRow.top; bottomMargin: 10 }
                                Canvas { id: chartCanvas; anchors.fill: parent; renderTarget: Canvas.Image; antialiasing: true
                                    onPaint: {
                                        var ctx=getContext('2d'); ctx.clearRect(0,0,width,height)
                                        var data=root.chartData; if(!data||data.length<2) return
                                        var max=chartMath.maxValue; var col=root.chartColor; var padTop=10; var padBot=10; var h=height-padTop-padBot; var step=width/Math.max(1,data.length-1)
                                        for(var g=0;g<=4;g++){var gy=padTop+(g/4)*h; ctx.strokeStyle=Qt.rgba(theme.textMuted.r,theme.textMuted.g,theme.textMuted.b,0.16); ctx.lineWidth=1; ctx.beginPath(); ctx.moveTo(0,gy); ctx.lineTo(width,gy); ctx.stroke()}
                                        var grad=ctx.createLinearGradient(0,padTop,0,padTop+h); grad.addColorStop(0,Qt.rgba(col.r,col.g,col.b,0.28)); grad.addColorStop(1,Qt.rgba(col.r,col.g,col.b,0.03))
                                        ctx.beginPath(); ctx.moveTo(0,padTop+h-(data[0]/max)*h); for(var i=1;i<data.length;i++) ctx.lineTo(i*step,padTop+h-(data[i]/max)*h); ctx.lineTo((data.length-1)*step,padTop+h); ctx.lineTo(0,padTop+h); ctx.closePath(); ctx.fillStyle=grad; ctx.fill()
                                        ctx.beginPath(); ctx.strokeStyle=Qt.rgba(col.r,col.g,col.b,1); ctx.lineWidth=3; ctx.lineJoin='round'; ctx.lineCap='round'; ctx.moveTo(0,padTop+h-(data[0]/max)*h); for(var j=1;j<data.length;j++) ctx.lineTo(j*step,padTop+h-(data[j]/max)*h); ctx.stroke()
                                    }
                                    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
                                }
                                Canvas { id: hoverCanvas; anchors.fill: parent; renderTarget: Canvas.Image; antialiasing: true; property int hoveredIndex: -1
                                    onPaint: {
                                        var ctx=getContext('2d'); ctx.clearRect(0,0,width,height)
                                        var data=root.chartData; if(!data||data.length<2||hoveredIndex<0||hoveredIndex>=data.length) return
                                        var max=chartMath.maxValue; var col=root.chartColor; var padTop=10; var h=height-padTop-10; var step=width/Math.max(1,data.length-1)
                                        var hx=hoveredIndex*step; var hy=padTop+h-(data[hoveredIndex]/max)*h
                                        ctx.strokeStyle=Qt.rgba(col.r,col.g,col.b,0.34); ctx.lineWidth=1; ctx.beginPath(); ctx.moveTo(hx,padTop); ctx.lineTo(hx,padTop+h); ctx.stroke()
                                        ctx.beginPath(); ctx.arc(hx,hy,10,0,Math.PI*2); ctx.fillStyle=Qt.rgba(col.r,col.g,col.b,0.16); ctx.fill()
                                        ctx.beginPath(); ctx.arc(hx,hy,4.5,0,Math.PI*2); ctx.fillStyle=Qt.rgba(col.r,col.g,col.b,1); ctx.fill()
                                    }
                                    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
                                }
                                MouseArea { anchors.fill: parent; hoverEnabled: true
                                    onPositionChanged: function(mouse) { var data=root.chartData; if(!data||data.length<2) return; var step=chartStage.width/Math.max(1,data.length-1); var idx=Math.round(mouse.x/step); idx=Math.max(0,Math.min(data.length-1,idx)); if(hoverCanvas.hoveredIndex===idx) return; hoverCanvas.hoveredIndex=idx; hoverCanvas.requestPaint() }
                                    onExited: { if(hoverCanvas.hoveredIndex!==-1){hoverCanvas.hoveredIndex=-1; hoverCanvas.requestPaint()} }
                                }
                            }

                            Rectangle { id: tooltipBubble; visible: hoverCanvas.hoveredIndex>=0; width: ttC.implicitWidth+24; height: ttC.implicitHeight+16; radius: 10
                                color: theme.surface; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: Qt.rgba(root.chartColor.r,root.chartColor.g,root.chartColor.b,0.50); border.width: 1
                                property real targetX: { if(!root.chartData||root.chartData.length<2) return chartStage.x; var step=chartStage.width/Math.max(1,root.chartData.length-1); var bx=chartStage.x+hoverCanvas.hoveredIndex*step; return Math.min(Math.max(chartStage.x+6,bx+12),parent.width-width-6) }
                                property real targetY: { if(!root.chartData||root.chartData.length===0) return chartStage.y+8; var max=chartMath.maxValue; var h=chartStage.height-20; var val=root.chartData[Math.max(0,hoverCanvas.hoveredIndex)]; var cy=chartStage.y+10+h-(val/max)*h; return Math.max(chartStage.y+6,cy-height-10) }
                                x: targetX; y: targetY
                                Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Column { id: ttC; anchors.centerIn: parent; spacing: 3
                                    Text { text: { if(hoverCanvas.hoveredIndex<0||!root.chartTimes||root.chartTimes.length===0) return ''; return root.chartTimes[Math.min(hoverCanvas.hoveredIndex,root.chartTimes.length-1)]||'' } color: theme.textMuted; font.pixelSize: 9; font.family: 'Consolas'; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: { if(hoverCanvas.hoveredIndex<0||!root.chartData) return ''; var v=root.chartData[Math.min(hoverCanvas.hoveredIndex,root.chartData.length-1)]; return chartMath.formatValue(v) } color: root.chartColor; font.pixelSize: 14; font.bold: true; font.family: 'Segoe UI'; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }

                            Row { id: xAxisRow; anchors { left: yAxis.right; leftMargin: 8; right: parent.right; bottom: parent.bottom } height: 18
                                Text { width: parent.width/3; text: root.chartTimes&&root.chartTimes.length>0?root.chartTimes[0]:''; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: 'Consolas'; horizontalAlignment: Text.AlignLeft }
                                Text { width: parent.width/3; text: { if(!root.chartTimes||root.chartTimes.length===0) return ''; return root.chartTimes[Math.floor(root.chartTimes.length/2)]||'' } color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: 'Consolas'; horizontalAlignment: Text.AlignHCenter }
                                Text { width: parent.width/3; text: root.chartTimes&&root.chartTimes.length>0?root.chartTimes[root.chartTimes.length-1]:''; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.family: 'Consolas'; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }

                    RowLayout { Layout.fillWidth: true; spacing: 10
                        Repeater { model: [{lbl:'Points',val:root.chartData.length.toString()},{lbl:'Started',val:root.sessionStartedAt.slice(11,19)},{lbl:'Range',val:root.chartRangeLabel},{lbl:'Unit',val:root.chartUnit}]
                            delegate: Rectangle { required property var modelData; Layout.preferredHeight: 34; radius: 9; color: theme.surfaceAlt; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } border.color: theme.border; border.width: 1; Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } implicitWidth: iC.implicitWidth+22
                                Column { id: iC; anchors.centerIn: parent; spacing: 1
                                    Text { text: modelData.lbl; color: theme.textMuted; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 9; font.family: 'Segoe UI'; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: modelData.val; color: theme.textPrimary; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } font.pixelSize: 10; font.bold: true; font.family: 'Segoe UI'; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        Connections { target: root
            function onChartDataChanged()    { hoverCanvas.hoveredIndex=-1; chartCanvas.requestPaint(); hoverCanvas.requestPaint() }
            function onChartVisibleChanged() { if(root.chartVisible){hoverCanvas.hoveredIndex=-1; chartCanvas.requestPaint(); hoverCanvas.requestPaint()} }
            function onChartColorChanged()   { chartCanvas.requestPaint(); hoverCanvas.requestPaint() }
            function onFileCountHistoryChanged() { if(root.chartVisible&&root.chartMetricKey==='fileCount'&&root.chartRangeDays===0) root.refreshChartRange() }
            function onSessionMbHistoryChanged() { if(root.chartVisible&&root.chartMetricKey==='sessionMb'&&root.chartRangeDays===0) root.refreshChartRange() }
            function onUrlCountHistoryChanged()  { if(root.chartVisible&&root.chartMetricKey==='urlCaptured'&&root.chartRangeDays===0) root.refreshChartRange() }
            function onDupGroupsHistoryChanged() { if(root.chartVisible&&root.chartMetricKey==='dupGroups'&&root.chartRangeDays===0) root.refreshChartRange() }
        }
        enter: Transition { NumberAnimation { property: 'opacity'; from: 0; to: 1; duration: 210 } NumberAnimation { property: 'scale'; from: 0.97; to: 1; duration: 210; easing.type: Easing.OutCubic } }
        exit:  Transition { NumberAnimation { property: 'opacity'; from: 1; to: 0; duration: 150 } NumberAnimation { property: 'scale'; from: 1; to: 0.985; duration: 150; easing.type: Easing.OutCubic } }
    }
}
