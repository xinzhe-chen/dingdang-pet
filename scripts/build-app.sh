#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Dingdang Pet"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
MODULE_CACHE="$ROOT/.build/module-cache"

mkdir -p "$MODULE_CACHE" "$DIST"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE"

BIN_DIR=$(cd "$ROOT" && swift build -c "$CONFIGURATION" --product DingdangPet --disable-sandbox --show-bin-path)
cd "$ROOT"
swift build -c "$CONFIGURATION" --product DingdangPet --disable-sandbox

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/DingdangPet" "$APP/Contents/MacOS/DingdangPet"
cp "$ROOT/Config/Info.plist" "$APP/Contents/Info.plist"

cp -R "$ROOT/Sources/DingdangPetApp/Resources/." "$APP/Contents/Resources/"

if [[ -n "${CONTENT_PUBLIC_KEY_BASE64:-}" || -n "${GITHUB_LATEST_RELEASE_URL:-}" ]]; then
  CONFIG_FILE="$APP/Contents/Resources/AppConfig.json"
  TMP=$(mktemp)
  jq \
    --arg url "${GITHUB_LATEST_RELEASE_URL:-}" \
    --arg key "${CONTENT_PUBLIC_KEY_BASE64:-}" \
    '.githubLatestReleaseURL = (if $url == "" then .githubLatestReleaseURL else $url end) | .contentPublicKeyBase64 = (if $key == "" then .contentPublicKeyBase64 else $key end)' \
    "$CONFIG_FILE" > "$TMP"
  mv "$TMP" "$CONFIG_FILE"
fi

if [[ "${ADHOC_SIGN:-1}" == "1" ]]; then
  codesign --force --deep --options runtime --sign - "$APP"
fi

echo "$APP"
