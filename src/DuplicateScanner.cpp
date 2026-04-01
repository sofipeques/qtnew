#include "DuplicateScanner.h"
#include "AppLogger.h"
#include <QCryptographicHash>
#include <QDirIterator>
#include <QFileInfo>
#include <QDir>
#include <QVariantMap>
#include <QFile>
#include <QDebug>
#include <QMetaObject>
#include <QMutexLocker>
#include <algorithm>

bool ScanWorker::waitIfPausedOrStopped() {
    QMutexLocker locker(&m_stateMutex);
    while (m_paused && !m_stopRequested)
        m_pauseCondition.wait(&m_stateMutex);
    return m_stopRequested;
}

void ScanWorker::pause() {
    QMutexLocker locker(&m_stateMutex);
    m_paused = true;
}

void ScanWorker::resume() {
    QMutexLocker locker(&m_stateMutex);
    if (!m_paused)
        return;
    m_paused = false;
    m_pauseCondition.wakeAll();
}

void ScanWorker::stop() {
    QMutexLocker locker(&m_stateMutex);
    m_stopRequested = true;
    m_paused = false;
    m_pauseCondition.wakeAll();
}

// ScanWorker
void ScanWorker::run() {
    AppLogger::log("Duplicates", QString("ScanWorker started for path: %1").arg(m_path));
    emit log(QString("Scanning: %1").arg(m_path));

    QStringList files;
    QDirIterator it(m_path, {"*.package"}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        if (waitIfPausedOrStopped()) {
            AppLogger::log("Duplicates", "Scan cancelled while enumerating files.");
            emit log("Scan cancelled.");
            emit finished({}, true);
            return;
        }
        files << it.next();
    }

    const int total = files.size();
    emit log(QString("Found %1 .package files").arg(total));
    AppLogger::log("Duplicates", QString("Found %1 package files to analyze.").arg(total));

    QMap<QString, QStringList> hashMap;
    int count = 0;

    for (const QString& filePath : files) {
        if (waitIfPausedOrStopped()) {
            AppLogger::log("Duplicates", "Scan cancelled during hashing loop.");
            emit log("Scan cancelled.");
            emit finished({}, true);
            return;
        }

        QFile f(filePath);
        if (!f.open(QIODevice::ReadOnly)) {
            const QString name = QFileInfo(filePath).fileName();
            AppLogger::log("Duplicates", QString("Could not open file for hashing: %1").arg(filePath));
            emit log(QString("[ERR] Could not open file: %1").arg(name));
            count++;
            emit progress(count, total);
            continue;
        }

        QCryptographicHash hasher(QCryptographicHash::Md5);
        while (!f.atEnd()) {
            if (waitIfPausedOrStopped()) {
                f.close();
                AppLogger::log("Duplicates", "Scan cancelled while reading file contents.");
                emit log("Scan cancelled.");
                emit finished({}, true);
                return;
            }
            const QByteArray chunk = f.read(65536);
            if (chunk.isNull()) {
                const QString name = QFileInfo(filePath).fileName();
                AppLogger::log("Duplicates", QString("Failed to hash file: %1").arg(filePath));
                emit log(QString("[ERR] Failed to hash file: %1").arg(name));
                break;
            }
            hasher.addData(chunk);
        }
        f.close();

        const QString hash = hasher.result().toHex();
        hashMap[hash].append(filePath);
        count++;
        emit progress(count, total);
    }

    QVariantList groups;
    int groupId = 1;
    for (const auto& paths : hashMap) {
        if (waitIfPausedOrStopped()) {
            AppLogger::log("Duplicates", "Scan cancelled while building duplicate groups.");
            emit log("Scan cancelled.");
            emit finished({}, true);
            return;
        }
        if (paths.size() < 2)
            continue;

        QStringList sorted = paths;
        std::sort(sorted.begin(), sorted.end(), [](const QString& a, const QString& b) {
            return QFileInfo(a).birthTime() < QFileInfo(b).birthTime();
        });

        QVariantList fileList;
        for (const QString& p : sorted) {
            QFileInfo fi(p);
            QVariantMap fm;
            fm["path"] = p;
            fm["name"] = fi.fileName();
            fm["folder"] = fi.dir().dirName();
            fm["sizeKb"] = fi.size() / 1024.0;
            fileList.append(fm);
        }

        QVariantMap group;
        group["id"] = groupId++;
        group["name"] = QFileInfo(sorted[0]).fileName();
        group["files"] = fileList;
        groups.append(group);
    }

    emit log("Scan complete.");
    if (groups.isEmpty())
        emit log("No duplicate groups found.");
    else
        emit log(QString("%1 duplicate groups found.").arg(groups.size()));
    emit finished(groups, false);
    AppLogger::log("Duplicates", QString("Scan finished with %1 duplicate groups.").arg(groups.size()));
}

// DuplicateScanner
DuplicateScanner::DuplicateScanner(QObject* parent) : QObject(parent) {}

void DuplicateScanner::startScan() {
    if (m_scanning)
        return;
    if (m_scanPath.isEmpty()) {
        AppLogger::log("Duplicates", "Start scan rejected: scan path is empty.");
        emit logMessage("[ERR] Scan path is empty");
        return;
    }
    if (!QDir(m_scanPath).exists()) {
        AppLogger::log("Duplicates", QString("Start scan rejected: scan path does not exist: %1").arg(m_scanPath));
        emit logMessage("[ERR] Scan path does not exist");
        return;
    }

    m_scanning = true;
    m_paused = false;
    m_progress = 0.0;
    m_progressText = "Starting...";
    m_groups.clear();
    emit scanningChanged();
    emit pausedChanged();
    emit progressChanged();
    emit groupsChanged();
    AppLogger::log("Duplicates", QString("Starting duplicate scan at path: %1").arg(m_scanPath));

    auto* worker = new ScanWorker(m_scanPath);
    m_worker = worker;
    m_thread = new QThread(this);
    worker->moveToThread(m_thread);

    connect(m_thread, &QThread::started, worker, &ScanWorker::run);
    connect(worker, &ScanWorker::progress, this, &DuplicateScanner::onProgress);
    connect(worker, &ScanWorker::log, this, &DuplicateScanner::logMessage);
    connect(worker, &ScanWorker::finished, this, &DuplicateScanner::onFinished);
    connect(worker, &ScanWorker::finished, m_thread, &QThread::quit);
    connect(m_thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(m_thread, &QThread::finished, m_thread, &QObject::deleteLater);
    connect(m_thread, &QThread::finished, this, [this]() {
        m_thread = nullptr;
        m_worker = nullptr;
    });

    m_thread->start();
}

void DuplicateScanner::pauseScan() {
    if (!m_scanning || m_paused || !m_worker)
        return;

    m_paused = true;
    m_progressText = "Paused";
    emit pausedChanged();
    emit progressChanged();
    m_worker->pause();
    emit logMessage("Scan paused.");
    AppLogger::log("Duplicates", "Pause requested.");
}

void DuplicateScanner::resumeScan() {
    if (!m_scanning || !m_paused || !m_worker)
        return;

    m_paused = false;
    emit pausedChanged();
    m_worker->resume();
    emit logMessage("Scan resumed.");
    AppLogger::log("Duplicates", "Resume requested.");
}

void DuplicateScanner::stopScan() {
    if (!m_scanning || !m_worker)
        return;

    m_paused = false;
    m_progressText = "Cancelling...";
    emit pausedChanged();
    emit progressChanged();
    m_worker->stop();
    AppLogger::log("Duplicates", "Stop requested.");
}

void DuplicateScanner::onProgress(int current, int total) {
    if (total > 0 && !m_paused) {
        m_progress = static_cast<double>(current) / total;
        m_progressText = QString("Scanning: %1 / %2 (%3%)")
            .arg(current)
            .arg(total)
            .arg(qRound(m_progress * 100));
        emit progressChanged();
    }
}

void DuplicateScanner::onFinished(const QVariantList& groups, bool cancelled) {
    if (!cancelled) {
        m_groups = groups;
        emit groupsChanged();
    }
    m_scanning = false;
    m_paused = false;
    m_progress = cancelled ? 0.0 : 1.0;
    m_progressText = cancelled ? "Cancelled" : QString("Done - %1 groups found").arg(groups.size());
    AppLogger::log("Duplicates", cancelled ? "Scan finished as cancelled." : QString("Scan finished successfully with %1 groups.").arg(groups.size()));
    emit scanningChanged();
    emit pausedChanged();
    emit progressChanged();
}

void DuplicateScanner::deleteFiles(const QStringList& paths) {
    for (const QString& p : paths) {
        if (QFile::remove(p))
            emit logMessage(QString("Deleted: %1").arg(QFileInfo(p).fileName()));
        else {
            emit logMessage(QString("Could not delete: %1").arg(p));
            emit logMessage(QString("[ERR] Could not delete: %1").arg(p));
            AppLogger::log("Duplicates", QString("Could not delete file: %1").arg(p));
        }
    }

    QVariantList updated;
    for (const QVariant& gv : m_groups) {
        QVariantMap g = gv.toMap();
        QVariantList files = g["files"].toList();
        QVariantList remaining;
        for (const QVariant& fv : files) {
            const QString p = fv.toMap()["path"].toString();
            if (!paths.contains(p))
                remaining.append(fv);
        }
        if (remaining.size() >= 2) {
            g["files"] = remaining;
            updated.append(g);
        }
    }
    m_groups = updated;
    emit groupsChanged();
}
