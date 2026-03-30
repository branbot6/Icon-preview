# BranAI Icon Preview Lab

A lightweight open-source macOS tool to preview SVG icons in real UI contexts and export ready-to-use assets.

## Download

- [Download DMG (Latest)](https://github.com/branbot6/Icon-preview/releases/latest/download/branai-icon-preview-lab-latest.dmg)
- [SHA256](https://github.com/branbot6/Icon-preview/releases/latest/download/branai-icon-preview-lab-latest.dmg.sha256)
- [All Releases](https://github.com/branbot6/Icon-preview/releases/latest)

Verify download:

```bash
shasum -a 256 "branai-icon-preview-lab-latest.dmg"
```

## Quick Start (From Source)

```bash
git clone https://github.com/branbot6/Icon-preview.git
cd Icon-preview
swift build
swift run IconPreviewLabNative
```

## What It Does

- Load SVG via native file picker or drag-and-drop
- Preview icon appearance in multiple contexts
- Favicon context
- Web tab + logo context
- macOS app icon scenes
- iOS app icon scenes
- Export 1024x1024 PNG (native save dialog)
- Export macOS DMG from the current icon

## Typical Workflow

1. Open app
2. Choose or drag an SVG
3. Inspect icon in all preview panels
4. Export PNG and/or DMG

## Local Packaging

Build `.app` and `.dmg` locally:

```bash
./scripts/build_app.sh
```

Output:

- `dist/Icon Preview Lab.app`
- `dist/Icon Preview Lab-<version>-native-arm64.dmg`

## Development

Run app in dev mode:

```bash
./scripts/run.sh
```

## Known Notes

- Current release assets are unsigned for now.
- On some macOS setups, Gatekeeper may block first launch.
- If needed, remove quarantine manually:

```bash
xattr -dr com.apple.quarantine ~/Downloads/branai-icon-preview-lab-latest.dmg
```

## Contributing

Issues and PRs are welcome.

Suggested PR format:

1. Describe user impact
2. Include screenshots/GIF for UI changes
3. Keep changes scoped and testable

## Release Automation

- Workflow: `.github/workflows/release-dmg.yml`
- Tag release:

```bash
git tag v1.2.0
git push origin v1.2.0
```

## Project Structure

```text
Icon-preview/
├─ Package.swift
├─ Sources/
│  └─ IconPreviewLabNative/
│     ├─ main.swift
│     └─ Resources/
└─ scripts/
   ├─ run.sh
   ├─ build_app.sh
   └─ sign_and_notarize.sh
```

## License

License file is not added yet. Add a `LICENSE` file (for example MIT) before broader external contributions.
