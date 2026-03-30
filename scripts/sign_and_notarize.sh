#!/bin/zsh
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$NATIVE_DIR/dist"

APP_PATH="${1:-}"
DMG_PATH="${2:-}"

if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$(ls -1d "$DIST_DIR"/*.app 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$DMG_PATH" ]]; then
  DMG_PATH="$(ls -1 "$DIST_DIR"/*.dmg 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "App bundle not found. Build first: scripts/build_app.sh"
  exit 1
fi

if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "DMG not found. Build first: scripts/build_app.sh"
  exit 1
fi

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "Missing SIGNING_IDENTITY."
  echo "Example: export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'"
  exit 1
fi

if [[ -z "$APPLE_TEAM_ID" ]]; then
  echo "Missing APPLE_TEAM_ID."
  echo "Example: export APPLE_TEAM_ID='ABCDE12345'"
  exit 1
fi

if [[ -z "$NOTARYTOOL_PROFILE" && ( -z "$APPLE_ID" || -z "$APPLE_APP_SPECIFIC_PASSWORD" ) ]]; then
  echo "Notarization credentials missing."
  echo "Use one of:"
  echo "  1) NOTARYTOOL_PROFILE=<keychain-profile>"
  echo "  2) APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID"
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
SIGNED_DMG_PATH="${DMG_PATH%.dmg}-signed.dmg"
STAGE_DIR="$DIST_DIR/notary-stage"

echo "Signing app: $APP_PATH"
codesign --force --deep --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Repacking DMG with signed app..."
rm -rf "$STAGE_DIR" "$SIGNED_DMG_PATH"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$SIGNED_DMG_PATH"

echo "Signing DMG: $SIGNED_DMG_PATH"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$SIGNED_DMG_PATH"
codesign --verify --verbose=2 "$SIGNED_DMG_PATH"

echo "Submitting for notarization..."
if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
  xcrun notarytool submit "$SIGNED_DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --team-id "$APPLE_TEAM_ID" --wait
else
  xcrun notarytool submit "$SIGNED_DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler staple "$SIGNED_DMG_PATH"

echo "Gatekeeper checks:"
spctl --assess --type execute --verbose=4 "$APP_PATH" || true
spctl --assess --type open --verbose=4 "$SIGNED_DMG_PATH" || true

rm -rf "$STAGE_DIR"

echo "Done."
echo "Signed/notarized DMG: $SIGNED_DMG_PATH"
