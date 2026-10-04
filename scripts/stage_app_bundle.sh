#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 BUILD_BINARY RESOURCE_BUNDLE OUTPUT_APP" >&2
  exit 2
fi

ROOT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIRECTORY/Config/AppMetadata.sh"

BUILD_BINARY="$1"
RESOURCE_BUNDLE="$2"
APP_BUNDLE="$3"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIRECTORY/Assets/AppIcon.icns"

case "$APP_BUNDLE" in
  "$ROOT_DIRECTORY"/dist/*.app|"$ROOT_DIRECTORY"/dist/*/*.app)
    ;;
  *)
    echo "refusing to stage outside the project dist directory: $APP_BUNDLE" >&2
    exit 1
    ;;
esac

if [[ ! -x "$BUILD_BINARY" ]]; then
  echo "build executable is missing or is not executable: $BUILD_BINARY" >&2
  exit 1
fi
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "SwiftPM resource bundle is missing: $RESOURCE_BUNDLE" >&2
  exit 1
fi
if [[ ! -f "$APP_ICON_SOURCE" ]]; then
  echo "application icon is missing: $APP_ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/SandboxLens_SandboxLens.bundle"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_BUNDLE_IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$APP_MINIMUM_MACOS_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
/usr/bin/codesign \
  --force \
  --options runtime \
  --timestamp=none \
  --sign - \
  "$APP_BUNDLE" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
