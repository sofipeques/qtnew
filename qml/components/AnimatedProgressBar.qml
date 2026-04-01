import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ── AnimatedProgressBar ──────────────────────────────────────────────────────
Rectangle {
    id: progressRoot
    property real value: 0          // 0.0 – 1.0
    property string label: ""
    property color barColor: theme.accent
    property bool animated: true

    height: 6
    radius: 3
    color: theme.surfaceAlt

    Rectangle {
        id: fill
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: progressRoot.animated
               ? fill.width  // driven by behavior
               : progressRoot.width * progressRoot.value
        radius: parent.radius
        color: progressRoot.barColor

        Behavior on width {
            enabled: progressRoot.animated
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    onValueChanged: {
        if (animated) fill.width = progressRoot.width * progressRoot.value
    }
    onWidthChanged: {
        fill.width = progressRoot.width * progressRoot.value
    }

    // Shimmer effect while running
    Rectangle {
        id: shimmer
        visible: progressRoot.value > 0 && progressRoot.value < 1
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        width: 60; radius: parent.radius
        x: -width
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.25) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on x {
            running: shimmer.visible
            loops: Animation.Infinite
            NumberAnimation { to: progressRoot.width + shimmer.width; duration: 1400; easing.type: Easing.InOutSine }
            PauseAnimation  { duration: 200 }
        }
    }
}
