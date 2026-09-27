#!/bin/zsh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔨 Building CryptoIsland (Release)..."
xcodebuild -scheme CryptoIsland -configuration Release -derivedDataPath build build > /dev/null 2>&1
rm -rf CryptoIsland.app
cp -R build/Build/Products/Release/CryptoIsland.app ./

# Detect Developer ID Application signing identity, fallback to ad-hoc (-)
SIGN_ID=$(security find-identity -p codesigning -v | grep "Developer ID Application:" | head -n 1 | awk -F '"' '{print $2}')

if [ -n "$SIGN_ID" ]; then
    echo "🔏 Signing with Developer ID: $SIGN_ID"
    codesign -s "$SIGN_ID" --force --deep --options runtime --timestamp CryptoIsland.app
else
    echo "⚠️  Developer ID not found. Signing ad-hoc..."
    codesign -s - --force --deep CryptoIsland.app
fi

echo "📦 Packaging CryptoIsland.dmg..."
DMG_ROOT="build/dmg_root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R CryptoIsland.app "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f CryptoIsland.dmg
hdiutil create -volname "CryptoIsland" -srcfolder "$DMG_ROOT" -ov -format UDZO CryptoIsland.dmg > /dev/null 2>&1
rm -rf "$DMG_ROOT"

if [ -n "$SIGN_ID" ]; then
    echo "🔏 Signing CryptoIsland.dmg..."
    codesign -s "$SIGN_ID" --force --timestamp CryptoIsland.dmg
fi

# Optional Notarization step if NOTARY_PROFILE is configured
if [ -n "$NOTARY_PROFILE" ]; then
    echo "🚀 Submitting to Apple Notary Service ($NOTARY_PROFILE)..."
    xcrun notarytool submit CryptoIsland.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple CryptoIsland.dmg
fi

echo "✅ DMG generated: CryptoIsland.dmg ($(du -h CryptoIsland.dmg | awk '{print $1}'))"
