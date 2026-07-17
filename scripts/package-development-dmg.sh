#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Dingdang Pet.app"
DMG="$ROOT/dist/Dingdang-Pet-development.dmg"
RW_DMG="$ROOT/dist/Dingdang-Pet-development-rw.dmg"
STAGING="$ROOT/dist/development-dmg-staging"

ADHOC_SIGN=1 CONFIGURATION=release "$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$DMG" "$RW_DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGING/.VolumeIcon.icns"
hdiutil create -volname "Dingdang Pet" -srcfolder "$STAGING" -ov -format UDRW "$RW_DMG"

MOUNT=$(mktemp -d /tmp/DingdangPetDMG.XXXXXX)
trap 'hdiutil detach "$MOUNT" >/dev/null 2>&1 || true' EXIT
hdiutil attach -nobrowse -mountpoint "$MOUNT" "$RW_DMG" >/dev/null
SetFile -a C "$MOUNT"
hdiutil detach "$MOUNT" >/dev/null
trap - EXIT
rmdir "$MOUNT"

hdiutil convert "$RW_DMG" -ov -format UDZO -o "$DMG" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"
rm -rf "$STAGING" "$RW_DMG"

echo "Development-only DMG (ad-hoc signed): $DMG"
echo "A downloaded copy requires Finder > Open on first launch. Use release-macos.sh for normal double-click distribution."
