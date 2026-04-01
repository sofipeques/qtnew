#include "NotepadManager.h"
#include "AppLogger.h"
#include <QDirIterator>
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QVariantMap>
#include <QHash>
#include <QMap>
#include <QDir>
#include <QDebug>
#include <QRegularExpression>
#include <algorithm>

namespace {
const QString kUncategorizedFile = "uncategorized.txt";

const QStringList kCategoryPriority = {
    "child", "makeup", "outfits", "tops", "bottoms",
    "skintones", "shoes", "hair", "accessories"
};

const QMap<QString, QStringList> kCategoryKeywords = {
    {"child", {"child", "children", "kid", "kids", "toddler", "toddlers", "infant", "infants"}},
    {"skintones", {"skintone", "skintones", "skinblend", "defaultskin", "skin"}},
    {"makeup", {"makeup", "lipstick", "lip", "lips", "blush", "eyeshadow", "eyeliner", "liner"}},
    {"outfits", {"outfit", "dress", "fullbody", "gown", "set", "jumpsuit"}},
    {"tops", {"top", "shirt", "blouse", "hoodie", "tank", "sweater", "jacket"}},
    {"bottoms", {"bottom", "pant", "pants", "skirt", "jean", "jeans", "trouser", "trousers", "legging", "leggings", "shorts"}},
    {"shoes", {"shoe", "shoes", "boot", "boots", "sneaker", "sneakers", "heel", "heels", "sandals"}},
    {"hair", {"hair", "hairstyle", "braid", "braids", "ponytail", "bun"}},
    {"accessories", {"accessory", "accessories", "necklace", "earring", "earrings", "ring", "rings", "bracelet", "bracelets", "glasses", "hat", "socks", "gloves", "tattoo", "tattoos"}}
};

QString normalizedUrlKey(const QString& url)
{
    static const QRegularExpression tsrIdRe(R"(/id/(\d+))", QRegularExpression::CaseInsensitiveOption);
    const QString trimmed = url.trimmed();
    const QRegularExpressionMatch match = tsrIdRe.match(trimmed);
    if (match.hasMatch())
        return QStringLiteral("id:%1").arg(match.captured(1));
    return trimmed.toLower();
}

QSet<QString> existingUrlKeysForFile(const QString& path)
{
    QSet<QString> keys;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return keys;

    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (!line.isEmpty())
            keys.insert(normalizedUrlKey(line));
    }
    return keys;
}

QStringList urlsMissingFromFile(const QStringList& urls, const QString& targetPath, QHash<QString, QSet<QString>>& knownKeysByFile)
{
    if (!knownKeysByFile.contains(targetPath))
        knownKeysByFile.insert(targetPath, existingUrlKeysForFile(targetPath));

    QSet<QString>& knownKeys = knownKeysByFile[targetPath];
    QStringList filtered;
    for (const QString& url : urls) {
        const QString key = normalizedUrlKey(url);
        if (knownKeys.contains(key))
            continue;
        knownKeys.insert(key);
        filtered.append(url);
    }
    return filtered;
}

QString detectCategory(const QString& url)
{
    const QString lower = url.toLower();

    for (const QString& keyword : kCategoryKeywords.value("child")) {
        if (lower.contains(keyword))
            return "child";
    }

    QString bestCategory = "uncategorized";
    int bestScore = 0;

    for (const QString& category : kCategoryPriority) {
        if (category == "child")
            continue;

        int score = 0;
        for (const QString& keyword : kCategoryKeywords.value(category)) {
            if (lower.contains(keyword))
                ++score;
        }

        if (score > bestScore) {
            bestScore = score;
            bestCategory = category;
        }
    }

    return bestCategory;
}

QStringList uniqueTrimmedLines(const QStringList& lines)
{
    QStringList result;
    QSet<QString> seen;
    for (const QString& raw : lines) {
        const QString line = raw.trimmed();
        if (line.isEmpty() || seen.contains(line))
            continue;
        seen.insert(line);
        result.append(line);
    }
    return result;
}
}

// ─── NotepadManager ──────────────────────────────────────────────────────────
NotepadManager::NotepadManager(QObject* parent) : QObject(parent) {}

void NotepadManager::setBasePath(const QString& path) {
    m_basePath = path;
    AppLogger::log("Notepads", QString("Base path set to %1").arg(m_basePath));
    refresh();
}

void NotepadManager::refresh() {
    m_files.clear();
    if (m_basePath.isEmpty() || !QDir(m_basePath).exists()) {
        AppLogger::log("Notepads", QString("Refresh skipped: base path is empty or missing (%1)").arg(m_basePath));
        emit filesChanged();
        return;
    }

    QDirIterator it(m_basePath, {"*.txt"}, QDir::Files, QDirIterator::Subdirectories);
    QStringList found;
    while (it.hasNext()) found << it.next();
    found.sort();

    for (const QString& fp : found) {
        QString rel = QDir(m_basePath).relativeFilePath(fp);
        QVariantMap m;
        m["path"]    = fp;
        m["relPath"] = rel;
        m["name"]    = rel;
        m_files.append(m);
    }
    AppLogger::log("Notepads", QString("Refreshed notepad list. Found %1 files under %2").arg(m_files.size()).arg(m_basePath));
    emit filesChanged();
}

QString NotepadManager::readFile(const QString& path) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        AppLogger::log("Notepads", QString("Failed to read file: %1").arg(path));
        return {};
    }
    AppLogger::log("Notepads", QString("Read file: %1").arg(path));
    return QTextStream(&f).readAll();
}

int NotepadManager::lineCount(const QString& path) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        AppLogger::log("Notepads", QString("Failed to count lines for file: %1").arg(path));
        return 0;
    }
    int c = 0;
    QTextStream ts(&f);
    while (!ts.atEnd()) { ts.readLine(); c++; }
    AppLogger::log("Notepads", QString("Counted %1 lines in %2").arg(c).arg(path));
    return c;
}

bool NotepadManager::deleteFile(const QString& path) {
    bool ok = QFile::remove(path);
    if (ok) {
        AppLogger::log("Notepads", QString("Deleted notepad file: %1").arg(path));
        refresh();
    } else {
        AppLogger::log("Notepads", QString("Failed to delete notepad file: %1").arg(path));
    }
    return ok;
}

QStringList NotepadManager::validUrlsFromFile(const QString& relPath) const {
    QString full = QDir(m_basePath).filePath(relPath);
    QFile f(full);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        AppLogger::log("Notepads", QString("Failed to read URLs from file: %1").arg(full));
        return {};
    }
    QStringList result;
    QTextStream ts(&f);
    while (!ts.atEnd()) {
        QString l = ts.readLine().trimmed();
        if (l.startsWith("http", Qt::CaseInsensitive) ||
            l.startsWith("www",  Qt::CaseInsensitive))
            result << l;
    }
    AppLogger::log("Notepads", QString("Collected %1 candidate URLs from %2").arg(result.size()).arg(full));
    return result;
}

QStringList NotepadManager::allRelativePaths() const {
    QStringList out;
    for (const QVariant& v : m_files)
        out << v.toMap()["relPath"].toString();
    return out;
}

QString NotepadManager::categoryFileNameForUrl(const QString& url, const QString& basePath) {
    const QString category = detectCategory(url);
    if (category == "makeup") {
        const QString lower = url.toLower();
        QString fileName = "makeup_other.txt";
        if (lower.contains("lipstick"))
            fileName = "lipstick.txt";
        else if (lower.contains("lips") || lower.contains("lip"))
            fileName = "lips.txt";
        else if (lower.contains("blush"))
            fileName = "blush.txt";
        else if (lower.contains("eyeshadow"))
            fileName = "eyeshadow.txt";
        else if (lower.contains("eyeliner") || lower.contains("liner"))
            fileName = "eyeliner.txt";
        return QDir(basePath).filePath("makeup/" + fileName);
    }

    return QDir(basePath).filePath(category + ".txt");
}

QVariantMap NotepadManager::categorizeUncategorized() {
    QVariantMap result;
    result["processed"] = 0;
    result["moved"] = 0;
    result["remaining"] = 0;
    result["createdFiles"] = QStringList();

    if (m_basePath.isEmpty()) {
        emit logMessage("[ERR] Auto-categorize failed");
        AppLogger::log("Clipboard", "Auto-categorize failed: base path is empty.");
        return result;
    }

    const QString uncategorizedPath = QDir(m_basePath).filePath(kUncategorizedFile);
    QFile input(uncategorizedPath);
    if (!input.exists())
        return result;

    if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit logMessage("[ERR] Auto-categorize failed");
        AppLogger::log("Clipboard", QString("Auto-categorize failed: could not open %1").arg(uncategorizedPath));
        return result;
    }

    QStringList lines;
    QTextStream in(&input);
    while (!in.atEnd())
        lines.append(in.readLine());
    input.close();

    const QStringList uniqueLines = uniqueTrimmedLines(lines);
    result["processed"] = uniqueLines.size();

    QHash<QString, QStringList> categorized;
    for (const QString& url : uniqueLines)
        categorized[detectCategory(url)].append(url);

    const QStringList remaining = categorized.value("uncategorized");
    int moved = 0;
    QSet<QString> createdFiles;
    QHash<QString, QSet<QString>> knownKeysByFile;

    for (auto it = categorized.cbegin(); it != categorized.cend(); ++it) {
        if (it.key() == "uncategorized" || it.value().isEmpty())
            continue;

        if (it.key() == "makeup") {
            QHash<QString, QStringList> makeupFiles;
            for (const QString& url : it.value())
                makeupFiles[categoryFileNameForUrl(url, m_basePath)].append(url);

            for (auto mf = makeupFiles.cbegin(); mf != makeupFiles.cend(); ++mf) {
                const QStringList urlsToAppend = urlsMissingFromFile(mf.value(), mf.key(), knownKeysByFile);
                if (urlsToAppend.isEmpty())
                    continue;

                QFileInfo info(mf.key());
                if (!QDir().mkpath(info.absolutePath())) {
                    emit logMessage("[ERR] Auto-categorize failed");
                    AppLogger::log("Clipboard", QString("Auto-categorize failed: could not create folder %1").arg(info.absolutePath()));
                    return result;
                }
                QFile out(mf.key());
                if (!out.open(QIODevice::Append | QIODevice::Text)) {
                    emit logMessage("[ERR] Auto-categorize failed");
                    AppLogger::log("Clipboard", QString("Auto-categorize failed: could not append to %1").arg(mf.key()));
                    return result;
                }
                QTextStream ts(&out);
                for (const QString& url : urlsToAppend)
                    ts << url << '\n';
                out.close();
                moved += urlsToAppend.size();
                createdFiles.insert(QDir(m_basePath).relativeFilePath(mf.key()));
            }
            continue;
        }

        const QString target = categoryFileNameForUrl(it.value().first(), m_basePath);
        const QStringList urlsToAppend = urlsMissingFromFile(it.value(), target, knownKeysByFile);
        if (urlsToAppend.isEmpty())
            continue;

        QFileInfo targetInfo(target);
        if (!QDir().mkpath(targetInfo.absolutePath())) {
            emit logMessage("[ERR] Auto-categorize failed");
            AppLogger::log("Clipboard", QString("Auto-categorize failed: could not create folder %1").arg(targetInfo.absolutePath()));
            return result;
        }
        QFile out(target);
        if (!out.open(QIODevice::Append | QIODevice::Text)) {
            emit logMessage("[ERR] Auto-categorize failed");
            AppLogger::log("Clipboard", QString("Auto-categorize failed: could not append to %1").arg(target));
            return result;
        }
        QTextStream ts(&out);
        for (const QString& url : urlsToAppend)
            ts << url << '\n';
        out.close();
        moved += urlsToAppend.size();
        createdFiles.insert(QDir(m_basePath).relativeFilePath(target));
    }

    if (remaining.isEmpty()) {
        QFile::remove(uncategorizedPath);
        emit logMessage("uncategorized.txt quedo vacio y se elimino.");
    } else if (input.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&input);
        for (const QString& url : remaining)
            out << url << '\n';
        input.close();
    } else {
        emit logMessage("[ERR] Auto-categorize failed");
        AppLogger::log("Clipboard", QString("Auto-categorize failed: could not rewrite %1").arg(uncategorizedPath));
        return result;
    }

    result["moved"] = moved;
    result["remaining"] = remaining.size();
    result["createdFiles"] = QStringList(createdFiles.begin(), createdFiles.end());

    emit logMessage(QString("Categorizacion completada. %1 URLs movidas.").arg(moved));
    AppLogger::log("Clipboard", QString("Auto-categorize completed. Moved %1 URLs, remaining %2.")
                                    .arg(moved)
                                    .arg(remaining.size()));
    refresh();
    return result;
}

// ─── DownloadStats ───────────────────────────────────────────────────────────
DownloadStats::DownloadStats(QObject* parent) : QObject(parent) {
    m_timer = new QTimer(this);
    m_timer->setInterval(2000);
    connect(m_timer, &QTimer::timeout, this, &DownloadStats::refresh);
}

void DownloadStats::setRootPath(const QString& path) {
    m_rootPath = path;
    AppLogger::log("Home", QString("DownloadStats root path set to %1").arg(m_rootPath));
    takeSnapshot();
    scanFolders();
    m_timer->start();
}

void DownloadStats::takeSnapshot() {
    m_snapshot.clear();
    if (m_rootPath.isEmpty()) {
        AppLogger::log("Home", "DownloadStats snapshot skipped: root path is empty.");
        return;
    }
    QDirIterator it(m_rootPath, {"*.package"}, QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext())
        m_snapshot.insert(QFileInfo(it.next()).absoluteFilePath());
    AppLogger::log("Home", QString("DownloadStats snapshot captured %1 package files from %2").arg(m_snapshot.size()).arg(m_rootPath));
}

void DownloadStats::refresh() {
    if (m_rootPath.isEmpty()) {
        AppLogger::log("Home", "DownloadStats refresh skipped: root path is empty.");
        return;
    }

    QSet<QString> current;
    QDirIterator it(m_rootPath, {"*.package"}, QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext())
        current.insert(QFileInfo(it.next()).absoluteFilePath());

    QSet<QString> newFiles = current - m_snapshot;
    m_fileCount = newFiles.size();
    double mb = 0.0;
    for (const QString& p : newFiles)
        mb += QFileInfo(p).size() / (1024.0 * 1024.0);
    m_sessionMb = mb;
    AppLogger::log("Home", QString("DownloadStats refresh found %1 new files totaling %2 MB").arg(m_fileCount).arg(m_sessionMb, 0, 'f', 2));
    emit statsChanged();

    scanFolders();
}

void DownloadStats::scanFolders() {
    m_folders.clear();
    if (m_rootPath.isEmpty()) {
        AppLogger::log("Home", "DownloadStats scanFolders skipped: root path is empty.");
        emit foldersChanged();
        return;
    }

    QDir root(m_rootPath);
    if (!root.exists()) {
        AppLogger::log("Home", QString("DownloadStats root folder does not exist: %1").arg(m_rootPath));
        emit foldersChanged();
        return;
    }

    QHash<QString, QVariantMap> foldersByPath;
    auto ensureFolderEntry = [&](const QString& folderPath) -> QVariantMap& {
        if (!foldersByPath.contains(folderPath)) {
            QVariantMap fm;
            fm["name"] = QFileInfo(folderPath).fileName();
            if (folderPath == root.absolutePath())
                fm["name"] = "downloads";
            fm["path"] = folderPath;
            fm["count"] = 0;
            fm["bytes"] = 0LL;
            foldersByPath.insert(folderPath, fm);
        }
        return foldersByPath[folderPath];
    };

    QDirIterator it(root.absolutePath(), {"*.package"}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString filePath = it.next();
        const QFileInfo info(filePath);
        QVariantMap& folder = ensureFolderEntry(info.absolutePath());
        folder["count"] = folder["count"].toInt() + 1;
        folder["bytes"] = folder["bytes"].toLongLong() + info.size();
    }

    QStringList sortedPaths = foldersByPath.keys();
    std::sort(sortedPaths.begin(), sortedPaths.end(), [](const QString& a, const QString& b) {
        return a.toLower() < b.toLower();
    });

    QVariantList folders;
    for (const QString& path : sortedPaths) {
        QVariantMap folder = foldersByPath.value(path);
        const double mb = folder["bytes"].toLongLong() / (1024.0 * 1024.0);
        folder["sizeStr"] = mb < 1000
                                ? QString("%1 MB").arg(mb, 0, 'f', 1)
                                : QString("%1 GB").arg(mb / 1024.0, 0, 'f', 2);
        folder.remove("bytes");
        folders.append(folder);
    }

    m_folders = folders;
    AppLogger::log("Home", QString("DownloadStats scanned %1 folders under %2").arg(m_folders.size()).arg(m_rootPath));
    emit foldersChanged();
}

QVariantList DownloadStats::filesInFolder(const QString& folderPath) const {
    QVariantList result;
    if (folderPath.isEmpty()) return result;

    QDirIterator it(folderPath, {"*.package"}, QDir::Files,
                    QDirIterator::Subdirectories);
    QList<QFileInfo> infos;
    while (it.hasNext()) {
        it.next();
        infos.append(it.fileInfo());
    }

    // Sort by name for a stable order
    std::sort(infos.begin(), infos.end(),
              [](const QFileInfo& a, const QFileInfo& b) {
                  return a.fileName().toLower() < b.fileName().toLower();
              });

    for (const QFileInfo& fi : infos) {
        QVariantMap m;
        const double mb = fi.size() / (1024.0 * 1024.0);
        m["name"]   = fi.fileName();
        m["sizeKb"] = static_cast<int>(fi.size() / 1024);
        m["sizeStr"] = mb < 1000.0
                           ? QString("%1MB").arg(mb, 0, 'f', 1)
                           : QString("%1GB").arg(mb / 1024.0, 0, 'f', 1);
        result.append(m);
    }
    return result;
}

// Required by Qt AutoMoc when two Q_OBJECT classes share one .cpp file
#include "NotepadManager.moc"
