#include "AppLogger.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QTextStream>

namespace {
QMutex g_logMutex;
QString g_logFilePath;
QString g_homeHistoryLogFilePath;

bool usesHomeHistoryLog(const QString& category)
{
    return category == "Home" || category == "History";
}
}

void AppLogger::initialize(const QString& projectRootPath) {
    QMutexLocker locker(&g_logMutex);
    const QString logsDir = QDir(projectRootPath).filePath("data/logs");
    QDir().mkpath(logsDir);
    g_logFilePath = QDir(logsDir).filePath("app_debug.log");
    g_homeHistoryLogFilePath = QDir(logsDir).filePath("home_history.log");
}

void AppLogger::log(const QString& category, const QString& message) {
    QMutexLocker locker(&g_logMutex);
    const QString targetPath = usesHomeHistoryLog(category) ? g_homeHistoryLogFilePath : g_logFilePath;
    if (targetPath.isEmpty())
        return;

    QFile file(targetPath);
    if (!file.open(QIODevice::Append | QIODevice::Text))
        return;

    QTextStream out(&file);
    out << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz")
        << " [" << category << "] "
        << message << "\n";
}

QString AppLogger::logFilePath() {
    QMutexLocker locker(&g_logMutex);
    return g_logFilePath;
}

QString AppLogger::homeHistoryLogFilePath() {
    QMutexLocker locker(&g_logMutex);
    return g_homeHistoryLogFilePath;
}
