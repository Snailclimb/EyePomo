#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-EyePomo.xcodeproj}"
SCHEME="${SCHEME:-EyePomo}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-EyePomo}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/$APP_NAME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_DIR/export}"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "No Developer ID Application signing identity found in the current keychain."
  echo "Install an Apple Developer ID Application certificate before archiving for release."
  exit 2
fi

if [[ -z "${DEVELOPMENT_TEAM:-}" ]] && \
  xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    | grep -q "_DEVELOPMENT_TEAM_IS_EMPTY = YES"; then
  echo "DEVELOPMENT_TEAM is not set in the project or environment."
  echo "Run with DEVELOPMENT_TEAM=<Apple Team ID> scripts/archive.sh, or set the team in Xcode."
  exit 2
fi

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

archive_args=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=macOS"
  -archivePath "$ARCHIVE_PATH"
  clean
  archive
  CODE_SIGN_IDENTITY="Developer ID Application"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  archive_args+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

"${archive_args[@]}"

team_xml=""
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  team_xml=$'\t<key>teamID</key>\n\t<string>'"$DEVELOPMENT_TEAM"$'</string>\n'
fi

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
${team_xml}	<key>stripSwiftSymbols</key>
	<true/>
</dict>
</plist>
PLIST

export_args=(
  xcodebuild
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS"
  -exportPath "$EXPORT_PATH"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  export_args+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

"${export_args[@]}"

APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected exported app not found: $APP_PATH"
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Exported signed app: $APP_PATH"
