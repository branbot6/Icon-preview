# BranAI Icon Preview Lab (Native macOS)

A native macOS app (Swift + AppKit + WKWebView) for previewing SVG icons in multiple platform contexts and exporting deliverables.

## Download

- Latest release: [Download from GitHub Releases](https://github.com/branbot6/Icon-preview/releases/latest)
- Release assets include:
  - `*.dmg`
  - `*.dmg.sha256`

Verify checksum:

```bash
shasum -a 256 "Icon Preview Lab-<version>-native-arm64.dmg"
```

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

## Build Installer (Local)

```bash
cd <repo-folder>
./scripts/build_app.sh
```

Output in `dist/`:
- `Icon Preview Lab.app`
- `Icon Preview Lab-<version>-native-arm64.dmg`

## GitHub Release Automation

- Workflow: `.github/workflows/release-dmg.yml`
- Release template: `.github/RELEASE_TEMPLATE.md`
- Changelog categories: `.github/release.yml`

Automatic release build on tag push:

```bash
git tag v1.2.0
git push origin v1.2.0
```

You can also run the workflow manually from GitHub Actions.

## macOS Signing & Trust

- For open-source testing, unsigned app/DMG can run, but users may see Gatekeeper warnings.
- For public distribution, recommended:
  - `Developer ID Application` certificate (Apple Developer Program)
  - Code signing for `.app` and `.dmg`
  - Notarization + stapling

Signing/notarization skeleton script:

```bash
cd <repo-folder>
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APPLE_TEAM_ID="ABCDE12345" \
NOTARYTOOL_PROFILE="your-notary-profile" \
./scripts/sign_and_notarize.sh
```

Alternative auth (instead of `NOTARYTOOL_PROFILE`):
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

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
   ├─ build_app.sh
   └─ sign_and_notarize.sh
```

## Notes

- The app uses a JS-to-native bridge (`window.desktopBridge`) for native file dialogs and export actions.
- If you moved this project from another path and hit module-cache errors, clean once:

```bash
rm -rf .build
swift build
```
