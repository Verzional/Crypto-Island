#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building CryptoNotch (Release)..."
./scripts/package.sh

echo "🚀 Deploying & Relaunching..."
killall CryptoNotch 2>/dev/null || true
sleep 0.4
rm -rf /Applications/CryptoNotch.app
cp -R CryptoNotch.app /Applications/
open /Applications/CryptoNotch.app

echo "✅ Running at PID $(pgrep -x CryptoNotch)"
