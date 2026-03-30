#!/bin/zsh
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$NATIVE_DIR/.." && pwd)"
APP_NAME="Icon Preview Lab"
EXEC_NAME="IconPreviewLabNative"
OUT_DIR="$NATIVE_DIR/dist"
APP_DIR="$OUT_DIR/$APP_NAME.app"
STAGE_DIR="$OUT_DIR/stage"
RESOURCE_DIR="$NATIVE_DIR/Sources/IconPreviewLabNative/Resources"

if command -v node >/dev/null 2>&1; then
  VERSION="$(node -p "require('$PROJECT_ROOT/package.json').version" 2>/dev/null || echo "1.1.0")"
else
  VERSION="1.1.0"
fi

DMG_PATH="$OUT_DIR/$APP_NAME-$VERSION-native-arm64.dmg"
ICON_SOURCE="$PROJECT_ROOT/ip-icon.icns"

mkdir -p "$OUT_DIR"

cp "$PROJECT_ROOT/index.html" "$RESOURCE_DIR/index.html"
cp "$PROJECT_ROOT/branai-logo.svg" "$RESOURCE_DIR/branai-logo.svg"
cp "$PROJECT_ROOT/branai-icon.svg" "$RESOURCE_DIR/branai-icon.svg"
cp "$PROJECT_ROOT/ip-icon-1024.png" "$RESOURCE_DIR/ip-icon-1024.png"

swift build --configuration release --package-path "$NATIVE_DIR"

BIN_PATH="$NATIVE_DIR/.build/release/$EXEC_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Release binary not found: $BIN_PATH"
  exit 1
fi

rm -rf "$APP_DIR" "$STAGE_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$STAGE_DIR"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$EXEC_NAME"

cp "$NATIVE_DIR/Sources/IconPreviewLabNative/Resources/index.html" "$APP_DIR/Contents/Resources/index.html"
cp "$NATIVE_DIR/Sources/IconPreviewLabNative/Resources/branai-logo.svg" "$APP_DIR/Contents/Resources/branai-logo.svg"
cp "$NATIVE_DIR/Sources/IconPreviewLabNative/Resources/branai-icon.svg" "$APP_DIR/Contents/Resources/branai-icon.svg"
cp "$NATIVE_DIR/Sources/IconPreviewLabNative/Resources/ip-icon-1024.png" "$APP_DIR/Contents/Resources/ip-icon-1024.png"

ICON_FILE_KEY=""
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_DIR/Contents/Resources/icon.icns"
  ICON_FILE_KEY='<key>CFBundleIconFile</key><string>icon.icns</string>'
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$EXEC_NAME</string>
  <key>CFBundleIdentifier</key><string>org.branai.iconpreviewlab.native</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION%.0}</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  $ICON_FILE_KEY
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

xattr -cr "$APP_DIR" || true

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE_DIR"

echo "Native app: $APP_DIR"
echo "Native DMG: $DMG_PATH"
