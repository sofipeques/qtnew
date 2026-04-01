#pragma once

#include <QObject>
#include <QProcess>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QTimer>

class ProcessRunner : public QObject {
    Q_OBJECT

    // ── Notepad-mode properties ───────────────────────────────────────────
    Q_PROPERTY(bool running  READ running  NOTIFY runningChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY finishedChanged)
    Q_PROPERTY(bool paused   READ paused   NOTIFY pausedChanged)

    // ── Clipboard-mode properties ─────────────────────────────────────────
    Q_PROPERTY(bool clipboardRunning    READ clipboardRunning    NOTIFY clipboardRunningChanged)
    Q_PROPERTY(int  clipboardElapsed    READ clipboardElapsed    NOTIFY clipboardElapsedChanged)
    Q_PROPERTY(int  clipboardDownloaded READ clipboardDownloaded NOTIFY clipboardDownloadedChanged)

public:
    explicit ProcessRunner(QObject* parent = nullptr);
    ~ProcessRunner();

    // Notepad mode
    bool running()  const { return m_running; }
    bool finished() const { return m_finished; }
    bool paused()   const { return m_paused; }

    // Clipboard mode
    bool clipboardRunning()    const { return m_clipRunning; }
    int  clipboardElapsed()    const { return m_clipElapsed; }
    int  clipboardDownloaded() const { return m_clipDownloaded; }

    // ── Notepad mode ──────────────────────────────────────────────────────
    Q_INVOKABLE void start(const QString& workingDir,
                           const QString& notepadBasePath,
                           const QStringList& relativePaths,
                           const QString& downloadRootPath,
                           int delaySeconds = 0);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();

    // ── Clipboard mode ────────────────────────────────────────────────────
    Q_INVOKABLE void startClipboard(const QString& workingDir,
                                    const QString& downloadRootPath);
    Q_INVOKABLE void stopClipboard();

signals:
    // Notepad mode
    void logLine(const QString& line, bool isError);
    void downloadCompleted();
    void runningChanged();
    void finishedChanged();
    void pausedChanged();
    void progressUpdated(double value);
    void currentItemChanged(int current, int total, const QString& sourceUrl);
    void notepadStarted(const QString& relPath, int totalUrls);
    void notepadUrlFinished(const QString& relPath,
                            const QString& sourceUrl,
                            int current, int total, bool succeeded);
    void notepadCompleted(const QString& relPath,
                          int processed, int total,
                          const QStringList& failedUrls);

    // Clipboard mode — separate signals so logs never mix
    void clipboardRunningChanged();
    void clipboardElapsedChanged();
    void clipboardDownloadedChanged();
    void clipboardLogLine(const QString& line, bool isError);

private slots:
    // Notepad mode
    void onReadyReadStdOut();
    void onReadyReadStdErr();
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);

    // Clipboard mode
    void onClipReadyReadStdOut();
    void onClipReadyReadStdErr();
    void onClipProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onClipTick();

private:
    void launchNotepadProcess(const QStringList& urls,
                              const QString& destDir,
                              int delaySeconds);
    void startNextNotepad();
    void finalizeRun(bool completed);

    QStringList collectUrlsFromNotepad(const QString& notepadBasePath,
                                       const QString& relPath);
    static void appendUrlsFromLine(const QString& line, QStringList& out);

#ifdef Q_OS_WIN
    static bool suspendPid(qint64 pid);
    static bool resumePid(qint64 pid);
#endif

    // ── Notepad mode state ────────────────────────────────────────────────
    QProcess* m_process  = nullptr;
    QString   m_workingDir;
    QString   m_downloadRootPath;
    QString   m_notepadBasePath;

    struct NotepadJob {
        QString     relPath;
        QStringList urls;
        QString     subfolderName;
    };
    QList<NotepadJob> m_notepadQueue;
    NotepadJob        m_currentNotepad;

    int  m_totalUrlsAllNotepads  = 0;
    int  m_completedUrlsGlobal   = 0;
    int  m_notepadUrlTotal       = 0;
    int  m_notepadCompletedCount = 0;
    int  m_notepadStartedCount   = 0;

    bool m_running       = false;
    bool m_finished      = false;
    bool m_paused        = false;
    bool m_stopRequested = false;
    int  m_delaySeconds  = 0;

    // ── Clipboard mode state ──────────────────────────────────────────────
    QProcess* m_clipProcess    = nullptr;
    QTimer*   m_clipTickTimer  = nullptr;
    bool      m_clipRunning    = false;
    int       m_clipElapsed    = 0;
    int       m_clipDownloaded = 0;
};
