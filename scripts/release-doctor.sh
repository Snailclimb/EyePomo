#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift test --package-path Packages/EyePomoCore
xcodebuild -project EyePomo.xcodeproj -scheme EyePomo -destination "platform=macOS" build

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "Developer ID Application identity: present"
else
  echo "Developer ID Application identity: missing"
fi

xcodebuild -showBuildSettings -project EyePomo.xcodeproj -scheme EyePomo -configuration Release \
  | grep -E "PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION|CURRENT_PROJECT_VERSION|DEVELOPMENT_TEAM|ENABLE_HARDENED_RUNTIME|CODE_SIGN_ENTITLEMENTS"
