#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-EyePomo}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/release}"
APP_PATH="${1:-$BUILD_DIR/export/$APP_NAME.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Run scripts/archive.sh first, or pass a signed .app path."
  exit 2
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
DMG_PATH="${DMG_PATH:-$BUILD_DIR/$APP_NAME-v$VERSION.dmg}"
DMG_ROOT="$BUILD_DIR/dmg-root"

rm -rf "$DMG_ROOT" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$DMG_ROOT"

ditto "$APP_PATH" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" | tee "$DMG_PATH.sha256"
echo "Created DMG: $DMG_PATH"
