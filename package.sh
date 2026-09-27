#!/bin/zsh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔨 Building CryptoIsland (Release)..."
./reload.sh > /dev/null 2>&1

echo "📦 Packaging CryptoIsland.dmg..."
DMG_ROOT="build/dmg_root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R CryptoIsland.app "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f CryptoIsland.dmg
hdiutil create -volname "CryptoIsland" -srcfolder "$DMG_ROOT" -ov -format UDZO CryptoIsland.dmg > /dev/null 2>&1
rm -rf "$DMG_ROOT"

echo "✅ DMG generated: CryptoIsland.dmg ($(du -h CryptoIsland.dmg | awk '{print $1}'))"
