#pragma once
#include <QObject>
#include <QThread>
#include <QVariantList>
#include <QStringList>
#include <QMap>
#include <QMutex>
#include <QWaitCondition>

// Worker that runs in a background thread
class ScanWorker : public QObject {
    Q_OBJECT
public:
    explicit ScanWorker(const QString& path, QObject* parent = nullptr)
        : QObject(parent), m_path(path) {}

public slots:
    void run();
    void pause();
    void resume();
    void stop();

signals:
    void progress(int current, int total);
    void log(const QString& msg);
    void finished(const QVariantList& groups, bool cancelled);

private:
    bool waitIfPausedOrStopped();
    QString m_path;
    QMutex m_stateMutex;
    QWaitCondition m_pauseCondition;
    bool m_paused = false;
    bool m_stopRequested = false;
};

// Controller exposed to QML
class DuplicateScanner : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString progressText READ progressText NOTIFY progressChanged)
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)
    Q_PROPERTY(QString scanPath READ scanPath WRITE setScanPath NOTIFY scanPathChanged)

public:
    explicit DuplicateScanner(QObject* parent = nullptr);

    bool scanning() const    { return m_scanning; }
    bool paused() const      { return m_paused; }
    double progress() const  { return m_progress; }
    QString progressText() const { return m_progressText; }
    QVariantList groups() const  { return m_groups; }
    QString scanPath() const     { return m_scanPath; }

    void setScanPath(const QString& p) { if(m_scanPath!=p){m_scanPath=p;emit scanPathChanged();} }

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void pauseScan();
    Q_INVOKABLE void resumeScan();
    Q_INVOKABLE void stopScan();
    Q_INVOKABLE void deleteFiles(const QStringList& paths);

signals:
    void scanningChanged();
    void pausedChanged();
    void progressChanged();
    void groupsChanged();
    void scanPathChanged();
    void logMessage(const QString& msg);

private slots:
    void onProgress(int current, int total);
    void onFinished(const QVariantList& groups, bool cancelled);

private:
    bool m_scanning = false;
    bool m_paused = false;
    double m_progress = 0.0;
    QString m_progressText;
    QVariantList m_groups;
    QString m_scanPath;
    QThread* m_thread = nullptr;
    ScanWorker* m_worker = nullptr;
};
