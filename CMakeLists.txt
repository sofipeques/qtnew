cmake_minimum_required(VERSION 3.16)

project(TRS4Sims VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network Concurrent Widgets)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(TRS4Sims
    main.cpp
    src/AppLogger.h      src/AppLogger.cpp
    src/AppConfig.h      src/AppConfig.cpp
    src/ProcessRunner.h  src/ProcessRunner.cpp
    src/DuplicateScanner.h src/DuplicateScanner.cpp
    src/ClipboardMonitor.h src/ClipboardMonitor.cpp
    src/NotepadManager.h src/NotepadManager.cpp
    src/DownloadStats.h  src/DownloadStats.cpp
    src/ThemeManager.h   src/ThemeManager.cpp
    src/SessionHistory.h src/SessionHistory.cpp
)

qt_add_qml_module(TRS4Sims
    URI TRS4Sims
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/Sidebar.qml
        qml/components/NavItem.qml
        qml/components/HeaderBar.qml
        qml/components/StatCard.qml
        qml/components/StatCardsRow.qml
        qml/components/AnimatedProgressBar.qml
        qml/components/LogViewer.qml
        qml/components/FolderButton.qml
        qml/components/AppButton.qml
        qml/components/ToggleSwitch.qml
        qml/components/ThemeTransition.qml
        qml/panels/HomePanel.qml
        qml/panels/DownloadPanel.qml
        qml/panels/DuplicatesPanel.qml
        qml/panels/CopyboardPanel.qml
        qml/panels/NotepadPanel.qml
        qml/dialogs/SettingsDialog.qml
        qml/dialogs/DestinationDialog.qml
        qml/dialogs/CategorySelectorDialog.qml
)

target_link_libraries(TRS4Sims PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Concurrent
    Qt6::Widgets
)

if(WIN32)
    set_target_properties(TRS4Sims PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

install(TARGETS TRS4Sims
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET TRS4Sims
    OUTPUT_SCRIPT deploy_script
    MACOS_BUNDLE_POST_BUILD
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
)
install(SCRIPT ${deploy_script})
