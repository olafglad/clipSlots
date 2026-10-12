#!/usr/bin/env bash
# Build ClipSlots.app (the menubar app) from the ClipSlotsApp SwiftPM product.
#
# Usage: scripts/build-app.sh [--debug] [--universal] [--sign IDENTITY] [--out DIR]
#
#   --debug       debug build (enables `--snapshot <dir>` for layout checks)
#   --universal   arm64 + x86_64 via lipo (what CI ships)
#   --sign ID     codesign identity; default: ClipSlots-Dev cert if present
#                 (so Accessibility survives rebuilds), else ad-hoc ("-")
#   --out DIR     where to put ClipSlots.app (default: .build/)
#
# Version comes from Sources/clipslots/main.swift, same as scripts/release.sh,
# unless VERSION is set in the environment.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CONFIG=release
UNIVERSAL=0
SIGN=""
OUT="$REPO_ROOT/.build"
DEV_CERT="ClipSlots-Dev"

while [ $# -gt 0 ]; do
    case "$1" in
        --debug) CONFIG=debug ;;
        --universal) UNIVERSAL=1 ;;
        --sign) SIGN="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ -z "${VERSION:-}" ]; then
    VERSION="$(grep -E '^\s*version: "[0-9]+\.[0-9]+\.[0-9]+"' Sources/clipslots/main.swift \
        | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')"
fi
[ -n "$VERSION" ] || { echo "error: could not read version" >&2; exit 1; }

mkdir -p "$OUT"

# --- Compile ---
if [ "$UNIVERSAL" = 1 ]; then
    for arch in arm64 x86_64; do
        swift build -c "$CONFIG" --product ClipSlotsApp --arch "$arch"
        cp "$(swift build -c "$CONFIG" --product ClipSlotsApp --arch "$arch" --show-bin-path)/ClipSlotsApp" \
            "$OUT/ClipSlotsApp-$arch"
    done
    BIN="$OUT/ClipSlotsApp-universal"
    lipo -create "$OUT/ClipSlotsApp-arm64" "$OUT/ClipSlotsApp-x86_64" -output "$BIN"
    rm -f "$OUT/ClipSlotsApp-arm64" "$OUT/ClipSlotsApp-x86_64"
else
    swift build -c "$CONFIG" --product ClipSlotsApp
    BIN="$(swift build -c "$CONFIG" --product ClipSlotsApp --show-bin-path)/ClipSlotsApp"
fi

# --- Assemble bundle ---
APP="$OUT/ClipSlots.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClipSlots"
[ "$UNIVERSAL" = 1 ] && rm -f "$BIN"
sed "s/__VERSION__/$VERSION/g" App/Info.plist > "$APP/Contents/Info.plist"
cp docs/images/mascot.png "$APP/Contents/Resources/mascot.png"
cp docs/fonts/JetBrainsMono-VariableFont_wght.ttf "$APP/Contents/Resources/JetBrainsMono.ttf"

# App icon from the mascot (sips + iconutil ship with macOS).
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size docs/images/mascot.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double docs/images/mascot.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

# --- Sign ---
if [ -z "$SIGN" ]; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEV_CERT"; then
        SIGN="$DEV_CERT"
    else
        SIGN="-"
    fi
fi
codesign --force --options runtime --sign "$SIGN" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP (v$VERSION, $CONFIG, signed: $SIGN)"
