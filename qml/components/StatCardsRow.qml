import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 12

    StatCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon: "📦"
        value: dlStats.fileCount.toString()
        label: "New Files"
        accentColor: theme.accent
    }

    StatCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon: "💾"
        value: dlStats.sessionMb.toFixed(1) + " MB"
        label: "Downloaded Size"
        accentColor: theme.orange
    }

    StatCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon: "🔗"
        value: clipMonitor.urlCount.toString()
        label: "URLs Captured"
        accentColor: theme.green
    }

    StatCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon: "♻"
        value: dupScanner.groups.length.toString()
        label: "Duplicate Groups"
        accentColor: theme.red
    }
}
