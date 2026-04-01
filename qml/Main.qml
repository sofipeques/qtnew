import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt.labs.platform as Platform
import "components"
import "panels"
import "dialogs"

ApplicationWindow {
    id: root
    readonly property var appTheme:    theme
    readonly property var appSettings: appConfig

    visible: true
    width:  1300
    height: 900
    minimumWidth:  1100
    minimumHeight: 700
    title: "TRS4 Sims Orchestrator — Qt6"

    // ── Smooth background — NO flash ─────────────────────────────────────
    // We drive color through an intermediate QML property so the
    // ColorAnimation runs entirely in QML before Qt repaints the native window.
    property color _bgColor: theme.bg
    Binding on color { value: root._bgColor }

    Behavior on _bgColor {
        ColorAnimation {
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }

    // Keep _bgColor in sync whenever the theme changes
    Connections {
        target: theme
        function onDarkChanged() { root._bgColor = theme.bg }
    }

    flags: root.appSettings.alwaysOnTop
           ? Qt.Window | Qt.WindowStaysOnTopHint
           : Qt.Window

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: sidebar.sidebarWidth
            currentTab: tabView.currentIndex
            onTabRequested: function(idx) {
                tabView.setCurrentIndex(idx)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            HeaderBar {
                id: headerBar
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                currentTabIndex: tabView.currentIndex
            }

            SwipeView {
                id: tabView
                Layout.fillWidth: true
                Layout.fillHeight: true
                interactive: false
                clip: true

                HomePanel       {}
                DownloadPanel   {}
                DuplicatesPanel {}
                CopyboardPanel  {}
                NotepadPanel    {}
            }
        }
    }

    Item {
        id: collapseHandle
        z: 50
        property bool hoverLocked: false
        readonly property bool hoverVisualActive: handleMouse.containsMouse && !collapseHandle.hoverLocked && !sidebar.handleSuppressed
        x: sidebar.width - 1
        y: Math.round((root.height - height) / 2)
        width: 22
        height: 72
        opacity: sidebar.handleSuppressed ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors {
                left: parent.left
                leftMargin: 0
                verticalCenter: parent.verticalCenter
            }
            width: collapseHandle.hoverVisualActive ? 18 : 8
            height: collapseHandle.hoverVisualActive ? 28 : 44
            radius: collapseHandle.hoverVisualActive ? 8 : 4
            color: collapseHandle.hoverVisualActive
                   ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.82)
                   : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.96)
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: sidebar.collapsed ? ">" : "<"
                color: theme.textSecondary
                opacity: collapseHandle.hoverVisualActive ? 1 : 0
                font.pixelSize: 13
                font.family: "Segoe UI Symbol"
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: handleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onExited: collapseHandle.hoverLocked = false
            onClicked: {
                collapseHandle.hoverLocked = true
                sidebar.collapsed = !sidebar.collapsed
            }
        }
    }

    SettingsDialog    { id: settingsDialog }
    DestinationDialog { id: destDialog }

    Platform.FolderDialog {
        id: folderPicker
        property string targetMode: ""
        onAccepted: {
            let p = folder.toString()
            p = p.replace(/^file:\/\/\//, "")
            if (targetMode === "downloadRoot") {
                root.appSettings.downloadRootPath = p
                destDialog.close()
            } else if (targetMode === "duplicateScan") {
                dupScanner.scanPath = p
            }
        }
    }

    function openDownloadRootPicker() {
        folderPicker.targetMode = "downloadRoot"
        folderPicker.open()
    }
    function setCurrentTab(index) { tabView.setCurrentIndex(index) }
    function openDuplicatePathPicker() {
        folderPicker.targetMode = "duplicateScan"
        folderPicker.open()
    }
    function openSettings()   { settingsDialog.open() }
    function openDestDialog() { destDialog.open()     }
}
