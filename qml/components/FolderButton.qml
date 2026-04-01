import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ── FolderButton ─────────────────────────────────────────────────────────────
Rectangle {
    id: folderBtn
    property string folderName: "folder"
    property string folderPath: ""
    property int    fileCount: 0
    property string sizeStr: "0 MB"
    property bool   isActive: false
    signal clicked()

    width: 120; height: 72; radius: 10
    color: isActive
           ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
           : (hov.containsMouse ? theme.surfaceAlt : theme.surface)
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    border {
        color: isActive ? theme.accent : theme.border
        width: isActive ? 2 : 1
    }
    Behavior on border.color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    ThemeTransition { anchors.fill: parent; radius: parent.radius }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 2

        Text {
            text: folderBtn.fileCount + " files"
            color: folderBtn.fileCount > 0 ? theme.green : theme.textMuted
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            font {
                pixelSize: 11
                bold: true
                family: "Segoe UI"
            }
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: folderBtn.sizeStr
            color: theme.orange
            font {
                pixelSize: 10
                family: "Segoe UI"
            }
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: "📂 " + folderBtn.folderName
            color: folderBtn.isActive ? theme.accent : theme.textPrimary
            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            font {
                pixelSize: 11
                family: "Segoe UI"
            }
            Layout.alignment: Qt.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: folderBtn.clicked()
    }
}
