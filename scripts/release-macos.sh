#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile name}"
: "${CONTENT_PUBLIC_KEY_BASE64:?Set CONTENT_PUBLIC_KEY_BASE64}"
: "${GITHUB_LATEST_RELEASE_URL:?Set GITHUB_LATEST_RELEASE_URL}"

ADHOC_SIGN=0 CONFIGURATION=release "$ROOT/scripts/build-app.sh"
APP="$ROOT/dist/Dingdang Pet.app"
ZIP="$ROOT/dist/Dingdang-Pet-notarization.zip"
DMG="$ROOT/dist/Dingdang-Pet.dmg"
RW_DMG="$ROOT/dist/Dingdang-Pet-rw.dmg"
STAGING="$ROOT/dist/dmg-staging"

codesign --force --deep --strict --options runtime --timestamp \
  --entitlements "$ROOT/Config/DingdangPet.entitlements" \
  --sign "$DEVELOPER_ID_APPLICATION" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

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
codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"

rm -rf "$STAGING" "$ZIP" "$RW_DMG"
echo "$DMG"
