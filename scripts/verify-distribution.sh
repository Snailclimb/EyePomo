#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-EyePomo}"
DMG_PATH="${1:-}"

if [[ -z "$DMG_PATH" ]]; then
  DMG_PATH="$(ls -t build/release/*.dmg 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "Usage: scripts/verify-distribution.sh path/to/EyePomo.dmg"
  exit 2
fi

xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --verbose "$DMG_PATH"

mount_plist="$(mktemp)"
mount_point=""

cleanup() {
  if [[ -n "$mount_point" ]]; then
    hdiutil detach "$mount_point" -quiet || true
  fi
  rm -f "$mount_plist"
}
trap cleanup EXIT

hdiutil attach -plist -nobrowse -readonly "$DMG_PATH" > "$mount_plist"
mount_point="$(awk -F'[<>]' '/<key>mount-point<\/key>/{getline; print $3; exit}' "$mount_plist")"

if [[ -z "$mount_point" ]]; then
  echo "Could not determine DMG mount point."
  exit 1
fi

APP_PATH="$mount_point/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app not found in DMG: $APP_PATH"
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"

echo "Distribution verified: $DMG_PATH"
