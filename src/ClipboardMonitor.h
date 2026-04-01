#pragma once
#include <QObject>
#include <QTimer>
#include <QStringList>
#include <QString>
#include <QSet>

class ClipboardMonitor : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active  READ active  NOTIFY activeChanged)
    Q_PROPERTY(bool paused  READ paused  NOTIFY pausedChanged)
    Q_PROPERTY(int  urlCount READ urlCount NOTIFY urlCountChanged)
    Q_PROPERTY(int  elapsedSeconds READ elapsedSeconds NOTIFY elapsedChanged)

public:
    explicit ClipboardMonitor(QObject* parent = nullptr);

    bool active()  const { return m_active; }
    bool paused()  const { return m_paused; }
    int  urlCount() const { return m_urlCount; }
    int  elapsedSeconds() const { return m_elapsed; }

    Q_INVOKABLE void start(const QString& outputPath, const QStringList& allowedPrefixes);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();

signals:
    void activeChanged();
    void pausedChanged();
    void urlCountChanged();
    void elapsedChanged();
    void urlCaptured(const QString& url);
    void logMessage(const QString& msg);

private slots:
    void checkClipboard();
    void tickTimer();

private:
    QTimer* m_clipTimer  = nullptr;
    QTimer* m_tickTimer  = nullptr;
    bool    m_active  = false;
    bool    m_paused  = false;
    int     m_urlCount = 0;
    int     m_elapsed  = 0;
    QString m_lastContent;
    QString m_outputPath;
    QStringList m_allowedPrefixes;
    QSet<QString> m_seenUrls;
};
