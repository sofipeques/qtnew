#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QSet>

// ─── NotepadManager ──────────────────────────────────────────────────────────
class NotepadManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList files READ files NOTIFY filesChanged)

public:
    explicit NotepadManager(QObject* parent = nullptr);

    QVariantList files() const { return m_files; }

    Q_INVOKABLE void setBasePath(const QString& path);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString     readFile(const QString& path) const;
    Q_INVOKABLE int         lineCount(const QString& path) const;
    Q_INVOKABLE bool        deleteFile(const QString& path);
    Q_INVOKABLE QStringList validUrlsFromFile(const QString& relPath) const;
    Q_INVOKABLE QStringList allRelativePaths() const;
    Q_INVOKABLE QVariantMap categorizeUncategorized();

signals:
    void filesChanged();
    void logMessage(const QString& msg);

private:
    static QString categoryFileNameForUrl(const QString& url, const QString& basePath);

    QString      m_basePath;
    QVariantList m_files;
};

// ─── DownloadStats ───────────────────────────────────────────────────────────
class DownloadStats : public QObject {
    Q_OBJECT
    Q_PROPERTY(int          fileCount READ fileCount NOTIFY statsChanged)
    Q_PROPERTY(double       sessionMb READ sessionMb NOTIFY statsChanged)
    Q_PROPERTY(QVariantList folders   READ folders   NOTIFY foldersChanged)

public:
    explicit DownloadStats(QObject* parent = nullptr);

    int          fileCount() const { return m_fileCount; }
    double       sessionMb()  const { return m_sessionMb; }
    QVariantList folders()    const { return m_folders; }

    Q_INVOKABLE void         setRootPath(const QString& path);
    Q_INVOKABLE void         takeSnapshot();
    Q_INVOKABLE void         refresh();

    // Returns a list of {name, sizeKb} maps for *.package files in folderPath.
    // Called by DownloadPanel's fileViewer.scan().
    Q_INVOKABLE QVariantList filesInFolder(const QString& folderPath) const;

signals:
    void statsChanged();
    void foldersChanged();

private:
    void scanFolders();

    QString       m_rootPath;
    QSet<QString> m_snapshot;
    int           m_fileCount = 0;
    double        m_sessionMb = 0.0;
    QVariantList  m_folders;
    QTimer*       m_timer = nullptr;
};
