#pragma once
#include <QObject>
#include <QColor>
#include "AppLogger.h"

class ThemeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool dark READ dark WRITE setDark NOTIFY darkChanged)
    Q_PROPERTY(bool transitioning READ transitioning NOTIFY transitioningChanged)

    // Surface colors
    Q_PROPERTY(QColor bg        READ bg        NOTIFY darkChanged)
    Q_PROPERTY(QColor surface   READ surface   NOTIFY darkChanged)
    Q_PROPERTY(QColor surfaceAlt READ surfaceAlt NOTIFY darkChanged)
    Q_PROPERTY(QColor border    READ border    NOTIFY darkChanged)

    // Text
    Q_PROPERTY(QColor textPrimary   READ textPrimary   NOTIFY darkChanged)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY darkChanged)
    Q_PROPERTY(QColor textMuted     READ textMuted     NOTIFY darkChanged)

    // Brand / accent
    Q_PROPERTY(QColor accent     READ accent     NOTIFY darkChanged)
    Q_PROPERTY(QColor accentHover READ accentHover NOTIFY darkChanged)
    Q_PROPERTY(QColor green      READ green      NOTIFY darkChanged)
    Q_PROPERTY(QColor orange     READ orange     NOTIFY darkChanged)
    Q_PROPERTY(QColor red        READ red        NOTIFY darkChanged)
    Q_PROPERTY(QColor blue       READ blue       NOTIFY darkChanged)

public:
    explicit ThemeManager(QObject* parent = nullptr);

    bool dark() const { return m_dark; }
    bool transitioning() const { return m_transitioning; }

    void setDark(bool v) {
        if (m_dark == v) return;
        AppLogger::log("Theme", QString("Theme change requested. Dark=%1").arg(v));
        m_transitioning = true;
        emit transitioningChanged();
        m_dark = v;
        emit darkChanged();
        // transitioning flag is cleared by QML after animation completes
    }

    Q_INVOKABLE void toggle()            { setDark(!m_dark); }
    Q_INVOKABLE void endTransition()     {
        if (!m_transitioning) return;
        m_transitioning = false;
        AppLogger::log("Theme", QString("Theme transition completed. Dark=%1").arg(m_dark));
        emit transitioningChanged();
    }

    QColor bg()          const { return m_dark ? QColor("#0F1117") : QColor("#F5F7FA"); }
    QColor surface()     const { return m_dark ? QColor("#1A1D27") : QColor("#FFFFFF"); }
    QColor surfaceAlt()  const { return m_dark ? QColor("#22263A") : QColor("#EEF1F6"); }
    QColor border()      const { return m_dark ? QColor("#2E3348") : QColor("#DDE3EE"); }
    QColor textPrimary() const { return m_dark ? QColor("#F0F2FF") : QColor("#151B2E"); }
    QColor textSecondary()const{ return m_dark ? QColor("#8B93B5") : QColor("#4B5577"); }
    QColor textMuted()   const { return m_dark ? QColor("#555E80") : QColor("#9BA4BC"); }
    QColor accent()      const { return QColor("#0066FF"); }
    QColor accentHover() const { return QColor("#0052CC"); }
    QColor green()       const { return QColor("#00C986"); }
    QColor orange()      const { return QColor("#FF8C00"); }
    QColor red()         const { return QColor("#FF3B5C"); }
    QColor blue()        const { return QColor("#3B8ED0"); }

signals:
    void darkChanged();
    void transitioningChanged();

private:
    bool m_dark        = false;
    bool m_transitioning = false;
};
