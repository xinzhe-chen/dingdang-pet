#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PRIVATE_KEY="${1:-$ROOT/.content-signing-key}"
PUBLIC_KEY="${2:-$ROOT/Config/content-public-key.txt}"

mkdir -p "$ROOT/.build/module-cache" "${PUBLIC_KEY:h}"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
cd "$ROOT"
swift run --disable-sandbox dingdang-pet-tool generate-key "$PRIVATE_KEY" "$PUBLIC_KEY"
chmod 600 "$PRIVATE_KEY"
echo "Keep $PRIVATE_KEY private and back it up securely."
echo "Use the public key in AppConfig.json or CONTENT_PUBLIC_KEY_BASE64 when building the app."
