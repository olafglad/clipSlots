#!/bin/bash
# Build a .pkg installer locally for testing.
# Usage: ./scripts/build-pkg.sh [version]
#   e.g. ./scripts/build-pkg.sh 1.0.0

set -euo pipefail

VERSION="${1:-0.0.0-dev}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "Staging pkg root..."
rm -rf pkg-root
mkdir -p pkg-root/usr/local/bin
cp .build/release/clipslots pkg-root/usr/local/bin/
chmod +x pkg-root/usr/local/bin/clipslots
codesign -s - pkg-root/usr/local/bin/clipslots

echo "Building ClipSlots-${VERSION}.pkg..."
pkgbuild \
  --root pkg-root \
  --identifier com.clipslots.pkg \
  --version "$VERSION" \
  --install-location / \
  --scripts scripts/ \
  "ClipSlots-${VERSION}.pkg"

rm -rf pkg-root

echo "Done: ClipSlots-${VERSION}.pkg"
