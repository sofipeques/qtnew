#include "ClipboardMonitor.h"
#include "AppLogger.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTextStream>
#include <QDebug>
#include <QDir>

ClipboardMonitor::ClipboardMonitor(QObject* parent) : QObject(parent) {
    m_clipTimer = new QTimer(this);
    m_clipTimer->setInterval(500);
    connect(m_clipTimer, &QTimer::timeout, this, &ClipboardMonitor::checkClipboard);

    m_tickTimer = new QTimer(this);
    m_tickTimer->setInterval(1000);
    connect(m_tickTimer, &QTimer::timeout, this, &ClipboardMonitor::tickTimer);
}

void ClipboardMonitor::start(const QString& outputPath, const QStringList& allowedPrefixes) {
    if (m_active) return;

    m_outputPath      = outputPath;
    m_allowedPrefixes = allowedPrefixes;
    m_seenUrls.clear();
    m_urlCount        = 0;
    m_elapsed         = 0;
    m_paused          = false;
    m_active          = true;
    AppLogger::log("Clipboard", QString("Clipboard monitoring start requested for output: %1").arg(outputPath));

    // Capture current clipboard so first check doesn't false-trigger
    auto* clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        m_active = false;
        emit activeChanged();
        emit logMessage("[ERR] Clipboard read failed");
        AppLogger::log("Clipboard", "Clipboard read failed: QGuiApplication::clipboard() returned null.");
        return;
    }
    m_lastContent = clipboard->text().trimmed();

    const QString outputDir = QFileInfo(m_outputPath).absolutePath();
    if (!QDir(outputDir).exists()) {
        emit logMessage("[ERR] Notepad output folder not found");
        AppLogger::log("Clipboard", QString("Output folder missing before start: %1").arg(outputDir));
        if (!QDir().mkpath(outputDir)) {
            m_active = false;
            emit activeChanged();
            emit logMessage("[ERR] Could not write to uncategorized.txt");
            AppLogger::log("Clipboard", QString("Failed to create output folder: %1").arg(outputDir));
            return;
        }
        AppLogger::log("Clipboard", QString("Output folder created: %1").arg(outputDir));
    }

    QFile existing(m_outputPath);
    if (existing.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream ts(&existing);
        while (!ts.atEnd()) {
            const QString line = ts.readLine().trimmed();
            if (!line.isEmpty())
                m_seenUrls.insert(line);
        }
        existing.close();
    }

    m_clipTimer->start();
    m_tickTimer->start();

    emit activeChanged();
    emit urlCountChanged();
    emit elapsedChanged();
    emit logMessage("Clipboard started. Waiting for URLs.");
    AppLogger::log("Clipboard", "Clipboard monitoring started.");
}

void ClipboardMonitor::pause() {
    if (!m_active || m_paused) return;
    m_paused = true;
    emit pausedChanged();
    emit logMessage("Clipboard paused.");
    AppLogger::log("Clipboard", "Clipboard monitoring paused.");
}

void ClipboardMonitor::resume() {
    if (!m_active || !m_paused) return;
    if (auto* clipboard = QGuiApplication::clipboard())
        m_lastContent = clipboard->text().trimmed();
    m_paused = false;
    emit pausedChanged();
    emit logMessage("Clipboard resumed.");
    AppLogger::log("Clipboard", "Clipboard monitoring resumed.");
}

void ClipboardMonitor::stop() {
    if (!m_active) return;
    m_clipTimer->stop();
    m_tickTimer->stop();
    m_active = false;
    m_paused = false;
    emit activeChanged();
    emit pausedChanged();
    emit logMessage("Clipboard stopped.");
    AppLogger::log("Clipboard", "Clipboard monitoring stopped.");
}

void ClipboardMonitor::checkClipboard() {
    static const QRegularExpression strictTsrUrlRe(
        R"(https?://(?:www\.)?thesimsresource\.com/(?:members/[^/\s"'<>]+/)?downloads/details(?:/[^/\s"'<>]+)*/id/\d+/?$)",
        QRegularExpression::CaseInsensitiveOption);

    if (!m_active || m_paused) return;

    auto* clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        emit logMessage("[ERR] Clipboard read failed");
        AppLogger::log("Clipboard", "Clipboard read failed during polling.");
        return;
    }

    QString content = clipboard->text().trimmed();
    if (content == m_lastContent || content.isEmpty()) return;
    m_lastContent = content;

    bool isAllowed = false;
    for (const QString& prefix : m_allowedPrefixes) {
        if (content.startsWith(prefix)) { isAllowed = true; break; }
    }
    const bool isStrictTsrUrl = strictTsrUrlRe.match(content).hasMatch();
    if (!isStrictTsrUrl) {
        emit logMessage(QString("Not Allowed: %1").arg(content));
        AppLogger::log("Clipboard", QString("Invalid clipboard content ignored: %1").arg(content));
        return;
    }
    if (!isAllowed && !content.startsWith("https://www.thesimsresource.com", Qt::CaseInsensitive)) {
        emit logMessage(QString("Not Allowed: %1").arg(content));
        AppLogger::log("Clipboard", QString("Unsupported URL ignored: %1").arg(content));
        return;
    }
    if (m_seenUrls.contains(content)) {
        emit logMessage(QString("Skipped duplicate: %1").arg(content));
        AppLogger::log("Clipboard", QString("Duplicate URL skipped: %1").arg(content));
        return;
    }

    // Write to output file (append)
    if (!QDir().mkpath(QFileInfo(m_outputPath).absolutePath())) {
        emit logMessage("[ERR] Notepad output folder not found");
        emit logMessage("[ERR] Could not write to uncategorized.txt");
        AppLogger::log("Clipboard", QString("Could not ensure output folder for file: %1").arg(m_outputPath));
        return;
    }
    QFile f(m_outputPath);
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&f);
        ts << content << "\n";
        f.close();
    } else {
        emit logMessage("[ERR] Could not write to uncategorized.txt");
        AppLogger::log("Clipboard", QString("Failed to append captured URL to file: %1").arg(m_outputPath));
        return;
    }
    m_seenUrls.insert(content);

    m_urlCount++;
    emit urlCountChanged();
    emit urlCaptured(content);
    emit logMessage(QString("Captured URL: %1").arg(content));
    AppLogger::log("Clipboard", QString("Captured URL stored: %1").arg(content));
}

void ClipboardMonitor::tickTimer() {
    if (m_active && !m_paused) {
        m_elapsed++;
        emit elapsedChanged();
    }
}

