#include "ProcessRunner.h"
#include "AppLogger.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QTextStream>
#include <QTimer>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#ifndef PROCESS_SUSPEND_RESUME
#define PROCESS_SUSPEND_RESUME 0x0800
#endif
typedef LONG NTSTATUS;
typedef NTSTATUS (WINAPI *NtSuspendProcessFn)(HANDLE);
typedef NTSTATUS (WINAPI *NtResumeProcessFn)(HANDLE);
#endif

// ─────────────────────────────────────────────────────────────────────────────
ProcessRunner::ProcessRunner(QObject* parent) : QObject(parent)
{
    m_clipTickTimer = new QTimer(this);
    m_clipTickTimer->setInterval(1000);
    connect(m_clipTickTimer, &QTimer::timeout, this, &ProcessRunner::onClipTick);
    AppLogger::log("Downloads", "ProcessRunner initialized.");
}

ProcessRunner::~ProcessRunner() {
    AppLogger::log("Downloads", "ProcessRunner shutting down.");
    stop();
    stopClipboard();
}

// ═══════════════════════════════════════════════════════════════════════════
//  NOTEPAD MODE
// ═══════════════════════════════════════════════════════════════════════════

void ProcessRunner::start(const QString& workingDir,
                          const QString& notepadBasePath,
                          const QStringList& relativePaths,
                          const QString& downloadRootPath,
                          int delaySeconds)
{
    if (m_running) {
        emit logLine("A download run is already in progress.", true);
        AppLogger::log("Downloads", "Start rejected: a notepad download run is already in progress.");
        return;
    }
    if (m_clipRunning) {
        emit logLine("Stop Clipboard Mode before starting a notepad run.", true);
        AppLogger::log("Downloads", "Start rejected: clipboard mode is active.");
        return;
    }

    m_workingDir           = workingDir;
    m_notepadBasePath      = notepadBasePath;
    m_downloadRootPath     = QDir::toNativeSeparators(QDir(downloadRootPath).absolutePath());
    m_delaySeconds         = qMax(0, delaySeconds);
    m_stopRequested        = false;
    m_completedUrlsGlobal  = 0;
    m_totalUrlsAllNotepads = 0;
    m_notepadQueue.clear();
    AppLogger::log("Downloads", QString("Starting notepad run. WorkingDir=%1, NotepadBase=%2, DownloadRoot=%3, Delay=%4s, RequestedFiles=%5")
                                  .arg(m_workingDir)
                                  .arg(m_notepadBasePath)
                                  .arg(m_downloadRootPath)
                                  .arg(m_delaySeconds)
                                  .arg(relativePaths.size()));

    for (const QString& relPath : relativePaths) {
        QStringList urls = collectUrlsFromNotepad(notepadBasePath, relPath);
        if (urls.isEmpty()) {
            emit logLine(QString("No valid TSR URLs found in: %1").arg(relPath), true);
            AppLogger::log("Downloads", QString("No valid TSR URLs found in selected notepad: %1").arg(relPath));
            continue;
        }
        NotepadJob job;
        job.relPath       = relPath;
        job.urls          = urls;
        job.subfolderName = QFileInfo(relPath).baseName();
        m_notepadQueue.append(job);
        m_totalUrlsAllNotepads += urls.size();
        AppLogger::log("Downloads", QString("Queued notepad %1 with %2 valid URLs.").arg(relPath).arg(urls.size()));
    }

    if (m_notepadQueue.isEmpty()) {
        emit logLine("No valid TSR URLs were found in any selected notepad.", true);
        AppLogger::log("Downloads", "Start aborted: no valid TSR URLs were found in any selected notepad.");
        return;
    }

    m_running  = true;
    m_finished = false;
    m_paused   = false;
    emit runningChanged();
    emit finishedChanged();
    emit pausedChanged();
    emit progressUpdated(0.0);

    startNextNotepad();
}

void ProcessRunner::stop()
{
    AppLogger::log("Downloads", QString("Stop requested. Running=%1, ActiveProcess=%2, RemainingNotepads=%3")
                                  .arg(m_running)
                                  .arg(m_process != nullptr)
                                  .arg(m_notepadQueue.size()));
    m_stopRequested = true;
    m_notepadQueue.clear();

    if (m_process) {
        QProcess* p = m_process;
        m_process = nullptr;
#ifdef Q_OS_WIN
        if (m_paused) resumePid(p->processId());
#endif
        disconnect(p, nullptr, this, nullptr);
        connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                p, &QObject::deleteLater);
        p->terminate();
        AppLogger::log("Downloads", "Sent terminate() to active downloader process.");
        QTimer::singleShot(3000, p, [p]() {
            if (p->state() != QProcess::NotRunning) p->kill();
        });
    }
    finalizeRun(false);
}

void ProcessRunner::pause()
{
    if (!m_running || m_paused) return;
    m_paused = true;
    emit pausedChanged();
    AppLogger::log("Downloads", QString("Pause requested. ProcessPresent=%1").arg(m_process != nullptr));
#ifdef Q_OS_WIN
    if (m_process && !suspendPid(m_process->processId()))
        emit logLine("Pause requested, but process could not be suspended.", true);
#else
    emit logLine("Pause will take effect after current downloads finish.", false);
#endif
}

void ProcessRunner::resume()
{
    if (!m_running || !m_paused) return;
    AppLogger::log("Downloads", QString("Resume requested. ProcessPresent=%1").arg(m_process != nullptr));
#ifdef Q_OS_WIN
    if (m_process && !resumePid(m_process->processId())) {
        emit logLine("The downloader process could not be resumed.", true);
        AppLogger::log("Downloads", "Resume failed: could not resume suspended downloader process.");
        return;
    }
#endif
    m_paused = false;
    emit pausedChanged();
}

// ── Notepad: internal ─────────────────────────────────────────────────────

void ProcessRunner::startNextNotepad()
{
    if (m_stopRequested || m_notepadQueue.isEmpty()) {
        finalizeRun(!m_stopRequested);
        return;
    }

    m_currentNotepad        = m_notepadQueue.takeFirst();
    m_notepadUrlTotal       = m_currentNotepad.urls.size();
    m_notepadCompletedCount = 0;
    m_notepadStartedCount   = 0;

    const QString destDir = QDir(m_downloadRootPath).filePath(m_currentNotepad.subfolderName);
    QDir().mkpath(destDir);
    AppLogger::log("Downloads", QString("Starting next notepad job: %1, Urls=%2, Destination=%3")
                                  .arg(m_currentNotepad.relPath)
                                  .arg(m_notepadUrlTotal)
                                  .arg(destDir));

    emit notepadStarted(m_currentNotepad.relPath, m_notepadUrlTotal);
    emit logLine(
        QString("Starting notepad: %1 (%2 URLs, %3s read-delay, parallel)")
            .arg(m_currentNotepad.relPath)
            .arg(m_notepadUrlTotal)
            .arg(m_delaySeconds),
        false);

    launchNotepadProcess(m_currentNotepad.urls, destDir, m_delaySeconds);
}

void ProcessRunner::launchNotepadProcess(const QStringList& urls,
                                          const QString& destDir,
                                          int delaySeconds)
{
    if (m_process) { m_process->deleteLater(); m_process = nullptr; }

    const QString batchFilePath = QDir(m_workingDir).filePath("_current_batch.txt");
    {
        QFile batchFile(batchFilePath);
        if (!batchFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            emit logLine(QString("Could not write batch file: %1").arg(batchFilePath), true);
            AppLogger::log("Downloads", QString("Failed to write batch file: %1").arg(batchFilePath));
            finalizeRun(false);
            return;
        }
        QTextStream stream(&batchFile);
        for (const QString& url : urls)
            stream << url << "\n";
    }
    AppLogger::log("Downloads", QString("Batch file written: %1 with %2 URLs.").arg(batchFilePath).arg(urls.size()));

    m_process = new QProcess(this);
    m_process->setWorkingDirectory(m_workingDir);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    env.insert("PYTHONUTF8",       "1");
    m_process->setProcessEnvironment(env);

    connect(m_process, &QProcess::readyReadStandardOutput, this, &ProcessRunner::onReadyReadStdOut);
    connect(m_process, &QProcess::readyReadStandardError,  this, &ProcessRunner::onReadyReadStdErr);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &ProcessRunner::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        if (!m_process) return;
        emit logLine(QString("Process error (%1): %2")
                         .arg(static_cast<int>(err))
                         .arg(m_process->errorString()), true);
        AppLogger::log("Downloads", QString("Downloader process error (%1): %2")
                                      .arg(static_cast<int>(err))
                                      .arg(m_process->errorString()));
    });

    QStringList args;
    args << "main.py";
    args << "--download-dir" << destDir;
    args << "--read-delay"   << QString::number(delaySeconds);
    args << "--source-file"  << batchFilePath;
    AppLogger::log("Downloads", QString("Launching python downloader with destination %1 and delay %2s.").arg(destDir).arg(delaySeconds));

    m_process->start("python", args);

    if (!m_process->waitForStarted(4000)) {
        emit logLine(QString("Process did not start: %1").arg(m_process->errorString()), true);
        AppLogger::log("Downloads", QString("Downloader process did not start: %1").arg(m_process->errorString()));
        m_process->deleteLater();
        m_process = nullptr;
        finalizeRun(false);
        return;
    }
    AppLogger::log("Downloads", QString("Downloader process started successfully. PID=%1").arg(m_process->processId()));
}

void ProcessRunner::finalizeRun(bool completed)
{
    if (m_process) { m_process->deleteLater(); m_process = nullptr; }
    AppLogger::log("Downloads", QString("Finalizing run. Completed=%1, CompletedUrls=%2, TotalUrls=%3")
                                  .arg(completed)
                                  .arg(m_completedUrlsGlobal)
                                  .arg(m_totalUrlsAllNotepads));

    const bool wasRunning  = m_running;
    const bool wasPaused   = m_paused;
    const bool wasFinished = m_finished;

    m_running       = false;
    m_paused        = false;
    m_finished      = completed;
    m_stopRequested = false;

    if (wasRunning  != m_running)  emit runningChanged();
    if (wasPaused   != m_paused)   emit pausedChanged();
    if (wasFinished != m_finished) emit finishedChanged();

    if (completed) {
        emit progressUpdated(1.0);
        emit downloadCompleted();
        AppLogger::log("Downloads", "Download run completed successfully.");
    } else {
        AppLogger::log("Downloads", "Download run finished without completion.");
    }
}

// ── Notepad: stdout / stderr ──────────────────────────────────────────────

void ProcessRunner::onReadyReadStdOut()
{
    if (!m_process) return;
    const QStringList lines = QString::fromUtf8(m_process->readAllStandardOutput()).split('\n');

    for (const QString& rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        static const QRegularExpression readingRe(
            R"(Reading URL (\d+)/(\d+): (.+))", QRegularExpression::CaseInsensitiveOption);
        QRegularExpressionMatch rm = readingRe.match(line);
        if (rm.hasMatch()) {
            emit logLine(line, false);
            AppLogger::log("Downloads", QString("Reading URL progress: %1").arg(line));
            continue;
        }

        if (line.contains("Starting download for:", Qt::CaseInsensitive)) {
            static const QRegularExpression startingRe(
                R"(Starting download for:\s*(.+))", QRegularExpression::CaseInsensitiveOption);
            QRegularExpressionMatch sm = startingRe.match(line);
            const QString url = sm.hasMatch() ? sm.captured(1).trimmed() : QString();

            m_notepadStartedCount++;
            emit currentItemChanged(m_completedUrlsGlobal, m_totalUrlsAllNotepads, url);
            emit logLine(line, false);
            AppLogger::log("Downloads", QString("Started download for URL: %1").arg(url));
            continue;
        }

        if (line.contains("Completed download for:", Qt::CaseInsensitive)) {
            static const QRegularExpression completedRe(
                R"(Completed download for:\s*(.+))", QRegularExpression::CaseInsensitiveOption);
            QRegularExpressionMatch cm = completedRe.match(line);
            const QString url = cm.hasMatch() ? cm.captured(1).trimmed() : QString();

            m_notepadCompletedCount++;
            m_completedUrlsGlobal++;
            const double prog = m_totalUrlsAllNotepads > 0
                ? static_cast<double>(m_completedUrlsGlobal) / m_totalUrlsAllNotepads : 0.0;
            emit progressUpdated(prog);
            emit currentItemChanged(m_completedUrlsGlobal, m_totalUrlsAllNotepads, url);
            emit notepadUrlFinished(m_currentNotepad.relPath, url,
                                    m_notepadCompletedCount, m_notepadUrlTotal, true);
            emit logLine(line, false);
            AppLogger::log("Downloads", QString("Completed download for URL: %1").arg(url));
            continue;
        }

        if (line.contains("Failed download for", Qt::CaseInsensitive)) {
            static const QRegularExpression failRe(
                R"(Failed download for\s+([^\s:]+[^\s]*)\s*:)", QRegularExpression::CaseInsensitiveOption);
            QRegularExpressionMatch fm = failRe.match(line);
            const QString url = fm.hasMatch() ? fm.captured(1).trimmed() : QString();

            m_notepadCompletedCount++;
            m_completedUrlsGlobal++;
            const double prog = m_totalUrlsAllNotepads > 0
                ? static_cast<double>(m_completedUrlsGlobal) / m_totalUrlsAllNotepads : 0.0;
            emit progressUpdated(prog);
            emit currentItemChanged(m_completedUrlsGlobal, m_totalUrlsAllNotepads, url);
            emit notepadUrlFinished(m_currentNotepad.relPath, url,
                                    m_notepadCompletedCount, m_notepadUrlTotal, false);
            emit logLine(line, true);
            AppLogger::log("Downloads", QString("Failed download for URL: %1").arg(url));
            continue;
        }

        if (line.contains("All downloads have been completed", Qt::CaseInsensitive)) {
            emit logLine(line, false);
            AppLogger::log("Downloads", "Python downloader reported all downloads completed.");
            continue;
        }

        if (line.contains("Getting 'tsrdlticket'", Qt::CaseInsensitive)) continue;
        if (line.contains("Queue is now empty",    Qt::CaseInsensitive)) continue;
        if (line.contains("Moved ",                Qt::CaseInsensitive)) continue;

        const bool isErr = line.startsWith("[ERROR]") || line.startsWith("[CRITICAL]");
        emit logLine(line, isErr);
        if (isErr)
            AppLogger::log("Downloads", QString("Downloader stdout error line: %1").arg(line));
    }
}

void ProcessRunner::onReadyReadStdErr()
{
    if (!m_process) return;
    const QStringList lines = QString::fromUtf8(m_process->readAllStandardError()).split('\n');
    for (const QString& rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (!line.isEmpty()) {
            emit logLine(line, true);
            AppLogger::log("Downloads", QString("Downloader stderr: %1").arg(line));
        }
    }
}

void ProcessRunner::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    if (!m_running) return;
    AppLogger::log("Downloads", QString("Downloader process finished. ExitCode=%1, Status=%2, StopRequested=%3")
                                  .arg(exitCode)
                                  .arg(status == QProcess::CrashExit ? "CrashExit" : "NormalExit")
                                  .arg(m_stopRequested));

    emit notepadCompleted(m_currentNotepad.relPath,
                          m_notepadCompletedCount,
                          m_notepadUrlTotal,
                          QStringList());

    if (m_process) { m_process->deleteLater(); m_process = nullptr; }

    if (status == QProcess::CrashExit) {
        emit logLine("Downloader process crashed.", true);
        AppLogger::log("Downloads", "Downloader process crashed.");
        finalizeRun(false);
        return;
    }
    if (m_stopRequested) {
        AppLogger::log("Downloads", "Downloader process finished after stop request.");
        finalizeRun(false);
        return;
    }

    startNextNotepad();
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLIPBOARD MODE
// ═══════════════════════════════════════════════════════════════════════════

void ProcessRunner::startClipboard(const QString& workingDir,
                                    const QString& downloadRootPath)
{
    if (m_clipRunning) {
        AppLogger::log("Downloads", "Clipboard downloader start ignored: already running.");
        return;
    }
    if (m_running) {
        emit clipboardLogLine("Stop the notepad run before activating Clipboard Mode.", true);
        AppLogger::log("Downloads", "Clipboard downloader start rejected: notepad run is active.");
        return;
    }

    m_clipRunning    = false; // set to true after process starts
    m_clipElapsed    = 0;
    m_clipDownloaded = 0;

    const QString destDir = QDir::toNativeSeparators(QDir(downloadRootPath).absolutePath());
    AppLogger::log("Downloads", QString("Starting clipboard downloader. WorkingDir=%1, DownloadRoot=%2")
                                  .arg(workingDir)
                                  .arg(destDir));

    m_clipProcess = new QProcess(this);
    m_clipProcess->setWorkingDirectory(workingDir);
    m_clipProcess->setProcessChannelMode(QProcess::SeparateChannels);

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    env.insert("PYTHONUTF8",       "1");
    m_clipProcess->setProcessEnvironment(env);

    connect(m_clipProcess, &QProcess::readyReadStandardOutput,
            this, &ProcessRunner::onClipReadyReadStdOut);
    connect(m_clipProcess, &QProcess::readyReadStandardError,
            this, &ProcessRunner::onClipReadyReadStdErr);
    connect(m_clipProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &ProcessRunner::onClipProcessFinished);
    connect(m_clipProcess, &QProcess::errorOccurred,
            this, [this](QProcess::ProcessError err) {
                if (!m_clipProcess) return;
                emit clipboardLogLine(
                    QString("Clipboard process error (%1): %2")
                        .arg(static_cast<int>(err))
                        .arg(m_clipProcess->errorString()), true);
                AppLogger::log("Downloads", QString("Clipboard downloader process error (%1): %2")
                                              .arg(static_cast<int>(err))
                                              .arg(m_clipProcess->errorString()));
            });

    // Launch Python in legacy clipboard-loop mode (no --source-url args)
    // Override downloadDirectory via env var so Python picks it up without
    // modifying config.json on disk.
    // Alternatively we pass --download-dir and main.py uses it for clipboard mode too.
    QStringList args;
    args << "main.py";
    args << "--clipboard-mode";
    args << "--download-dir" << destDir;

    m_clipProcess->start("python", args);

    if (!m_clipProcess->waitForStarted(4000)) {
        emit clipboardLogLine(
            QString("Clipboard process did not start: %1").arg(m_clipProcess->errorString()), true);
        AppLogger::log("Downloads", QString("Clipboard downloader did not start: %1").arg(m_clipProcess->errorString()));
        m_clipProcess->deleteLater();
        m_clipProcess = nullptr;
        return;
    }

    m_clipRunning = true;
    emit clipboardRunningChanged();
    m_clipTickTimer->start();
    emit clipboardLogLine("Clipboard Mode active — copy TSR URLs to auto-download.", false);
    AppLogger::log("Downloads", QString("Clipboard downloader started successfully. PID=%1").arg(m_clipProcess->processId()));
}

void ProcessRunner::stopClipboard()
{
    if (!m_clipRunning && !m_clipProcess) return;
    AppLogger::log("Downloads", QString("Clipboard downloader stop requested. Running=%1, ProcessPresent=%2")
                                  .arg(m_clipRunning)
                                  .arg(m_clipProcess != nullptr));

    m_clipTickTimer->stop();

    if (m_clipProcess) {
        QProcess* p = m_clipProcess;
        m_clipProcess = nullptr;
        disconnect(p, nullptr, this, nullptr);
        connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                p, &QObject::deleteLater);
        p->terminate();
        AppLogger::log("Downloads", "Sent terminate() to clipboard downloader process.");
        QTimer::singleShot(3000, p, [p]() {
            if (p->state() != QProcess::NotRunning) p->kill();
        });
    }

    m_clipRunning = false;
    emit clipboardRunningChanged();
    emit clipboardLogLine("🛑 Clipboard Mode stopped.", false);
    AppLogger::log("Downloads", "Clipboard downloader stopped.");
}

void ProcessRunner::onClipReadyReadStdOut()
{
    if (!m_clipProcess) return;
    const QStringList lines = QString::fromUtf8(m_clipProcess->readAllStandardOutput()).split('\n');

    for (const QString& rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        if (line.contains("[CLIP] Clipboard Mode active.", Qt::CaseInsensitive)) continue;
        if (line.contains("[INFO] Starting download for:", Qt::CaseInsensitive)) continue;

        // Count completed downloads
        if (line.contains("Completed download for:", Qt::CaseInsensitive)) {
            m_clipDownloaded++;
            emit clipboardDownloadedChanged();
            emit clipboardLogLine(line, false);
            AppLogger::log("Downloads", QString("Clipboard downloader completed URL. Count=%1").arg(m_clipDownloaded));
            continue;
        }

        if (line.contains("Starting download for:", Qt::CaseInsensitive)) {
            emit clipboardLogLine(line, false);
            AppLogger::log("Downloads", QString("Clipboard downloader started URL: %1").arg(line));
            continue;
        }

        if (line.contains("Failed download for", Qt::CaseInsensitive)) {
            emit clipboardLogLine(line, true);
            AppLogger::log("Downloads", QString("Clipboard downloader failure: %1").arg(line));
            continue;
        }

        // Filter noise
        if (line.contains("Getting 'tsrdlticket'", Qt::CaseInsensitive)) continue;

        const bool isErr = line.startsWith("[ERROR]") || line.startsWith("[CRITICAL]");
        emit clipboardLogLine(line, isErr);
        if (isErr)
            AppLogger::log("Downloads", QString("Clipboard downloader stdout error line: %1").arg(line));
    }
}

void ProcessRunner::onClipReadyReadStdErr()
{
    if (!m_clipProcess) return;
    const QStringList lines = QString::fromUtf8(m_clipProcess->readAllStandardError()).split('\n');
    for (const QString& rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;
        if (line.contains("[INFO] Starting download for:", Qt::CaseInsensitive)) continue;
        emit clipboardLogLine(line, true);
        AppLogger::log("Downloads", QString("Clipboard downloader stderr: %1").arg(line));
    }
}

void ProcessRunner::onClipProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    m_clipTickTimer->stop();
    if (m_clipProcess) { m_clipProcess->deleteLater(); m_clipProcess = nullptr; }
    const bool was = m_clipRunning;
    m_clipRunning = false;
    AppLogger::log("Downloads", QString("Clipboard downloader process finished. ExitCode=%1, Status=%2")
                                  .arg(exitCode)
                                  .arg(status == QProcess::CrashExit ? "CrashExit" : "NormalExit"));
    if (was) {
        emit clipboardRunningChanged();
        emit clipboardLogLine("Clipboard Mode process ended.", false);
    }
}

void ProcessRunner::onClipTick()
{
    m_clipElapsed++;
    emit clipboardElapsedChanged();
    if ((m_clipElapsed % 30) == 0)
        AppLogger::log("Downloads", QString("Clipboard downloader heartbeat. Elapsed=%1s, Downloaded=%2").arg(m_clipElapsed).arg(m_clipDownloaded));
}

// ═══════════════════════════════════════════════════════════════════════════
//  URL COLLECTION
// ═══════════════════════════════════════════════════════════════════════════

QStringList ProcessRunner::collectUrlsFromNotepad(const QString& notepadBasePath,
                                                   const QString& relPath)
{
    QStringList urls;
    const QString fullPath = QDir(notepadBasePath).filePath(relPath);
    QFile file(fullPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit logLine(QString("Could not read notepad: %1").arg(relPath), true);
        AppLogger::log("Downloads", QString("Could not read notepad file: %1").arg(fullPath));
        return urls;
    }
    QTextStream stream(&file);
    while (!stream.atEnd())
        appendUrlsFromLine(stream.readLine(), urls);
    urls.removeDuplicates();
    AppLogger::log("Downloads", QString("Collected %1 unique valid URLs from notepad %2").arg(urls.size()).arg(relPath));
    return urls;
}

void ProcessRunner::appendUrlsFromLine(const QString& line, QStringList& out)
{
    static const QRegularExpression urlRe(
        R"((https?://[^\s"'<>]+))", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression strictTsrUrlRe(
        R"(https?://(?:www\.)?thesimsresource\.com/(?:members/[^/\s"'<>]+/)?downloads/details(?:/[^/\s"'<>]+)*/id/\d+/?$)",
        QRegularExpression::CaseInsensitiveOption);

    QRegularExpressionMatchIterator it = urlRe.globalMatch(line);
    while (it.hasNext()) {
        QString url = it.next().captured(1).trimmed();
        while (!url.isEmpty() && QString(").,;]}").contains(url.back()))
            url.chop(1);
        if (!strictTsrUrlRe.match(url).hasMatch()) continue;
        out << url;
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIN32 SUSPEND / RESUME
// ═══════════════════════════════════════════════════════════════════════════

#ifdef Q_OS_WIN
bool ProcessRunner::suspendPid(qint64 pid) {
    const HANDLE h = OpenProcess(PROCESS_SUSPEND_RESUME, FALSE, static_cast<DWORD>(pid));
    if (!h) return false;
    const HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    const auto fn = reinterpret_cast<NtSuspendProcessFn>(GetProcAddress(ntdll, "NtSuspendProcess"));
    const bool ok = fn && fn(h) >= 0;
    CloseHandle(h);
    return ok;
}

bool ProcessRunner::resumePid(qint64 pid) {
    const HANDLE h = OpenProcess(PROCESS_SUSPEND_RESUME, FALSE, static_cast<DWORD>(pid));
    if (!h) return false;
    const HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    const auto fn = reinterpret_cast<NtResumeProcessFn>(GetProcAddress(ntdll, "NtResumeProcess"));
    const bool ok = fn && fn(h) >= 0;
    CloseHandle(h);
    return ok;
}
#endif
