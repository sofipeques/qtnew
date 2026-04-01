#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QDate>
#include <QVariant>

/**
 * SessionHistory — saves/loads daily session snapshots to data/history.json
 *
 * Each entry: { date, dateLabel, fileCount, sessionMb, urlCaptured, dupGroups, startTime }
 * Called from QML via historyMgr context property.
 */
class SessionHistory : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)

public:
    explicit SessionHistory(QObject* parent = nullptr);

    QVariantList entries() const { return m_entries; }

    Q_INVOKABLE void setDataPath(const QString& dataDir);

    // Save today's snapshot (call when session ends or on demand)
    Q_INVOKABLE void saveSnapshot(int fileCount, double sessionMb,
                                  int urlCaptured, int dupGroups,
                                  const QString& startTime);

    // Load all entries from JSON
    Q_INVOKABLE void load();

    // Persist a time-series point for chart ranges (3/7/15/30 days).
    Q_INVOKABLE void recordPoint(int fileCount, double sessionMb,
                                 int urlCaptured, int dupGroups,
                                 const QString& isoTimestamp = QString());

    // Return [{timestamp, timeLabel, value}] for the requested metric/range.
    Q_INVOKABLE QVariantList seriesForRange(const QString& metricKey, int days) const;

    // Delete a specific entry by date string
    Q_INVOKABLE void removeEntry(const QString& dateStr);

signals:
    void entriesChanged();

private:
    QString      m_filePath;
    QVariantList m_entries;   // newest first

    QString pointsFilePath() const;
    QVariantList loadPoints() const;
};
