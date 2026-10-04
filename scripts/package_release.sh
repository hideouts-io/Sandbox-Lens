#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 0 ]]; then
  echo "usage: $0" >&2
  exit 2
fi

ROOT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIRECTORY/Config/AppMetadata.sh"

RELEASE_DIRECTORY="$ROOT_DIRECTORY/dist/release"
APP_BUNDLE="$RELEASE_DIRECTORY/$APP_DISPLAY_NAME.app"
ARCHIVE_NAME="Sandbox-Lens-v$APP_VERSION-macOS-universal.zip"
ARCHIVE_PATH="$RELEASE_DIRECTORY/$ARCHIVE_NAME"
CHECKSUM_PATH="$RELEASE_DIRECTORY/SHA256SUMS.txt"
EXTRACTION_DIRECTORY="$(mktemp -d /private/tmp/SandboxLens-release-verification.XXXXXX)"

cleanup() {
  rm -rf "$EXTRACTION_DIRECTORY"
}
trap cleanup EXIT

verify_binary() {
  local binary_path="$1"
  local architecture
  local minimum_version

  for architecture in arm64 x86_64; do
    /usr/bin/lipo "$binary_path" -verify_arch "$architecture"
    minimum_version="$(
      /usr/bin/vtool -show-build -arch "$architecture" "$binary_path" \
        | /usr/bin/awk '$1 == "minos" { print $2; exit }'
    )"
    if [[ "$minimum_version" != "$APP_MINIMUM_MACOS_VERSION" ]]; then
      echo "binary minimum macOS mismatch for $architecture: expected $APP_MINIMUM_MACOS_VERSION, found $minimum_version" >&2
      exit 1
    fi
  done
}

rm -rf "$RELEASE_DIRECTORY"
mkdir -p "$RELEASE_DIRECTORY"

cd "$ROOT_DIRECTORY"
swift package clean
swift test
PYTHONPATH="$ROOT_DIRECTORY/scripts" python3 -m unittest discover \
  -s "$ROOT_DIRECTORY/Tests/Scripts" \
  -v
python3 "$ROOT_DIRECTORY/scripts/check_repository.py"

while IFS= read -r shell_script; do
  /bin/bash -n "$shell_script"
done < <(/usr/bin/find "$ROOT_DIRECTORY/script" "$ROOT_DIRECTORY/scripts" -type f -name '*.sh' -print)

swift build -c release --arch arm64 --arch x86_64

BUILD_DIRECTORY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BUILD_BINARY="$BUILD_DIRECTORY/$APP_EXECUTABLE_NAME"
RESOURCE_BUNDLE="$BUILD_DIRECTORY/SandboxLens_SandboxLens.bundle"

"$ROOT_DIRECTORY/scripts/stage_app_bundle.sh" \
  "$BUILD_BINARY" \
  "$RESOURCE_BUNDLE" \
  "$APP_BUNDLE"

verify_binary "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE_NAME"
(
  cd "$RELEASE_DIRECTORY"
  /usr/bin/zip -q -r -y -X "$ARCHIVE_NAME" "$APP_DISPLAY_NAME.app"
)

ARCHIVE_ENTRIES="$(/usr/bin/unzip -Z1 "$ARCHIVE_PATH")"
if /usr/bin/grep -qE '(^__MACOSX/|/\._)' <<<"$ARCHIVE_ENTRIES"; then
  echo "release archive contains unwanted AppleDouble metadata: $ARCHIVE_PATH" >&2
  exit 1
fi

cd "$RELEASE_DIRECTORY"
/usr/bin/shasum -a 256 "$ARCHIVE_NAME" >"$CHECKSUM_PATH"

/usr/bin/ditto -x -k "$ARCHIVE_PATH" "$EXTRACTION_DIRECTORY"
EXTRACTED_APP="$EXTRACTION_DIRECTORY/$APP_DISPLAY_NAME.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
verify_binary "$EXTRACTED_APP/Contents/MacOS/$APP_EXECUTABLE_NAME"

EXTRACTED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXTRACTED_APP/Contents/Info.plist")"
EXTRACTED_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXTRACTED_APP/Contents/Info.plist")"
EXTRACTED_MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$EXTRACTED_APP/Contents/Info.plist")"

if [[ "$EXTRACTED_VERSION" != "$APP_VERSION" ]]; then
  echo "release version mismatch: expected $APP_VERSION, found $EXTRACTED_VERSION" >&2
  exit 1
fi
if [[ "$EXTRACTED_BUILD" != "$APP_BUILD_NUMBER" ]]; then
  echo "release build mismatch: expected $APP_BUILD_NUMBER, found $EXTRACTED_BUILD" >&2
  exit 1
fi
if [[ "$EXTRACTED_MINIMUM" != "$APP_MINIMUM_MACOS_VERSION" ]]; then
  echo "minimum macOS mismatch: expected $APP_MINIMUM_MACOS_VERSION, found $EXTRACTED_MINIMUM" >&2
  exit 1
fi

printf 'Release archive: %s\n' "$ARCHIVE_PATH"
printf 'Checksum manifest: %s\n' "$CHECKSUM_PATH"
