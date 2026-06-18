#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Compilation (release)…"
swift build -c release

APP="Mousy.app"
echo "▸ Assemblage de ${APP} ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Mousy "$APP/Contents/MacOS/Mousy"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signature ad-hoc (stabilise les autorisations)…"
codesign --force --deep --sign - "$APP"

echo "✅ $APP prêt."
echo "   Lance-le avec :  open ${APP}"
