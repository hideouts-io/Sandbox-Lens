#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -gt 1 ]]; then
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
  exit 2
fi

MODE="run"
if [[ "$#" -eq 1 ]]; then
  MODE="$1"
fi

ROOT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIRECTORY/Config/AppMetadata.sh"
DIST_DIRECTORY="$ROOT_DIRECTORY/dist"
APP_BUNDLE="$DIST_DIRECTORY/$APP_DISPLAY_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE_NAME"

if pgrep -x "$APP_EXECUTABLE_NAME" >/dev/null; then
  pkill -x "$APP_EXECUTABLE_NAME"
fi

cd "$ROOT_DIRECTORY"
swift build
BUILD_DIRECTORY="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIRECTORY/$APP_EXECUTABLE_NAME"
RESOURCE_BUNDLE="$BUILD_DIRECTORY/SandboxLens_SandboxLens.bundle"

"$ROOT_DIRECTORY/scripts/stage_app_bundle.sh" \
  "$BUILD_BINARY" \
  "$RESOURCE_BUNDLE" \
  "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$APP_BUNDLE_IDENTIFIER\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
