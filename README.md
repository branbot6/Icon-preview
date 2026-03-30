# BranAI Icon Preview Lab

A lightweight open-source macOS tool to preview SVG icons in real UI contexts and export ready-to-use assets.

Most icon tools stop at static preview. BranAI Icon Preview Lab also exports an installable macOS DMG from your current icon, so you can validate the icon in real install/use scenarios.

## Quick Start (From Source)

```bash
git clone https://github.com/branbot6/Icon-Preview-Lab.git
cd Icon-Preview-Lab
swift build
swift run IconPreviewLabNative
```

## What It Does

### Import

- Load SVG via native file picker or drag-and-drop

### Preview

- Favicon context
- Web tab + logo context
- macOS app icon scenes
- iOS app icon scenes

### Export

- Export macOS DMG directly from the current icon (core differentiator)
- Export 1024x1024 PNG (native save dialog)

## Why It Matters

- You do not only preview icons; you can package and test them in a real macOS install flow.
- This closes the gap between "looks good in preview" and "looks right in actual app distribution".

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
xattr -dr com.apple.quarantine "/Applications/Icon Preview Lab.app"
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
Icon-Preview-Lab/
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

This project is licensed under the MIT License.

- You can use, modify, and distribute this project (including commercial use).
- Keep the original copyright notice and license text.
- The software is provided "as is", without warranty.

See [LICENSE](./LICENSE) for full text.
