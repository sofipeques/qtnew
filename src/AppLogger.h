#pragma once

#include <QString>

class AppLogger {
public:
    static void initialize(const QString& projectRootPath);
    static void log(const QString& category, const QString& message);
    static QString logFilePath();
    static QString homeHistoryLogFilePath();
};
