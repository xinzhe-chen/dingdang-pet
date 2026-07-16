#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="${1:?Usage: publish-pet-release.sh <version> <owner/repo> [catalog-directory]}"
REPOSITORY="${2:?Usage: publish-pet-release.sh <version> <owner/repo> [catalog-directory]}"
CATALOG="${3:-$ROOT/Sources/DingdangPetApp/Resources/DefaultCatalog}"
PRIVATE_KEY="${CONTENT_SIGNING_KEY_FILE:-$ROOT/.content-signing-key}"
OUTPUT="$ROOT/dist/pet-release-$VERSION"
ASSET_BASE="https://github.com/$REPOSITORY/releases/download/pets-v$VERSION"

if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "Missing content signing key: $PRIVATE_KEY" >&2
  exit 1
fi
command -v gh >/dev/null || { echo "gh CLI is required" >&2; exit 1; }

mkdir -p "$ROOT/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

cd "$ROOT"
swift run --disable-sandbox dingdang-pet-tool package "$CATALOG" "$VERSION" "$ASSET_BASE" "$OUTPUT" "$PRIVATE_KEY"
gh release create "pets-v$VERSION" \
  "$OUTPUT/pet-catalog-$VERSION.zip" \
  "$OUTPUT/manifest.json" \
  "$OUTPUT/manifest.sig" \
  --repo "$REPOSITORY" \
  --title "Pet resources v$VERSION" \
  --generate-notes \
  --latest

echo "https://github.com/$REPOSITORY/releases/tag/pets-v$VERSION"
