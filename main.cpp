#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QString>
#include <QDir>

#include "src/AppConfig.h"
#include "src/AppLogger.h"
#include "src/DownloadStats.h"
#include "src/ProcessRunner.h"
#include "src/DuplicateScanner.h"
#include "src/ClipboardMonitor.h"
#include "src/NotepadManager.h"
#include "src/ThemeManager.h"
#include "src/SessionHistory.h"

int main(int argc, char *argv[])
{
    QApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QApplication app(argc, argv);
    app.setApplicationName("TRS4 Sims Orchestrator");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("TRS4Sims");

    QQuickStyle::setStyle("Basic");

    AppConfig        config;
    AppLogger::initialize(config.projectRootPath());
    ThemeManager     theme;
    ProcessRunner    runner;
    DuplicateScanner dupScanner;
    ClipboardMonitor clipboard;
    NotepadManager   notepad;
    DownloadStats    dlStats;
    SessionHistory   history;

    theme.setDark(config.darkMode());
    QObject::connect(&theme, &ThemeManager::darkChanged, [&](){
        config.setDarkMode(theme.dark());
    });

    dupScanner.setScanPath(config.downloadRootPath());
    notepad.setBasePath(config.notepadPath());
    dlStats.setRootPath(config.downloadRootPath());
    history.setDataPath(QDir(config.projectRootPath()).filePath("data"));

    QObject::connect(&config, &AppConfig::downloadRootPathChanged, [&](){
        dupScanner.setScanPath(config.downloadRootPath());
        dlStats.setRootPath(config.downloadRootPath());
    });

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("appConfig",    &config);
    engine.rootContext()->setContextProperty("theme",        &theme);
    engine.rootContext()->setContextProperty("processRunner",&runner);
    engine.rootContext()->setContextProperty("dupScanner",   &dupScanner);
    engine.rootContext()->setContextProperty("clipMonitor",  &clipboard);
    engine.rootContext()->setContextProperty("notepadMgr",   &notepad);
    engine.rootContext()->setContextProperty("dlStats",      &dlStats);
    engine.rootContext()->setContextProperty("historyMgr",   &history);

    const QUrl url(QStringLiteral("qrc:/qt/qml/TRS4Sims/qml/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}
