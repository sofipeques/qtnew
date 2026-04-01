import QtQuick

// ── ThemeTransition ───────────────────────────────────────────────────────────
// Drop this inside ANY Rectangle that should show the animated border shimmer
// during theme changes. It renders above all children (z: 10) but is fully
// transparent when no transition is in progress.
//
// Usage:
//   Rectangle {
//       id: myCard
//       color: theme.surface
//       Behavior on color { ColorAnimation { duration: ThemeTransition.duration } }
//       ThemeTransition { anchors.fill: parent; radius: parent.radius }
//   }
//
// The component listens to theme.transitioning and fires its own animation.

Item {
    id: root

    // Mirror the parent's corner radius so the overlay clips correctly.
    property real radius: 0

    // How long the full shimmer cycle lasts (ms). Keep in sync with ColorAnimation durations.
    readonly property int duration: 420

    // ── State ─────────────────────────────────────────────────────────────
    property bool _active: false

    Connections {
        target: theme
        function onTransitioningChanged() {
            if (theme.transitioning) {
                root._active = true
                shimmerAnim.restart()
                endTimer.restart()
            }
        }
    }

    // Auto-clear after the animation completes + a small buffer
    Timer {
        id: endTimer
        interval: root.duration + 80
        repeat: false
        onTriggered: {
            root._active = false
            theme.endTransition()
        }
    }

    // ── Shimmer border overlay ────────────────────────────────────────────
    // A rounded rectangle whose border animates from transparent → grey → transparent
    Rectangle {
        id: shimmerBorder
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root._active ? 1.5 : 0
        border.color: shimmerColor.value
        opacity: root._active ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 60 } }
        Behavior on border.width { NumberAnimation { duration: 80 } }
    }

    // Animated colour: transparent → light grey → transparent
    QtObject {
        id: shimmerColor
        property color value: "transparent"
        SequentialAnimation on value {
            id: shimmerAnim
            running: false
            loops: 1
            ColorAnimation {
                from: "transparent"
                to:   "#AAAAAA"
                duration: root.duration * 0.35
                easing.type: Easing.OutCubic
            }
            ColorAnimation {
                from: "#AAAAAA"
                to:   "transparent"
                duration: root.duration * 0.65
                easing.type: Easing.InCubic
            }
        }
    }

    // Make this overlay non-interactive — clicks pass through to children
    enabled: false
    // Always on top of siblings
    z: 10
}
