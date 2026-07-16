#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Dingdang Pet.app"
DMG="$ROOT/dist/Dingdang-Pet-development.dmg"
STAGING="$ROOT/dist/development-dmg-staging"

ADHOC_SIGN=1 CONFIGURATION=release "$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Dingdang Pet" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
codesign --verify --deep --strict --verbose=2 "$APP"
rm -rf "$STAGING"

echo "Development-only DMG (ad-hoc signed): $DMG"
echo "A downloaded copy requires Finder > Open on first launch. Use release-macos.sh for normal double-click distribution."
