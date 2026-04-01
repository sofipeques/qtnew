import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: theme.surface
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    property int currentTab: 0
    property int hoveredTab: -1
    property bool collapsed: false
    property bool handleSuppressed: false
    property real expandedWidth: 260
    property real collapsedWidth: 84
    property real sidebarWidth: collapsed ? collapsedWidth : expandedWidth
    signal tabRequested(int idx)

    Behavior on sidebarWidth { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

    // Shimmer overlay for the whole sidebar panel
    ThemeTransition { anchors.fill: parent; radius: 0 }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: theme.border
        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    }

    Timer {
        id: handleRevealTimer
        interval: 260
        repeat: false
        onTriggered: root.handleSuppressed = false
    }

    onCurrentTabChanged: {
        root.handleSuppressed = true
        handleRevealTimer.restart()
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 0
        }
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: "transparent"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 20
                    rightMargin: 16
                }
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: theme.accent
                    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "S4"
                        color: "white"
                        font {
                            pixelSize: 14
                            bold: true
                            family: "Segoe UI"
                        }
                    }
                }

                Column {
                    opacity: root.collapsed ? 0 : 1
                    visible: opacity > 0
                    spacing: 1
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Text {
                        text: "Package Hub"
                        color: theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font {
                            pixelSize: 14
                            bold: true
                            family: "Segoe UI"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: "transparent"

                    Canvas {
                        id: settingsGear
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        opacity: settBtn.containsMouse ? 1.0 : 0.82
                        scale: settBtn.containsMouse ? 1.06 : 1.0
                        smooth: true
                        antialiasing: true
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var w = width
                            var h = height
                            var cx = w / 2
                            var cy = h / 2
                            var teeth = 8
                            var innerTooth = 5.8
                            var outerTooth = 8.4
                            var bodyRadius = 6.4
                            var holeRadius = 3.1
                            var rotation = -Math.PI / 2
                            var step = Math.PI / teeth
                            var gearColor = Qt.rgba(theme.textSecondary.r, theme.textSecondary.g, theme.textSecondary.b, 1)

                            if (settBtn.containsMouse) {
                                ctx.save()
                                ctx.beginPath()
                                ctx.arc(cx, cy, 9.6, 0, Math.PI * 2)
                                ctx.fillStyle = Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                                ctx.fill()
                                ctx.restore()
                            }

                            ctx.beginPath()
                            for (var i = 0; i < teeth * 2; ++i) {
                                var angle = rotation + i * step
                                var radius = (i % 2 === 0) ? outerTooth : innerTooth
                                var x = cx + Math.cos(angle) * radius
                                var y = cy + Math.sin(angle) * radius
                                if (i === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                            }
                            ctx.closePath()
                            ctx.fillStyle = gearColor
                            ctx.fill()

                            ctx.beginPath()
                            ctx.arc(cx, cy, bodyRadius, 0, Math.PI * 2)
                            ctx.fillStyle = gearColor
                            ctx.fill()

                            ctx.beginPath()
                            ctx.arc(cx, cy, holeRadius, 0, Math.PI * 2)
                            ctx.globalCompositeOperation = "destination-out"
                            ctx.fill()
                            ctx.globalCompositeOperation = "source-over"
                        }

                        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    Connections {
                        target: theme
                        function onTextSecondaryChanged() { settingsGear.requestPaint() }
                        function onAccentChanged() { settingsGear.requestPaint() }
                    }

                    states: [
                        State {
                            name: "hovered"
                            when: settBtn.containsMouse
                            PropertyChanges { target: settingsGear; opacity: 1.0; scale: 1.06 }
                        }
                    ]

                    MouseArea {
                        id: settBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: settingsGear.requestPaint()
                        onExited: settingsGear.requestPaint()
                        onClicked: {
                            var w = root.Window.window
                            if (w) w.openSettings()
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.border
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        }

        Item { Layout.preferredHeight: 12 }

        Repeater {
            model: [
                { icon: "H", label: "Inicio",     sub: "Overview & Actions" },
                { icon: "D", label: "Downloads",  sub: "Process & Monitor"  },
                { icon: "U", label: "Duplicates", sub: "Find & Clean"       },
                { icon: "C", label: "Clipboard",  sub: "URL Capture"        },
                { icon: "N", label: "Notepads",   sub: "File Viewer"        }
            ]

            delegate: NavItem {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                icon: modelData.icon
                label: modelData.label
                subtext: modelData.sub
                active: root.currentTab === index
                hovered: root.hoveredTab === index
                collapsed: root.collapsed
                onClicked: root.tabRequested(index)
                onHoverStateChanged: function(hoveredNow) {
                    if (hoveredNow) root.hoveredTab = index
                    else if (root.hoveredTab === index) root.hoveredTab = -1
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.border
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        }

        // ── Downloads footer ─────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.collapsed ? 0 : 92
            Layout.maximumHeight: Layout.preferredHeight
            opacity: root.collapsed ? 0 : 1
            clip: true
            visible: Layout.preferredHeight > 0 || opacity > 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors {
                    fill: parent
                    margins: 12
                }
                radius: 14
                color: theme.surfaceAlt
                border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 8

                    RowLayout {
                        spacing: 8

                        Item {
                            visible: false
                            width: 0
                            height: 0
                        }

                        Text {
                            text: "Downloads"
                            color: theme.textPrimary
                            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                            font {
                                pixelSize: 11
                                bold: true
                                family: "Segoe UI"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 62
                            height: 24
                            radius: 7
                            color: changeMouse.containsMouse
                                   ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                                   : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.30)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "Change"
                                color: theme.accent
                                Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                                font {
                                    pixelSize: 10
                                    bold: true
                                    family: "Segoe UI"
                                }
                            }

                            MouseArea {
                                id: changeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var w = root.Window.window
                                    if (w) w.openDestDialog()
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        text: appConfig.downloadRootPath
                        color: theme.accent
                        Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                        font {
                            pixelSize: 10
                            family: "Consolas"
                        }
                        elide: Text.ElideLeft
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
}
