#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACT="${1:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-eyepomo-notary}"

if [[ -z "$ARTIFACT" ]]; then
  echo "Usage: NOTARY_PROFILE=<keychain-profile> scripts/notarize.sh path/to/EyePomo.dmg"
  exit 2
fi

if [[ ! -f "$ARTIFACT" ]]; then
  echo "Artifact not found: $ARTIFACT"
  exit 2
fi

xcrun notarytool submit "$ARTIFACT" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
spctl --assess --type open --verbose "$ARTIFACT"

echo "Notarized and stapled: $ARTIFACT"
