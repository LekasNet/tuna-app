#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${APP_NAME:-tuna_unofficial_client}"
VOLUME_NAME="${VOLUME_NAME:-Tuna}"
VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml | cut -d+ -f1)"
OUTPUT_DIR="$ROOT_DIR/build/macos/dmg"
STAGING_DIR="$OUTPUT_DIR/staging"
APP_PATH="$ROOT_DIR/build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="$OUTPUT_DIR/${VOLUME_NAME}-${VERSION}.dmg"
FLUTTER_BIN="${FLUTTER_BIN:-}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "DMG can only be built on macOS." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to create a DMG." >&2
  exit 1
fi

if [[ -z "$FLUTTER_BIN" ]]; then
  if [[ -x "/Users/lek4s/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="/Users/lek4s/flutter/bin/flutter"
  else
    FLUTTER_BIN="flutter"
  fi
fi

"$FLUTTER_BIN" build macos --release

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
