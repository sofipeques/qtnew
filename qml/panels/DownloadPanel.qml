import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    // ── Notepad-mode state ────────────────────────────────────────────────
    property bool   running:         false
    property bool   paused:          false
    property real   progress:        0.0
    property int    currentUrl:      0
    property int    totalUrls:       0
    property string currentFilename: ""
    property string currentUrlStr:   ""
    property int    delaySeconds:    0
    property int    modeAll:         1
    property var    selectedFiles:   []

    property string currentNotepad:     ""
    property int    currentNotepadUrl:  0
    property int    totalNotepadUrls:   0

    property var    notepadLogs:  ({})
    property var    notepadStats: ({})
    property int    globalQueuedUrls: 0
    property int    selectedQueuedUrls: 0
    property int    selectedQueuedTotal: 0
    property string viewingNotepad:       ""
    property bool   logPanelExpanded:     false
    property bool   packagePanelCollapsed: false
    readonly property int selectorRowHeight:   42
    readonly property int selectorVisibleRows: Math.max(1, Math.min(5, notepadMgr.files.length))

    // ── Clipboard-mode state ──────────────────────────────────────────────
    property bool   clipMode:        false
    property bool   clipRunning:     processRunner.clipboardRunning
    property int    clipElapsed:     processRunner.clipboardElapsed
    property int    clipDownloaded:  processRunner.clipboardDownloaded

    // ── Session timer (notepad mode) ──────────────────────────────────────
    property int sessionSeconds: 0
    Timer {
        interval: 1000; repeat: true; running: root.running
        onTriggered: root.sessionSeconds++
    }

    function fmtTime(s) {
        var h = Math.floor(s/3600), m = Math.floor((s%3600)/60), sec = s%60
        return (h > 0 ? h + "h " : "") + m.toString().padStart(2,"0") + ":" + sec.toString().padStart(2,"0")
    }
    function syncDelaySeconds(rawText) {
        var trimmed = (rawText || "").trim()
        if (trimmed === "") return
        var value = parseInt(trimmed)
        if (!isNaN(value) && value >= 0) root.delaySeconds = value
    }
    function commitDelayInput() { syncDelaySeconds(delayInput.text) }
    function displayLabelForUrl(sourceUrl) {
        var url = (sourceUrl || "").trim()
        if (url === "") return ""
        var idMatch = url.match(/\/id\/(\d+)\/?$/i)
        if (idMatch) return "id/" + idMatch[1]
        var clean = url.replace(/\/+$/, "")
        var parts = clean.split(/[\\/]/)
        return parts.length > 0 ? parts[parts.length - 1] : clean
    }
    function noteName(relPath) { return (relPath || "").split(/[\\/]/).pop().replace(".txt","") }
    function noteFolderPath(relPath) {
        var name = noteName(relPath)
        return name !== "" ? appConfig.downloadRootPath + "/" + name : ""
    }
    function ensureNotepadStats(relPath, total) {
        if (!relPath) return { processed:0, queued:0, total:total||0, succeeded:0, failedUrls:[] }
        var copy = root.notepadStats
        var stats = copy[relPath]
        if (!stats) stats = { processed:0, queued:0, total:total||0, succeeded:0, failedUrls:[] }
        else if (typeof total !== "undefined") stats.total = total
        copy[relPath] = stats; root.notepadStats = copy; return stats
    }
    function updateNotepadStats(relPath, processed, total, succeeded, failedUrls) {
        if (!relPath) return
        var copy  = root.notepadStats
        var stats = copy[relPath] || { processed:0, queued:0, total:total||0, succeeded:0, failedUrls:[] }
        stats.processed = processed; stats.total = total; stats.succeeded = succeeded
        stats.failedUrls = failedUrls ? failedUrls.slice() : stats.failedUrls
        copy[relPath] = stats; root.notepadStats = copy
    }
    function updateQueuedStats(relPath, queued, total) {
        if (!relPath) return
        var copy  = root.notepadStats
        var stats = copy[relPath] || { processed:0, queued:0, total:total||0, succeeded:0, failedUrls:[] }
        stats.queued = queued
        if (typeof total !== "undefined") stats.total = total
        copy[relPath] = stats; root.notepadStats = copy
        var sum = 0
        for (var key in copy) {
            if (copy[key] && typeof copy[key].queued === "number") sum += copy[key].queued
        }
        root.globalQueuedUrls = sum
        if (root.viewingNotepad === relPath) {
            root.selectedQueuedUrls = stats.queued || 0
            root.selectedQueuedTotal = stats.total || 0
        }
    }
    function syncSelectedQueued() {
        if (root.viewingNotepad !== "") {
            var stats = root.notepadStats[root.viewingNotepad]
            root.selectedQueuedUrls = stats ? (stats.queued || 0) : 0
            root.selectedQueuedTotal = stats ? (stats.total || 0) : 0
        } else {
            root.selectedQueuedUrls = 0; root.selectedQueuedTotal = 0
        }
    }
    function viewedNotepadStats() { return root.viewingNotepad !== "" ? root.notepadStats[root.viewingNotepad] : null }
    function viewedQueued()       { return root.viewingNotepad !== "" ? root.selectedQueuedUrls  : root.globalQueuedUrls  }
    function viewedQueuedTotal()  { return root.viewingNotepad !== "" ? root.selectedQueuedTotal : root.totalUrls }
    function triggerAutoDuplicateScan() {
        if (!appConfig.autoScanDuplicates || dupScanner.scanning) return
        if (dupScanner.scanPath === "") dupScanner.scanPath = appConfig.downloadRootPath
        dupScanner.startScan(); addLog("Auto-scan for duplicates started.", "started")
    }
    function loggedNotepadEntries() {
        var entries = []
        for (var i = 0; i < notepadMgr.files.length; i++) {
            var file = notepadMgr.files[i]
            if (root.notepadLogs[file.relPath] !== undefined) entries.push(file)
        }
        return entries
    }

    // ── Logs ──────────────────────────────────────────────────────────────
    ListModel { id: globalLogModel }
    ListModel { id: clipLogModel }

    function addLog(msg, kind) {
        globalLogModel.append({ modelData: "[" + Qt.formatTime(new Date(),"HH:mm:ss") + "] " + msg, kind: kind || "" })
    }
    function addClipLog(msg, kind) {
        clipLogModel.append({ modelData: "[" + Qt.formatTime(new Date(),"HH:mm:ss") + "] " + msg, kind: kind || "" })
    }
    function classifyDownloadLogKind(line, isError) {
        if (isError) return "error"
        var lower = (line || "").toLowerCase()
        if (lower.indexOf("failed download for") >= 0 || lower.indexOf("[err]") >= 0 || lower.indexOf("pending url") >= 0 || lower.indexOf("stopped") >= 0) return "error"
        if (lower.indexOf("completed") >= 0 || lower.indexOf("processed") >= 0 || lower.indexOf("process ended") >= 0) return "completed"
        if (lower.indexOf("paused") >= 0 || lower.indexOf("skipped duplicate") >= 0) return "paused"
        if (lower.indexOf("starting") >= 0 || lower.indexOf("resumed") >= 0 || lower.indexOf("auto-scan") >= 0 || lower.indexOf("active") >= 0) return "started"
        return ""
    }
    function addNotepadLog(notepadRelPath, msg, kind) {
        if (!notepadRelPath) return
        if (!root.notepadLogs[notepadRelPath]) {
            var m = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', root)
            var copy = root.notepadLogs; copy[notepadRelPath] = m; root.notepadLogs = copy
        }
        root.notepadLogs[notepadRelPath].append({ modelData: "[" + Qt.formatTime(new Date(),"HH:mm:ss") + "] " + msg, kind: kind || "" })
    }

    // ── Connections: notepad mode ─────────────────────────────────────────
    Connections {
        target: processRunner
        function onLogLine(line, isError) {
            var readingMatch = line.match(/^Reading URL (\d+)\/(\d+):\s+(.+)$/i)
            if (readingMatch) { updateQueuedStats(root.currentNotepad, parseInt(readingMatch[1]), parseInt(readingMatch[2])); return }
            if (!isError) {
                if (line.indexOf("Starting download for:") >= 0) return
                if (line.indexOf("Completed download for:") >= 0) return
                if (line.indexOf("All downloads have been completed") >= 0) return
                if (line.indexOf("[INFO] Starting batch:") >= 0) return
                if (line.indexOf("Starting notepad:") === 0) return
            }
            var kind = classifyDownloadLogKind(line, isError)
            var prefix = isError ? "[ERR] " : ""
            addLog(prefix + line, kind); addNotepadLog(root.currentNotepad, prefix + line, kind)
        }
        function onDownloadCompleted() { addLog("All selected notepads processed.", "all-completed"); root.progress = 1.0; triggerAutoDuplicateScan() }
        function onProgressUpdated(v)  { root.progress = v }
        function onRunningChanged() {
            root.running = processRunner.running
            if (!processRunner.running) { root.currentFilename = ""; root.currentUrlStr = ""; root.currentNotepad = "" }
        }
        function onCurrentItemChanged(current, total, sourceUrl) {
            var previousCurrent = root.currentUrl
            root.currentUrl = current; root.totalUrls = total
            if (current > previousCurrent && sourceUrl !== "") { root.currentUrlStr = sourceUrl; root.currentFilename = displayLabelForUrl(sourceUrl) }
        }
        function onPausedChanged() { root.paused = processRunner.paused }
        function onNotepadStarted(relPath, total) {
            root.currentNotepad = relPath; root.totalNotepadUrls = total; root.currentNotepadUrl = 0
            ensureNotepadStats(relPath, total); updateQueuedStats(relPath, 0, total)
            addLog("Starting notepad: " + noteName(relPath) + " (" + total + " URLs)", "started")
            addNotepadLog(relPath, "Starting notepad: " + noteName(relPath) + " (" + total + " URLs)", "started")
        }
        function onNotepadUrlFinished(relPath, sourceUrl, current, total, succeeded) {
            root.currentNotepadUrl = current
            var stats = ensureNotepadStats(relPath, total); var failedUrls = stats.failedUrls
            if (!succeeded && failedUrls.indexOf(sourceUrl) < 0) failedUrls = failedUrls.concat([sourceUrl])
            updateNotepadStats(relPath, current, total, stats.succeeded + (succeeded ? 1 : 0), failedUrls)
            if (succeeded) { var completedId = displayLabelForUrl(sourceUrl); addNotepadLog(relPath, "Completed: " + completedId, "completed"); addLog("Completed: " + noteName(relPath) + " - " + completedId, "completed") }
            else { addNotepadLog(relPath, "[X] " + sourceUrl, "error"); addLog("[X] " + noteName(relPath) + " - " + sourceUrl, "error") }
        }
        function onNotepadCompleted(relPath, processed, total, failedUrls) {
            updateNotepadStats(relPath, processed, total, total - failedUrls.length, failedUrls)
            var kind = failedUrls.length === 0 ? "all-completed" : "error"
            var msg  = failedUrls.length === 0 ? "Notepad '" + noteName(relPath) + "' completed" : "Notepad '" + noteName(relPath) + "' has " + failedUrls.length + " pending URL(s)"
            addLog(msg, kind); addNotepadLog(relPath, msg, kind)
        }
    }

    Connections {
        target: processRunner
        function onClipboardLogLine(line, isError) { var kind = classifyDownloadLogKind(line, isError); addClipLog(line, kind) }
        function onClipboardRunningChanged() { if (!processRunner.clipboardRunning && root.clipMode) root.clipMode = false }
    }

    Timer { interval: 2000; repeat: true; running: true; onTriggered: { notepadMgr.refresh(); dlStats.refresh(); fileViewer.scan() } }

    // ── Selector popup ────────────────────────────────────────────────────
    Popup {
        id: selectorPopup
        modal: true; anchors.centerIn: Overlay.overlay
        width: 380; height: 170 + root.selectorVisibleRows * root.selectorRowHeight
        padding: 0; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var tempSelected: []
        onOpened: tempSelected = root.selectedFiles.slice()
        background: Rectangle {
            radius: 14
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            ThemeTransition { anchors.fill: parent; radius: parent.radius }
        }

        ColumnLayout {
            anchors.fill: parent; spacing: 0
            Rectangle {
                Layout.fillWidth: true; height: 48; radius: 14
                color: theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 8; color: parent.color
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: theme.border
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                    Text { text: "📂  Select Notepads"; color: theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 14; font.bold: true; font.family: "Segoe UI" }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 26; height: 26; radius: 6
                        color: spClose.containsMouse ? theme.red : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "✕"; color: spClose.containsMouse ? "white" : theme.textMuted; font.pixelSize: 13 }
                        MouseArea { id: spClose; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: selectorPopup.close() }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 10; spacing: 8
                AppButton { height: 28; Layout.fillWidth: true; text: "Select All"; bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 11
                    onClicked: { var arr = []; for (var i = 0; i < notepadMgr.files.length; i++) arr.push(notepadMgr.files[i].relPath); selectorPopup.tempSelected = arr } }
                AppButton { height: 28; Layout.fillWidth: true; text: "Clear All"; bgColor: theme.surfaceAlt; textColor: theme.textPrimary; textSize: 11
                    onClicked: selectorPopup.tempSelected = [] }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 8
                clip: true; spacing: 4; model: notepadMgr.files
                delegate: Rectangle {
                    required property var modelData; required property int index
                    property bool chkd: selectorPopup.tempSelected.includes(modelData.relPath)
                    width: ListView.view.width; height: 38; radius: 8
                    color: chkd ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 150 } }
                    border.color: chkd ? theme.accent : theme.border; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 10
                        Rectangle { width: 18; height: 18; radius: 4; color: chkd ? theme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            border.color: chkd ? theme.accent : theme.border; border.width: 2
                            Text { visible: chkd; anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 11; font.bold: true } }
                        Text { text: "📄 " + modelData.name; color: theme.textPrimary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 12; font.family: "Segoe UI"; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: notepadMgr.lineCount(modelData.path) + " URLs"; color: theme.textMuted; font.pixelSize: 10; font.family: "Consolas" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { var arr = selectorPopup.tempSelected.slice(); var i = arr.indexOf(modelData.relPath); if (i >= 0) arr.splice(i,1); else arr.push(modelData.relPath); selectorPopup.tempSelected = arr } }
                }
                Text { visible: notepadMgr.files.length === 0; anchors.centerIn: parent; text: "No .txt files found"; color: theme.textMuted; font.pixelSize: 12; font.family: "Segoe UI" }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8
                Text { text: selectorPopup.tempSelected.length + " / " + notepadMgr.files.length + " selected"; color: theme.textMuted; font.pixelSize: 11; font.family: "Segoe UI"; Layout.fillWidth: true }
                AppButton { width: 90; text: "Cancel"; bgColor: theme.surfaceAlt; textColor: theme.textPrimary; onClicked: selectorPopup.close() }
                AppButton { width: 110; text: "✓  Confirm"; bgColor: theme.green; enabled: selectorPopup.tempSelected.length > 0
                    onClicked: { root.selectedFiles = selectorPopup.tempSelected.slice(); selectorPopup.close() } }
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutBack } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130 } }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  MAIN LAYOUT
    // ══════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // ── Control bar ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 120; radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: root.clipMode ? theme.orange : theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            RowLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 16

                // ── EXECUTION MODE ────────────────────────────────────────
                ColumnLayout {
                    spacing: 8
                    opacity: (root.clipMode || root.running) ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text { text: "EXECUTION MODE"; color: theme.textMuted
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 10; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1 }

                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: ["All Notepads", "Custom Select"]
                            delegate: Rectangle {
                                required property string modelData; required property int index
                                property bool active: root.modeAll === (index + 1)
                                width: 170; height: 36; radius: 8
                                color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12) : theme.surfaceAlt
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: active ? theme.accent : theme.border; border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    text: index === 1 && root.selectedFiles.length > 0 ? ("Custom (" + root.selectedFiles.length + ")") : modelData
                                    color: parent.active ? theme.accent : theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 12; font.bold: parent.active; font.family: "Segoe UI"
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !root.clipMode && !root.running
                                    onClicked: { root.modeAll = index + 1; if (index === 1) selectorPopup.open() } }
                            }
                        }
                    }

                    Row {
                        spacing: 4; clip: true
                        Repeater {
                            model: root.modeAll === 1 ? notepadMgr.files.slice(0,6) : root.selectedFiles.slice(0,6).map(function(r){ return {name:r} })
                            delegate: Rectangle {
                                required property var modelData
                                height: 18; radius: 5; width: chipLabel.implicitWidth + 10
                                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3); border.width: 1
                                Text { id: chipLabel; anchors.centerIn: parent
                                    text: (modelData.name||"").split(/[\\/]/).pop().replace(".txt","")
                                    color: theme.accent; font.pixelSize: 9; font.family: "Segoe UI" }
                            }
                        }
                        Text {
                            visible: (root.modeAll === 1 ? notepadMgr.files.length : root.selectedFiles.length) > 6
                            text: "+" + ((root.modeAll === 1 ? notepadMgr.files.length : root.selectedFiles.length) - 6) + " more"
                            color: theme.textMuted; font.pixelSize: 9; font.family: "Segoe UI"
                        }
                    }
                }

                Rectangle { width: 1; height: 88; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

                // ── DELAY ─────────────────────────────────────────────────
                Column {
                    spacing: 8
                    opacity: (root.clipMode || root.running) ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text { text: "DELAY (SEC)"; color: theme.textMuted
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 10; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1 }
                    Rectangle {
                        width: 72; height: 36; radius: 8
                        color: theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        border.color: theme.border; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        TextInput {
                            id: delayInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.delaySeconds.toString(); color: theme.textPrimary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 15; font.family: "Consolas"
                            inputMethodHints: Qt.ImhDigitsOnly
                            readOnly: root.clipMode || root.running
                            onTextChanged: root.syncDelaySeconds(text)
                            onEditingFinished: root.commitDelayInput()
                            onAccepted: root.commitDelayInput()
                        }
                    }
                }

                Rectangle { width: 1; height: 88; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

                // ── ACTION BUTTONS ────────────────────────────────────────
                RowLayout {
                    spacing: 12
                    ColumnLayout {
                        spacing: 8
                        opacity: root.clipMode ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        AppButton {
                            Layout.preferredWidth: 170
                            text: root.running ? "⏳  RUNNING..." : "▶  START PROCESS"
                            bgColor: theme.green; hoverColor: "#00A870"
                            enabled: !root.running && !root.clipMode; textSize: 13
                            onClicked: beginDownloadProcess()
                        }
                        RowLayout {
                            spacing: 6
                            AppButton {
                                Layout.fillWidth: true
                                text: root.paused ? "▶  RESUME" : "⏸  PAUSE"
                                bgColor: root.paused ? theme.green : theme.orange
                                hoverColor: root.paused ? "#00A870" : "#CC7000"
                                enabled: root.running && !root.clipMode; textSize: 12
                                onClicked: toggleDownloadPause()
                            }
                            AppButton {
                                Layout.fillWidth: true
                                text: "■  STOP"; bgColor: theme.red; hoverColor: "#CC2040"
                                enabled: root.running && !root.clipMode; textSize: 12
                                onClicked: stopProcess()
                            }
                        }
                    }

                    Rectangle { width: 1; height: 88; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

                    // ── SESSION INFO ──────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6
                        opacity: root.clipMode ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Text { text: "SESSION INFO"; color: theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 9; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1 }
                        Row {
                            spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter
                                color: root.running ? theme.green : theme.textMuted
                                SequentialAnimation on opacity { running: root.running; loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 600 } NumberAnimation { to: 1.0; duration: 600 } } }
                            Text { text: root.running ? "Running · " + fmtTime(root.sessionSeconds) : "Idle"
                                color: root.running ? theme.green : theme.textMuted
                                font.pixelSize: 12; font.bold: true; font.family: "Segoe UI"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text {
                            text: root.currentNotepad !== "" ? ("📄 " + root.currentNotepad.split(/[\\/]/).pop()) : "—"
                            color: theme.accent; font.pixelSize: 10; font.family: "Segoe UI"
                        }
                        Text {
                            text: "Destination: " + appConfig.downloadRootPath.split(/[\\/]/).pop()
                            color: theme.orange; font.pixelSize: 10; font.family: "Consolas"
                        }
                    }

                    Rectangle { width: 1; height: 88; color: theme.border; Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

                    // ── CLIPBOARD MODE TOGGLE ─────────────────────────────
                    ColumnLayout {
                        spacing: 8
                        Text { text: "CLIPBOARD MODE"; color: theme.orange; font.pixelSize: 10; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1 }

                        Rectangle {
                            width: 170; height: 36; radius: 8
                            property bool canToggle: !root.running
                            color: root.clipMode
                                   ? Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.18)
                                   : (clipToggleHov.containsMouse && canToggle ? theme.surfaceAlt : theme.surfaceAlt)
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            border.color: root.clipMode ? theme.orange : theme.border; border.width: root.clipMode ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            opacity: canToggle ? 1.0 : 0.45
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: root.clipMode ? theme.orange : theme.textMuted
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    SequentialAnimation on opacity {
                                        running: root.clipMode && root.clipRunning; loops: Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 500 } NumberAnimation { to: 1.0; duration: 500 }
                                    }
                                }
                                Text {
                                    text: root.clipMode ? (root.clipRunning ? "ACTIVE" : "Starting...") : "ACTIVATE"
                                    color: root.clipMode ? theme.orange : theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 12; font.bold: true; font.family: "Segoe UI"; Layout.fillWidth: true
                                }
                                Rectangle {
                                    width: 32; height: 18; radius: 9
                                    color: root.clipMode ? theme.orange : theme.border
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    Text { anchors.centerIn: parent; text: root.clipMode ? "ON" : "OFF"; color: "white"; font.pixelSize: 9; font.bold: true }
                                }
                            }

                            MouseArea {
                                id: clipToggleHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: parent.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: parent.canToggle
                                onClicked: {
                                    if (root.clipMode) { processRunner.stopClipboard(); root.clipMode = false }
                                    else {
                                        clipLogModel.clear(); root.clipMode = true
                                        processRunner.startClipboard(appConfig.projectRootPath + "/tsr_downloader", appConfig.downloadRootPath)
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.clipMode
                                  ? (root.clipRunning ? (root.clipDownloaded + " downloaded · " + fmtTime(root.clipElapsed)) : "Waiting for process...")
                                  : "Auto-dl from clipboard"
                            color: root.clipMode ? theme.orange : theme.textMuted
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font.pixelSize: 10; font.family: "Segoe UI"
                        }
                    }
                }
            }
        }

        // ── Progress section ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: (!root.clipMode && root.running) ? 84 : 0
            Layout.minimumHeight: 0; Layout.maximumHeight: Layout.preferredHeight
            height: Layout.preferredHeight; radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            visible: height > 0 || opacity > 0; clip: true
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            opacity: (!root.clipMode && root.running) ? 1.0 : 0.0
            enabled: !root.clipMode && root.running
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutCubic } }

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 6

                RowLayout {
                    Text {
                        text: root.running
                              ? (root.currentFilename !== "" ? "📂  " + root.currentFilename : "Initializing...")
                              : (root.progress >= 1.0 ? "✅ Completed" : "No active process")
                        color: root.running ? theme.textPrimary : (root.progress >= 1.0 ? theme.green : theme.textMuted)
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font.pixelSize: 12; font.bold: true; font.family: "Segoe UI"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: root.running && root.totalUrls > 0
                        text: root.currentUrl + " / " + root.totalUrls + " total"
                        color: theme.textSecondary; font.pixelSize: 11; font.family: "Consolas"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 8; radius: 4
                    color: theme.surfaceAlt
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    Rectangle {
                        id: mainProgressFill; height: parent.height; radius: parent.radius
                        color: root.paused ? theme.orange : (root.progress >= 1.0 ? theme.green : theme.accent)
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        width: parent.width * root.progress
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        Rectangle {
                            visible: root.running && root.progress > 0 && root.progress < 1
                            anchors { top: parent.top; bottom: parent.bottom }
                            width: 80; radius: parent.radius; x: -width
                            gradient: Gradient { orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.3) }
                                GradientStop { position: 1.0; color: "transparent" } }
                            SequentialAnimation on x { running: parent.visible; loops: Animation.Infinite
                                NumberAnimation { to: mainProgressFill.width + 80; duration: 1200; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 150 } }
                        }
                    }
                }

                RowLayout {
                    visible: root.currentNotepad !== "" && root.totalNotepadUrls > 0
                    Text { text: root.currentNotepad.split(/[\\/]/).pop().replace(".txt","") + ":"; color: theme.textMuted; font.pixelSize: 10; font.family: "Segoe UI"; font.bold: true }
                    Rectangle { Layout.fillWidth: true; height: 4; radius: 2; color: theme.surfaceAlt
                        Rectangle { height: parent.height; radius: parent.radius; color: theme.green
                            width: root.totalNotepadUrls > 0 ? parent.width * (root.currentNotepadUrl / root.totalNotepadUrls) : 0
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } } }
                    Text { text: root.currentNotepadUrl + "/" + root.totalNotepadUrls; color: theme.textMuted; font.pixelSize: 10; font.family: "Consolas" }
                }

                Text { text: (root.totalUrls > 0 ? (root.currentUrl + " / " + root.totalUrls + " = ") : "") + root.currentUrlStr
                    color: theme.orange; font.pixelSize: 10; font.family: "Consolas"
                    elide: Text.ElideMiddle; Layout.fillWidth: true; maximumLineCount: 1
                    visible: root.currentUrlStr !== "" }
            }
        }

        // ── Folder row ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 96; radius: 10
            color: theme.surface
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            border.color: theme.border; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

            ThemeTransition { anchors.fill: parent; radius: parent.radius }

            RowLayout {
                anchors { fill: parent; margins: 12 } spacing: 10
                Text { text: "FOLDERS"; color: theme.textMuted
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                    font.pixelSize: 9; font.bold: true; font.family: "Segoe UI"; font.letterSpacing: 1.5
                    rotation: -90; transformOrigin: Item.Center; width: 16 }
                ListView {
                    id: folderList; Layout.fillWidth: true; Layout.fillHeight: true
                    orientation: ListView.Horizontal; spacing: 8; clip: true
                    model: dlStats.folders
                    delegate: FolderButton {
                        required property var modelData
                        height: folderList.height
                        folderName: modelData.name; folderPath: modelData.path
                        fileCount: modelData.count; sizeStr: modelData.sizeStr
                        isActive: fileViewer.watchedPath === modelData.path
                        onClicked: fileViewer.setPath(modelData.path)
                    }
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded
                        contentItem: Rectangle { radius: 3; color: theme.textMuted; opacity: 0.4 } }
                }
            }
        }

        // ── Bottom: Log + File viewer ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

            // ── Log panel ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 10
                color: theme.surface
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                border.color: root.clipMode ? theme.orange : theme.border; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                clip: true

                ThemeTransition { anchors.fill: parent; radius: parent.radius }

                ColumnLayout {
                    anchors.fill: parent; spacing: 0

                    // Log header
                    Rectangle {
                        Layout.fillWidth: true; height: 38; radius: 10
                        color: root.clipMode
                               ? Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.08)
                               : theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: root.clipMode ? theme.orange : theme.border
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: arrowHov.containsMouse ? theme.surface : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: root.logPanelExpanded ? "^" : "v"; color: theme.textMuted; font.pixelSize: 11 }
                                MouseArea { id: arrowHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.logPanelExpanded = !root.logPanelExpanded }
                            }

                            Rectangle {
                                id: logModeChip; height: 22; radius: 6; width: logModeText.implicitWidth + (root.clipMode ? 34 : 24)
                                color: root.clipMode ? Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.18) : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 300 } }
                                Text { id: logModeText; anchors.centerIn: parent
                                    text: root.clipMode ? "Clipboard Log" : "Activity Log"
                                    color: root.clipMode ? theme.orange : theme.accent
                                    font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                            }

                            Rectangle {
                                visible: root.clipMode && root.clipDownloaded > 0; Layout.leftMargin: 6
                                height: 22; radius: 11; width: clipBadgeText.implicitWidth + 20
                                color: Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: Qt.rgba(theme.orange.r, theme.orange.g, theme.orange.b, 0.3); border.width: 1
                                Text { id: clipBadgeText; anchors.centerIn: parent; text: root.clipDownloaded + " downloaded"; color: theme.orange; font.pixelSize: 10; font.family: "Consolas" }
                            }

                            Rectangle {
                                visible: !root.clipMode && viewedQueuedTotal() > 0; Layout.leftMargin: 6
                                height: 22; radius: 11; width: queuedBadgeText.implicitWidth + 18
                                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28); border.width: 1
                                Text { id: queuedBadgeText; anchors.centerIn: parent; text: "Queued " + viewedQueued() + "/" + viewedQueuedTotal() + " URLs"; color: theme.accent; font.pixelSize: 10; font.family: "Consolas" }
                            }

                            Rectangle {
                                visible: root.viewingNotepad !== "" && !root.clipMode; Layout.leftMargin: 6
                                height: 22; radius: 6; width: selectedLogText.implicitWidth + 20
                                color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.30); border.width: 1
                                Text { id: selectedLogText; anchors.centerIn: parent; text: noteName(root.viewingNotepad); color: theme.green; font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: root.viewingNotepad !== "" && !root.clipMode
                                height: 24; radius: 6; width: backText.implicitWidth + 12
                                color: backHov.containsMouse ? theme.surface : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { id: backText; anchors.centerIn: parent; text: "Global"; color: theme.accent; font.pixelSize: 10; font.family: "Segoe UI" }
                                MouseArea { id: backHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.viewingNotepad = ""; root.syncSelectedQueued() } }
                            }

                            Text { text: "Clear"; color: theme.textMuted; font.pixelSize: 10; font.family: "Segoe UI"
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.clipMode) clipLogModel.clear()
                                        else if (root.viewingNotepad === "") globalLogModel.clear()
                                        else if (root.notepadLogs[root.viewingNotepad]) root.notepadLogs[root.viewingNotepad].clear()
                                    }
                                }
                            }
                        }
                    }

                    // Notepad selector
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!root.clipMode && root.logPanelExpanded) ? notepadSelectorFlow.implicitHeight + 16 : 0
                        Layout.maximumHeight: Layout.preferredHeight; Layout.minimumHeight: 0
                        opacity: (!root.clipMode && root.logPanelExpanded) ? 1 : 0
                        clip: true; visible: height > 0 || opacity > 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Rectangle {
                            anchors.fill: parent
                            color: theme.bg
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        }
                        Flow {
                            id: notepadSelectorFlow
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 } spacing: 6
                            Rectangle {
                                height: 26; radius: 6; width: glbText.implicitWidth + 14
                                color: root.viewingNotepad === "" ? theme.accent : (glbHov.containsMouse ? theme.surfaceAlt : theme.surface)
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                border.color: root.viewingNotepad === "" ? theme.accent : theme.border; border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                Text { id: glbText; anchors.centerIn: parent; text: "All"; color: root.viewingNotepad === "" ? "white" : theme.textSecondary; font.pixelSize: 11; font.family: "Segoe UI" }
                                MouseArea { id: glbHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.viewingNotepad = ""; root.syncSelectedQueued() } }
                            }
                            Repeater {
                                model: loggedNotepadEntries()
                                delegate: Rectangle {
                                    required property var modelData
                                    property bool isViewing: root.viewingNotepad === modelData.relPath
                                    height: 26; radius: 6; width: npChipText.implicitWidth + 18
                                    color: isViewing ? theme.green : (npHov.containsMouse ? theme.surfaceAlt : theme.surface)
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    border.color: isViewing ? theme.green : theme.border; border.width: 1
                                    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    Row { anchors.centerIn: parent; spacing: 4
                                        Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: theme.green }
                                        Text { id: npChipText; text: noteName(modelData.relPath); color: isViewing ? "white" : theme.textSecondary; font.pixelSize: 10; font.family: "Segoe UI" }
                                    }
                                    MouseArea { id: npHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.viewingNotepad = modelData.relPath; root.syncSelectedQueued(); fileViewer.setPath(noteFolderPath(modelData.relPath)) } }
                                }
                            }
                        }
                    }

                    // Log list
                    ListView {
                        id: logListView
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 6
                        clip: true; spacing: 1
                        model: root.clipMode ? clipLogModel : (root.viewingNotepad === "" ? globalLogModel : (root.notepadLogs[root.viewingNotepad] || globalLogModel))
                        onCountChanged: positionViewAtEnd()

                        delegate: Rectangle {
                            required property string modelData; required property string kind
                            property string entryKind: kind || ""
                            property bool filteredOut: modelData.indexOf("Getting 'tsrdlticket'") >= 0 || modelData.indexOf("Queue is now empty") >= 0 || modelData.indexOf("Moved ") >= 0
                            property color entryColor: {
                                if (entryKind === "completed" || entryKind === "all-completed" || modelData.indexOf("Completed") >= 0 || modelData.indexOf("processed") >= 0) return theme.green
                                if (entryKind === "started"   || modelData.indexOf("Starting") >= 0 || modelData.indexOf("active") >= 0) return theme.blue
                                if (entryKind === "paused"    || modelData.indexOf("Paused") >= 0 || modelData.indexOf("Skipped duplicate") >= 0) return theme.orange
                                if (entryKind === "error"     || modelData.indexOf("[ERR]") >= 0 || modelData.indexOf("Failed") >= 0 || modelData.indexOf("pending URL") >= 0) return theme.red
                                if (modelData.indexOf("[CLIP]") >= 0) return theme.orange
                                return theme.textSecondary
                            }
                            width: logListView.width
                            height: filteredOut ? 0 : logEntryText.implicitHeight + 8
                            visible: !filteredOut; radius: 4; color: "transparent"

                            Row {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 } spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: entryColor }
                                Text { id: logEntryText; width: parent.width - 14; text: modelData; color: entryColor
                                    font.pixelSize: 11; font.family: "Consolas"; wrapMode: Text.WrapAnywhere; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { radius: 3; color: theme.textMuted; opacity: 0.5
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } } }
                    }
                }
            }

            // ── File viewer panel ─────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: root.packagePanelCollapsed ? 48 : 290
                Layout.minimumWidth:   root.packagePanelCollapsed ? 48 : 240
                Layout.maximumWidth:   root.packagePanelCollapsed ? 48 : 320
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
                    Rectangle {
                        Layout.fillWidth: true; height: 38; radius: 10
                        color: theme.surfaceAlt
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: theme.border
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            Text { text: root.packagePanelCollapsed ? "PKG" : ".package Files"; color: theme.textSecondary
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font.pixelSize: 11; font.bold: true; font.family: "Segoe UI" }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: packageArrowHover.containsMouse ? theme.surface : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: root.packagePanelCollapsed ? "<" : ">"; color: theme.textMuted; font.pixelSize: 10 }
                                MouseArea { id: packageArrowHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.packagePanelCollapsed = !root.packagePanelCollapsed }
                            }
                            AppButton { visible: !root.packagePanelCollapsed; width: 62; height: 24; text: "Open"
                                bgColor: theme.surfaceAlt; textColor: theme.textSecondary; textSize: 10
                                enabled: fileViewer.watchedPath !== ""
                                onClicked: Qt.openUrlExternally("file:///" + fileViewer.watchedPath) }
                        }
                    }

                    ListView {
                        id: fileViewList
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 6
                        visible: !root.packagePanelCollapsed; clip: true; spacing: 2; model: fileViewer.files
                        delegate: Rectangle {
                            required property var modelData; required property int index
                            width: fileViewList.width; height: 30; radius: 6
                            color: index % 2 === 0 ? "transparent" : theme.surfaceAlt
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            RowLayout { anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
                                Text { text: "PKG"; font.pixelSize: 9; color: theme.textMuted }
                                Text { text: modelData.name; color: theme.textPrimary
                                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                    font.pixelSize: 11; font.family: "Segoe UI"; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.sizeStr || (modelData.sizeKb + "K"); color: theme.textMuted; font.pixelSize: 10; font.family: "Consolas" } }
                        }
                        Text { visible: fileViewList.count === 0; anchors.centerIn: parent
                            text: fileViewer.watchedPath === "" ? "Select a folder above" : "No .package files"
                            color: theme.textMuted; font.pixelSize: 12; font.family: "Segoe UI" }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { radius: 3; color: theme.textMuted; opacity: 0.4
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } } } }
                    }

                    Item { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.packagePanelCollapsed
                        Text { anchors.centerIn: parent
                            text: fileViewer.files.length > 0 ? (fileViewer.files.length + "\nfiles") : "PKG"
                            color: fileViewer.files.length > 0 ? theme.accent : theme.textMuted
                            font.pixelSize: fileViewer.files.length > 0 ? 11 : 12; font.family: "Segoe UI"; horizontalAlignment: Text.AlignHCenter } }
                }
            }
        }
    }

    // ── File viewer helper ────────────────────────────────────────────────
    QtObject {
        id: fileViewer
        property string watchedPath: ""; property var files: []
        function setPath(p) { watchedPath = p; scan() }
        function scan() { if (watchedPath !== "") files = dlStats.filesInFolder(watchedPath) }
    }
    Timer { interval: 1500; repeat: true; running: fileViewer.watchedPath !== ""; onTriggered: fileViewer.scan() }

    // ── Download logic ────────────────────────────────────────────────────
    function beginDownloadProcess() {
        commitDelayInput()
        var relPaths = root.modeAll === 1 ? notepadMgr.allRelativePaths() : root.selectedFiles.slice()
        if (relPaths.length === 0) { addLog("[ERR] No notepads selected.", "error"); return }
        globalLogModel.clear(); root.notepadLogs = {}; root.notepadStats = {}; root.viewingNotepad = ""
        addLog("Starting downloader...", "started")
        root.progress = 0; root.sessionSeconds = 0; root.currentUrl = 0; root.totalUrls = 0
        root.currentFilename = ""; root.currentUrlStr = ""; root.currentNotepad = ""; root.currentNotepadUrl = 0; root.totalNotepadUrls = 0; root.paused = false
        appConfig.syncDownloaderConfig(appConfig.downloadRootPath)
        dlStats.takeSnapshot(); dlStats.refresh()
        processRunner.start(appConfig.projectRootPath + "/tsr_downloader", appConfig.notepadPath, relPaths, appConfig.downloadRootPath, root.delaySeconds)
    }
    function toggleDownloadPause() {
        if (processRunner.paused) { processRunner.resume(); addLog("Resumed downloader.", "started") }
        else                      { processRunner.pause();  addLog("Paused downloader.",  "paused")  }
    }
    function stopProcess() { processRunner.stop(); addLog("Stopped downloader.", "error"); root.progress = 0 }
}

