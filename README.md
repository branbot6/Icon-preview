# Icon Preview Lab (Native macOS)

A native macOS app (Swift + AppKit + WKWebView) for previewing SVG icons in multiple platform contexts and exporting deliverables.

## Features

- Load SVG from native file picker or drag-and-drop
- Preview icon appearance for:
  - Favicon context
  - Web logo + browser tab
  - macOS app icon contexts
  - iOS app icon contexts
- Export **1024x1024 PNG** with native save dialog
- Export **macOS DMG** (auto-generates `.icns` + app bundle)

## Requirements

- macOS 13+
- Xcode Command Line Tools (Swift toolchain)

## Quick Start

```bash
cd <repo-folder>
swift build
swift run IconPreviewLabNative
```

## Project Structure

```text
native-macos/
├─ Package.swift
├─ Sources/
│  └─ IconPreviewLabNative/
│     ├─ main.swift
│     └─ Resources/
│        ├─ index.html
│        ├─ branai-logo.svg
│        ├─ branai-icon.svg
│        └─ ip-icon-1024.png
└─ scripts/
   ├─ run.sh
   └─ build_app.sh
```

## Notes

- The app uses a JS-to-native bridge (`window.desktopBridge`) for native file dialogs and export actions.
- If you moved this project from another path and hit module-cache errors, clean once:

```bash
rm -rf .build
swift build
```
