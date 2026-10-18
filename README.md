# 🎯 Dragged

> **The ultra-fast, gesture-based local file converter & radial tool wheel for macOS and Windows.**  
> Hold **Shift** while dragging any file, pick an action on the blooming radial wheel, and release. 100% offline, zero cloud uploads.

[![Release](https://img.shields.io/github/v/release/ozertugrul/Dragged?style=flat-square&color=orange)](https://github.com/ozertugrul/Dragged/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%20(Universal)%20%7C%20Windows%20x64-blue?style=flat-square)](https://github.com/ozertugrul/Dragged/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

<p align="center">
  <img src="assets/banner.png" alt="Dragged App Feature Showcase" width="100%" style="border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);" />
</p>

---

## ✨ Features

- **🎯 Blooming Radial Wheel:** Drag any file in Finder or File Explorer, hold **Shift**, and a beautiful frosted-glass radial wheel blooms directly at your cursor.
- **🔄 Scroll to Switch Menus:** Use your mouse scroll wheel or trackpad two-finger swipe while dragging to cycle smoothly between 4 dedicated tool wheels:
  1. **Image Formats:** `PNG`, `WEBP`, `HEIC`, `GIF`, `AVIF`, `BMP`, `PDF`, `DOCX`, Center: `TIFF`
  2. **Tools & Edit:** `COMPRESS`, `METADATA` (EXIF Strip), `EDIT`, `ANNOTATE`, `REMOVE BG`, `PREVIEW`, `CROP`, `REDACT`, Center: `ADD BG`
  3. **Video & Audio:** `MP4`, `GIF`, `MP3` (Audio extractor), `WAV`, `MOV`, `WEBM`, `M4A`, `COMPRESS`, Center: `MUTE`
  4. **PDF & Documents:** `TO PDF`, `COMPRESS`, `SPLIT`, `MERGE`, `OCR TEXT`, `TO IMAGES`, `TO WORD`, `PRINT`, Center: `PREVIEW`
- **🧠 Smart Category Auto-Detection:** Automatically opens the right wheel depending on the dragged file type (Videos open Media, PDFs open Documents, Images open Formats).
- **🖼️ Real-Time Document Thumbnail Hover:** When hovering over a target petal, it lights up in vibrant orange/magenta and displays a live mini preview of your dragged document.
- **🔔 Native System Notifications:** Instant desktop notifications showing the saved destination, file dimensions, and size savings percentage (e.g. `Saved 78%`). Clicking reveals the file in Finder/Explorer.
- **🔒 100% Local & Offline:** Never uploads your files to any external server. Uses native high-performance engines (`sips`, `cwebp`, `ffmpeg`, `PDFKit`, `Pillow`).
- **⚡ Universal Binary:** Native support for both **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs, plus **Windows x64**.

---

## 🚀 Downloads (Latest Release v1.0.0)

| Platform | Type | File | Description |
| :--- | :--- | :--- | :--- |
| **macOS** | **DMG Installer** | [`Dragged-macOS-Universal.dmg`](https://github.com/ozertugrul/Dragged/releases/download/v1.0.0/Dragged-macOS-Universal.dmg) | Universal binary for Apple Silicon & Intel |
| **macOS** | **ZIP Archive** | [`Dragged-macOS-Universal.zip`](https://github.com/ozertugrul/Dragged/releases/download/v1.0.0/Dragged-macOS-Universal.zip) | Portable app bundle |
| **Windows** | **Setup Installer** | [`Dragged-Setup-Windows-x64.exe`](https://github.com/ozertugrul/Dragged/releases/download/v1.0.0/Dragged-Setup-Windows-x64.exe) | Complete setup wizard with shortcuts |
| **Windows** | **Standalone Exe** | [`Dragged.exe`](https://github.com/ozertugrul/Dragged/releases/download/v1.0.0/Dragged.exe) | Single portable executable |

---

## 🛠️ Building from Source

### macOS (Apple Silicon + Intel Universal)
Requirements: macOS 13+, Apple Xcode Command Line Tools.

```bash
git clone https://github.com/ozertugrul/Dragged.git
cd Dragged
chmod +x build.sh
./build.sh
```
The compiled Universal binary and `.dmg` will be placed in `release/`.

### Windows (x64)
Requirements: Python 3.10+, Inno Setup 6 (optional, for installer).

```cmd
git clone https://github.com/ozertugrul/Dragged.git
cd Dragged\windows
pip install -r requirements.txt
build_windows.bat
```

---

## 📄 License

Distributed under the [MIT License](LICENSE).
