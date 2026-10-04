#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi

OUTPUT_DIRECTORY="$1"
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion)"
RELEASE_ID="macos-${PRODUCT_VERSION}-${BUILD_VERSION}"
RELEASE_DIRECTORY="$OUTPUT_DIRECTORY/$RELEASE_ID"

if [[ -e "$RELEASE_DIRECTORY" ]]; then
  echo "refusing to merge into existing release directory: $RELEASE_DIRECTORY" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIRECTORY/usr/share" "$RELEASE_DIRECTORY/System/Library/Sandbox"

if [[ -d /usr/share/sandbox ]]; then
  cp -R /usr/share/sandbox "$RELEASE_DIRECTORY/usr/share/sandbox"
fi

if [[ -d /System/Library/Sandbox/Profiles ]]; then
  cp -R /System/Library/Sandbox/Profiles \
    "$RELEASE_DIRECTORY/System/Library/Sandbox/Profiles"
fi

cat >"$RELEASE_DIRECTORY/provenance.json" <<JSON
{
  "id": "$RELEASE_ID",
  "displayName": "macOS $PRODUCT_VERSION ($BUILD_VERSION)",
  "productVersion": "$PRODUCT_VERSION",
  "buildVersion": "$BUILD_VERSION",
  "releaseChannel": "stable",
  "sourceName": "Locally installed Apple system",
  "sourceURL": "",
  "sourceCommit": "",
  "confidence": "local-system-snapshot",
  "notes": "Captured read-only from the standard system sandbox-profile directories on this Mac."
}
JSON

echo "Saved local baseline snapshot to $RELEASE_DIRECTORY"
