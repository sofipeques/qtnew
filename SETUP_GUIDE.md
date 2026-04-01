# TRS4 Sims Orchestrator — Qt6 Edition
## Setup & Deployment Guide (MinGW 64-bit, Windows)

---

## 1. Folder Structure (Portable Layout)

Place everything in ONE root folder, for example `C:\TRS4\`:

```
C:\TRS4\
├── TRS4Sims.exe              ← compiled app
├── data\
│   ├── config_user.json      ← auto-generated on first run
│   ├── allowed_urls.json     ← your URL whitelist
│   └── notepad\              ← .txt files (uncategorized, hair, etc.)
├── downloads\                ← default download destination
├── tsr_downloader\           ← YOUR EXISTING Python downloader (copy here)
│   ├── main.py
│   ├── config.json           ← managed by C++ app automatically
│   ├── session
│   └── ...all other .py files
└── Qt6 DLLs (see step 4)
```

The C++ app **auto-detects** `tsr_downloader/` by walking up from the .exe location.

---

## 2. Open in Qt Creator

1. Open **Qt Creator 18.0.1**
2. File → Open File or Project → select `CMakeLists.txt`
3. When asked for a Kit, choose **Desktop Qt 6.x.x MinGW 64-bit**
4. Click **Configure Project**
5. Press **Ctrl+B** to build

> **Note:** Use `CMakeLists.txt`, not `TRS4Sims.pro`. CMake is the modern standard for Qt6.

---

## 3. First Build — Fix Any Missing Includes

If you get errors about missing headers, check Qt Maintenance Tool has these modules:
- Qt Quick
- Qt Quick Controls 2
- Qt Network
- Qt Concurrent

All included in the standard Qt6 MinGW install.

---

## 4. Deploy as Portable .exe

After building in **Release** mode:

```powershell
# Open Qt MinGW terminal (from Start Menu: Qt 6.x > MinGW terminal)
cd C:\TRS4
windeployqt6 --qmldir qml TRS4Sims.exe
```

This copies all required Qt DLLs next to the .exe automatically.

Your portable package will be:
```
C:\TRS4\
├── TRS4Sims.exe
├── Qt6Core.dll
├── Qt6Quick.dll
├── Qt6QuickControls2.dll
├── ... (other Qt DLLs, ~20MB total)
├── qml\              ← QML files (embedded in exe via Qt resources)
└── tsr_downloader\
```

---

## 5. Python Requirements (unchanged)

The existing `tsr_downloader` Python stack works unchanged.
C++ launches it via `QProcess` — no modifications needed to Python code.

Make sure Python is in PATH on the target machine:
```
python --version  # should print Python 3.x
```

---

## 6. Key Behaviors

| Feature | How it works |
|---|---|
| Config persistence | `data/config_user.json` (JSON, same format as Python version) |
| Download destination | Set in UI → saved to config, synced to `tsr_downloader/config.json` |
| Clipboard monitor | `QClipboard` polling every 500ms → writes to `data/notepad/uncategorized.txt` |
| Duplicate scan | `QCryptographicHash::Md5` in background thread with live progress |
| Python process | `QProcess` launches `python main.py` in `tsr_downloader/` directory |
| Theme | Instant toggle white↔dark, saved to config |
| Stats | Auto-refreshes every 2s, diff from startup snapshot |

---

## 7. Troubleshooting

**"python not found" error:**
Add Python to your Windows PATH, or change `"python"` to the full path in `ProcessRunner.cpp`:
```cpp
m_process->start("C:/Python311/python.exe", {"main.py"});
```

**QML import errors on startup:**
Make sure you opened the project via CMakeLists.txt and ran `windeployqt6` after build.

**Config not saving:**
Check that the folder containing `TRS4Sims.exe` is writable (not in Program Files).

---

## 8. Customization Points

| File | What to change |
|---|---|
| `src/ThemeManager.h` | Colors — edit hex values for white/dark palette |
| `qml/Main.qml` | Window size, layout proportions |
| `qml/components/Sidebar.qml` | Navigation items, logo |
| `src/AppConfig.cpp` | Default values, config file path logic |
| `qml/panels/DownloadPanel.qml` | Download controls, progress display |
