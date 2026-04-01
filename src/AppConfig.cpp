#include "AppConfig.h"
#include "AppLogger.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QApplication>
#include <QDebug>

AppConfig::AppConfig(QObject* parent) : QObject(parent) {
    // Detect project root: the folder containing tsr_downloader/
    // We look upward from the executable until we find it, or use exe dir
    QDir dir(QCoreApplication::applicationDirPath());
    m_projectRootPath = dir.absolutePath();

    // Walk up max 5 levels looking for tsr_downloader directory
    for (int i = 0; i < 5; ++i) {
        if (QDir(dir.filePath("tsr_downloader")).exists()) {
            m_projectRootPath = dir.absolutePath();
            break;
        }
        if (!dir.cdUp()) break;
    }

    AppLogger::log("Config", QString("Project root resolved to %1").arg(m_projectRootPath));
    ensureProjectLayout();
    load();
}

void AppConfig::ensureProjectLayout() {
    QDir root(m_projectRootPath);
    for (const QString& sub : {"data/notepad", "data/ropa", "downloads", "tsr_downloader"}) {
        root.mkpath(sub);
        AppLogger::log("Config", QString("Ensured project subdirectory exists: %1").arg(root.filePath(sub)));
    }
}

QString AppConfig::configFilePath() const {
    return QDir(m_projectRootPath).filePath("data/config_user.json");
}

QString AppConfig::allowedUrlsFilePath() const {
    return QDir(m_projectRootPath).filePath("data/allowed_urls.json");
}

QString AppConfig::notepadPath() const {
    return QDir(m_projectRootPath).filePath("data/notepad");
}

void AppConfig::load() {
    AppLogger::log("Config", QString("Loading configuration from %1").arg(configFilePath()));
    loadAllowedUrls();

    QFile f(configFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        // Use defaults, save them
        if (m_downloadRootPath.isEmpty())
            m_downloadRootPath = QDir(m_projectRootPath).filePath("downloads");
        AppLogger::log("Config", "Config file not found; using defaults and saving new config.");
        save();
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
    f.close();
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        AppLogger::log("Config", QString("Failed to parse config JSON: %1").arg(parseError.errorString()));
        if (m_downloadRootPath.isEmpty())
            m_downloadRootPath = QDir(m_projectRootPath).filePath("downloads");
        save();
        return;
    }
    QJsonObject obj = doc.object();

    m_darkMode           = obj["modo_oscuro"].toBool(false);
    m_soundOnFinish      = obj["sonido_al_finalizar"].toBool(true);
    m_alwaysOnTop        = obj["siempre_visible"].toBool(false);
    m_popupOnFinish      = obj["popup_al_finalizar"].toBool(true);
    m_autoScanDuplicates = obj["autoscan_duplicados"].toBool(false);
    m_autoCategorize     = obj["categorizacion_automatica"].toBool(false);
    m_homeQuickActionsExpanded = obj.contains("home_quick_actions_expanded")
                                 ? obj["home_quick_actions_expanded"].toBool(true)
                                 : true;
    m_homeModulesExpanded = obj.contains("home_modules_expanded")
                            ? obj["home_modules_expanded"].toBool(true)
                            : true;

    QString savedPath = obj["download_root_path"].toString();
    if (!savedPath.isEmpty() && QDir(savedPath).exists())
        m_downloadRootPath = normalizePath(savedPath);
    else
        m_downloadRootPath = QDir(m_projectRootPath).filePath("downloads");

    QDir().mkpath(m_downloadRootPath);
    syncDownloaderConfig(m_downloadRootPath);
    AppLogger::log("Config", QString("Configuration loaded. DarkMode=%1, AutoCategorize=%2, DownloadRoot=%3, AllowedUrls=%4")
                                  .arg(m_darkMode)
                                  .arg(m_autoCategorize)
                                  .arg(m_downloadRootPath)
                                  .arg(m_allowedUrls.size()));
}

void AppConfig::save() {
    QJsonObject obj;
    obj["modo_oscuro"]               = m_darkMode;
    obj["sonido_al_finalizar"]       = m_soundOnFinish;
    obj["siempre_visible"]           = m_alwaysOnTop;
    obj["popup_al_finalizar"]        = m_popupOnFinish;
    obj["autoscan_duplicados"]       = m_autoScanDuplicates;
    obj["categorizacion_automatica"] = m_autoCategorize;
    obj["home_quick_actions_expanded"] = m_homeQuickActionsExpanded;
    obj["home_modules_expanded"]       = m_homeModulesExpanded;
    obj["download_root_path"]        = m_downloadRootPath;

    QFile f(configFilePath());
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
        AppLogger::log("Config", QString("Configuration saved to %1").arg(configFilePath()));
    } else {
        AppLogger::log("Config", QString("Failed to save configuration to %1").arg(configFilePath()));
    }
}

void AppConfig::syncDownloaderConfig(const QString& destPath) {
    QString cfgPath = QDir(m_projectRootPath).filePath("tsr_downloader/config.json");
    QJsonObject cfg;
    QFile f(cfgPath);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
        if (parseError.error == QJsonParseError::NoError && doc.isObject())
            cfg = doc.object();
        else
            AppLogger::log("Config", QString("Failed to parse downloader config JSON at %1: %2").arg(cfgPath).arg(parseError.errorString()));
        f.close();
    }
    QString normalized = normalizePath(destPath);
    QDir().mkpath(normalized);
    cfg["downloadDirectory"] = normalized.replace("\\", "/");

    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(cfg).toJson(QJsonDocument::Indented));
        AppLogger::log("Config", QString("Synced downloader config %1 to downloadDirectory=%2").arg(cfgPath).arg(normalized));
    } else {
        AppLogger::log("Config", QString("Failed to write downloader config %1").arg(cfgPath));
    }
}

QString AppConfig::normalizePath(const QString& path) const {
    QString p = path.trimmed();
    p.remove('"'); p.remove('\'');
    if (p.isEmpty()) return QString();
    return QDir::toNativeSeparators(QDir(p).absolutePath());
}

void AppConfig::beep() const {
    QApplication::beep();
}

void AppConfig::loadAllowedUrls() {
    QFile f(allowedUrlsFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        m_allowedUrls = {"https://www.thesimsresource.com"};
        AppLogger::log("Config", QString("Allowed URLs file missing; using default list for %1").arg(allowedUrlsFilePath()));
        return;
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
    f.close();
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        m_allowedUrls = {"https://www.thesimsresource.com"};
        AppLogger::log("Config", QString("Failed to parse allowed URLs file %1: %2").arg(allowedUrlsFilePath()).arg(parseError.errorString()));
        return;
    }
    QJsonObject obj = doc.object();

    // Support both "allowed_urls" (list) and "urls_permitidas" (string)
    if (obj.contains("allowed_urls")) {
        QJsonArray arr = obj["allowed_urls"].toArray();
        for (const auto& v : arr) m_allowedUrls.append(v.toString());
    } else if (obj.contains("urls_permitidas")) {
        m_allowedUrls = {obj["urls_permitidas"].toString()};
    }
    if (m_allowedUrls.isEmpty())
        m_allowedUrls = {"https://www.thesimsresource.com"};
    AppLogger::log("Config", QString("Loaded %1 allowed URL prefixes from %2").arg(m_allowedUrls.size()).arg(allowedUrlsFilePath()));
}

// Setters with save-on-change
void AppConfig::setDarkMode(bool v)           { if(m_darkMode==v) return; m_darkMode=v; save(); emit darkModeChanged(); }
void AppConfig::setSoundOnFinish(bool v)      { if(m_soundOnFinish==v) return; m_soundOnFinish=v; save(); emit soundOnFinishChanged(); }
void AppConfig::setAlwaysOnTop(bool v)        { if(m_alwaysOnTop==v) return; m_alwaysOnTop=v; save(); emit alwaysOnTopChanged(); }
void AppConfig::setPopupOnFinish(bool v)      { if(m_popupOnFinish==v) return; m_popupOnFinish=v; save(); emit popupOnFinishChanged(); }
void AppConfig::setAutoScanDuplicates(bool v) { if(m_autoScanDuplicates==v) return; m_autoScanDuplicates=v; save(); emit autoScanDuplicatesChanged(); }
void AppConfig::setAutoCategorize(bool v)     { if(m_autoCategorize==v) return; m_autoCategorize=v; save(); emit autoCategorizeChanged(); }
void AppConfig::setHomeQuickActionsExpanded(bool v) {
    if (m_homeQuickActionsExpanded == v) return;
    m_homeQuickActionsExpanded = v;
    save();
    emit homeQuickActionsExpandedChanged();
}
void AppConfig::setHomeModulesExpanded(bool v) {
    if (m_homeModulesExpanded == v) return;
    m_homeModulesExpanded = v;
    save();
    emit homeModulesExpandedChanged();
}
void AppConfig::setDownloadRootPath(const QString& v) {
    QString n = normalizePath(v);
    if(m_downloadRootPath==n) return;
    m_downloadRootPath=n;
    save();
    syncDownloaderConfig(n);
    emit downloadRootPathChanged();
}
