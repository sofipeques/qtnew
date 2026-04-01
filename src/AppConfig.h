#pragma once
#include <QObject>
#include <QString>
#include <QStringList>

class AppConfig : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(bool soundOnFinish READ soundOnFinish WRITE setSoundOnFinish NOTIFY soundOnFinishChanged)
    Q_PROPERTY(bool alwaysOnTop READ alwaysOnTop WRITE setAlwaysOnTop NOTIFY alwaysOnTopChanged)
    Q_PROPERTY(bool popupOnFinish READ popupOnFinish WRITE setPopupOnFinish NOTIFY popupOnFinishChanged)
    Q_PROPERTY(bool autoScanDuplicates READ autoScanDuplicates WRITE setAutoScanDuplicates NOTIFY autoScanDuplicatesChanged)
    Q_PROPERTY(bool autoCategorize READ autoCategorize WRITE setAutoCategorize NOTIFY autoCategorizeChanged)
    Q_PROPERTY(bool homeQuickActionsExpanded READ homeQuickActionsExpanded WRITE setHomeQuickActionsExpanded NOTIFY homeQuickActionsExpandedChanged)
    Q_PROPERTY(bool homeModulesExpanded READ homeModulesExpanded WRITE setHomeModulesExpanded NOTIFY homeModulesExpandedChanged)
    Q_PROPERTY(QString downloadRootPath READ downloadRootPath WRITE setDownloadRootPath NOTIFY downloadRootPathChanged)
    Q_PROPERTY(QString projectRootPath READ projectRootPath CONSTANT)
    Q_PROPERTY(QString notepadPath READ notepadPath CONSTANT)
    Q_PROPERTY(QStringList allowedUrls READ allowedUrls CONSTANT)

public:
    explicit AppConfig(QObject* parent = nullptr);

    bool darkMode() const { return m_darkMode; }
    bool soundOnFinish() const { return m_soundOnFinish; }
    bool alwaysOnTop() const { return m_alwaysOnTop; }
    bool popupOnFinish() const { return m_popupOnFinish; }
    bool autoScanDuplicates() const { return m_autoScanDuplicates; }
    bool autoCategorize() const { return m_autoCategorize; }
    bool homeQuickActionsExpanded() const { return m_homeQuickActionsExpanded; }
    bool homeModulesExpanded() const { return m_homeModulesExpanded; }
    QString downloadRootPath() const { return m_downloadRootPath; }
    QString projectRootPath() const { return m_projectRootPath; }
    QString notepadPath() const;
    QStringList allowedUrls() const { return m_allowedUrls; }

    void setDarkMode(bool v);
    void setSoundOnFinish(bool v);
    void setAlwaysOnTop(bool v);
    void setPopupOnFinish(bool v);
    void setAutoScanDuplicates(bool v);
    void setAutoCategorize(bool v);
    void setHomeQuickActionsExpanded(bool v);
    void setHomeModulesExpanded(bool v);
    void setDownloadRootPath(const QString& v);

    Q_INVOKABLE void save();
    Q_INVOKABLE void load();
    Q_INVOKABLE void syncDownloaderConfig(const QString& destPath);
    Q_INVOKABLE QString normalizePath(const QString& path) const;
    Q_INVOKABLE void beep() const;

signals:
    void darkModeChanged();
    void soundOnFinishChanged();
    void alwaysOnTopChanged();
    void popupOnFinishChanged();
    void autoScanDuplicatesChanged();
    void autoCategorizeChanged();
    void homeQuickActionsExpandedChanged();
    void homeModulesExpandedChanged();
    void downloadRootPathChanged();

private:
    QString configFilePath() const;
    QString allowedUrlsFilePath() const;
    void loadAllowedUrls();
    void ensureProjectLayout();

    bool m_darkMode = false;
    bool m_soundOnFinish = true;
    bool m_alwaysOnTop = false;
    bool m_popupOnFinish = true;
    bool m_autoScanDuplicates = false;
    bool m_autoCategorize = false;
    bool m_homeQuickActionsExpanded = true;
    bool m_homeModulesExpanded = true;
    QString m_downloadRootPath;
    QString m_projectRootPath;
    QStringList m_allowedUrls;
};
