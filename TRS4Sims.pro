QT += quick quickcontrols2 network concurrent widgets

CONFIG += c++17

SOURCES += \
    src/main.cpp \
    src/AppConfig.cpp \
    src/ProcessRunner.cpp \
    src/DuplicateScanner.cpp \
    src/ClipboardMonitor.cpp \
    src/NotepadManager.cpp \
    src/DownloadStats.cpp \
    src/ThemeManager.cpp

HEADERS += \
    src/AppConfig.h \
    src/ProcessRunner.h \
    src/DuplicateScanner.h \
    src/ClipboardMonitor.h \
    src/NotepadManager.h \
    src/DownloadStats.h \
    src/ThemeManager.h

QML_FILES += \
    qml/Main.qml \
    qml/components/Sidebar.qml \
    qml/components/StatCard.qml \
    qml/components/AnimatedProgressBar.qml \
    qml/components/LogViewer.qml \
    qml/components/FolderButton.qml \
    qml/components/ToggleSwitch.qml \
    qml/panels/HomePanel.qml \
    qml/panels/DownloadPanel.qml \
    qml/panels/DuplicatesPanel.qml \
    qml/panels/CopyboardPanel.qml \
    qml/panels/NotepadPanel.qml \
    qml/dialogs/SettingsDialog.qml \
    qml/dialogs/DestinationDialog.qml \
    qml/dialogs/CategorySelectorDialog.qml

resources.files = $$QML_FILES
resources.prefix = /qt/qml/TRS4Sims

RESOURCES += resources

# Default rules for deployment
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

RC_ICONS = resources/icons/app.ico
