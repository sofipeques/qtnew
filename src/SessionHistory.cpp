#include "SessionHistory.h"
#include "AppLogger.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDateTime>
#include <algorithm>

SessionHistory::SessionHistory(QObject* parent) : QObject(parent) {}

void SessionHistory::setDataPath(const QString& dataDir) {
    m_filePath = QDir(dataDir).filePath("history.json");
    AppLogger::log("History", QString("Session history data path set to %1").arg(m_filePath));
    load();
}

void SessionHistory::load() {
    m_entries.clear();
    QFile f(m_filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        AppLogger::log("History", QString("Could not open history file for reading: %1").arg(m_filePath));
        emit entriesChanged();
        return;
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
    f.close();
    if (parseError.error != QJsonParseError::NoError || !doc.isArray()) {
        AppLogger::log("History", QString("Failed to parse history file %1: %2").arg(m_filePath).arg(parseError.errorString()));
        emit entriesChanged();
        return;
    }
    QJsonArray arr = doc.array();
    for (const auto& v : arr) m_entries.append(v.toObject().toVariantMap());
    // Sort newest-first
    std::sort(m_entries.begin(), m_entries.end(), [](const QVariant& a, const QVariant& b){
        return a.toMap()["date"].toString() > b.toMap()["date"].toString();
    });
    AppLogger::log("History", QString("Loaded %1 history entries from %2").arg(m_entries.size()).arg(m_filePath));
    emit entriesChanged();
}

void SessionHistory::saveSnapshot(int fileCount, double sessionMb,
                                  int urlCaptured, int dupGroups,
                                  const QString& startTime) {
    // Load existing
    QJsonArray arr;
    QFile f(m_filePath);
    if (f.open(QIODevice::ReadOnly)) { arr = QJsonDocument::fromJson(f.readAll()).array(); f.close(); }

    QString today = QDate::currentDate().toString("yyyy-MM-dd");

    // Remove existing entry for today (replace/upsert)
    QJsonArray updated;
    for (const auto& v : arr) {
        if (v.toObject()["date"].toString() != today) updated.append(v);
    }

    // Build label: "29 Mar"
    QString label = QDate::currentDate().toString("d MMM");

    QJsonObject entry;
    entry["date"]        = today;
    entry["dateLabel"]   = label;
    entry["fileCount"]   = fileCount;
    entry["sessionMb"]   = sessionMb;
    entry["urlCaptured"] = urlCaptured;
    entry["dupGroups"]   = dupGroups;
    entry["startTime"]   = startTime;
    updated.prepend(entry);

    // Keep last 60 days
    while (updated.size() > 60) updated.removeLast();

    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(updated).toJson(QJsonDocument::Indented));
        AppLogger::log("History", QString("Saved session snapshot for %1 to %2").arg(today).arg(m_filePath));
    } else {
        AppLogger::log("History", QString("Failed to save session snapshot to %1").arg(m_filePath));
    }

    load();
}

void SessionHistory::removeEntry(const QString& dateStr) {
    QJsonArray arr;
    QFile f(m_filePath);
    if (f.open(QIODevice::ReadOnly)) { arr = QJsonDocument::fromJson(f.readAll()).array(); f.close(); }
    QJsonArray updated;
    for (const auto& v : arr)
        if (v.toObject()["date"].toString() != dateStr) updated.append(v);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(updated).toJson(QJsonDocument::Indented));
        AppLogger::log("History", QString("Removed history entry for %1 from %2").arg(dateStr).arg(m_filePath));
    } else {
        AppLogger::log("History", QString("Failed to remove history entry for %1 from %2").arg(dateStr).arg(m_filePath));
    }
    load();
}

QString SessionHistory::pointsFilePath() const {
    if (m_filePath.isEmpty())
        return QString();
    return QFileInfo(m_filePath).dir().filePath("history_points.json");
}

QVariantList SessionHistory::loadPoints() const {
    QVariantList points;
    const QString path = pointsFilePath();
    if (path.isEmpty())
        return points;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        AppLogger::log("History", QString("Could not open history points file for reading: %1").arg(path));
        return points;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
    f.close();
    if (parseError.error != QJsonParseError::NoError || !doc.isArray()) {
        AppLogger::log("History", QString("Failed to parse history points file %1: %2").arg(path).arg(parseError.errorString()));
        return points;
    }
    const QJsonArray arr = doc.array();
    for (const auto& v : arr)
        points.append(v.toObject().toVariantMap());
    AppLogger::log("History", QString("Loaded %1 history points from %2").arg(points.size()).arg(path));
    return points;
}

void SessionHistory::recordPoint(int fileCount, double sessionMb,
                                 int urlCaptured, int dupGroups,
                                 const QString& isoTimestamp) {
    if (m_filePath.isEmpty() || sessionMb <= 0.0)
        return;

    const QString path = pointsFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    QVariantList points = loadPoints();
    const QString timestamp = isoTimestamp.isEmpty()
        ? QDateTime::currentDateTime().toString(Qt::ISODate)
        : isoTimestamp;

    QVariantMap point;
    point["timestamp"] = timestamp;
    point["fileCount"] = fileCount;
    point["sessionMb"] = sessionMb;
    point["urlCaptured"] = urlCaptured;
    point["dupGroups"] = dupGroups;
    points.append(point);

    // Keep roughly the last 45 days of points.
    const QDateTime cutoff = QDateTime::currentDateTime().addDays(-45);
    QJsonArray updated;
    for (const QVariant& v : points) {
        const QVariantMap map = v.toMap();
        const QDateTime dt = QDateTime::fromString(map.value("timestamp").toString(), Qt::ISODate);
        if (!dt.isValid() || dt < cutoff)
            continue;
        updated.append(QJsonObject::fromVariantMap(map));
    }

    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(updated).toJson(QJsonDocument::Indented));
        AppLogger::log("History", QString("Recorded history point at %1 to %2").arg(timestamp).arg(path));
    } else {
        AppLogger::log("History", QString("Failed to record history point to %1").arg(path));
    }
}

QVariantList SessionHistory::seriesForRange(const QString& metricKey, int days) const {
    QVariantList out;
    if (days <= 0)
        return out;

    const QVariantList points = loadPoints();
    const QDateTime cutoff = QDateTime::currentDateTime().addDays(-days);
    for (const QVariant& v : points) {
        const QVariantMap map = v.toMap();
        const QDateTime dt = QDateTime::fromString(map.value("timestamp").toString(), Qt::ISODate);
        if (!dt.isValid() || dt < cutoff)
            continue;

        const QVariant metric = map.value(metricKey);
        if (!metric.isValid())
            continue;

        QVariantMap row;
        row["timestamp"] = map.value("timestamp");
        row["timeLabel"] = dt.toString("dd/MM HH:mm");
        row["value"] = metric;
        out.append(row);
    }
    return out;
}
