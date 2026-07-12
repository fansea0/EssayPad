#!/usr/bin/env bash
# Build the current EssayPad Mobile Android APK.
# Usage:
#   ./build_android.sh            # release APK
#   ./build_android.sh --debug    # debug APK

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="release"

case "${1:-}" in
  ""|--release) ;;
  --debug) MODE="debug" ;;
  --help|-h)
    printf 'Usage: %s [--release|--debug]\n' "$0"
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    exit 1
    ;;
esac

cd "$SCRIPT_DIR"
VERSION="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
OUTPUT_DIR="$SCRIPT_DIR/dist"
SOURCE_APK="$SCRIPT_DIR/build/app/outputs/flutter-apk/app-$MODE.apk"
OUTPUT_APK="$OUTPUT_DIR/essaypad-mobile-$VERSION-$MODE.apk"

printf '\033[1;36mBuilding Android %s APK (version %s)\033[0m\n' "$MODE" "$VERSION"
flutter build apk "--$MODE"

if [[ ! -f "$SOURCE_APK" ]]; then
  printf 'APK was not produced: %s\n' "$SOURCE_APK" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_APK" "$OUTPUT_APK"
CHECKSUM="$(shasum -a 256 "$OUTPUT_APK" | awk '{print $1}')"

printf '\033[1;32mAPK ready\033[0m\n'
printf 'Path: %s\n' "$OUTPUT_APK"
printf 'SHA-256: %s\n' "$CHECKSUM"
