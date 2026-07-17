#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="${1:-$ROOT/Assets/AppIcon.png}"
ICONSET="$ROOT/.build/AppIcon.iconset"
OUTPUT="$ROOT/Sources/DingdangPetApp/Resources/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing 1024x1024 icon source: $SOURCE" >&2
  exit 1
fi

WIDTH=$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')
if [[ "$WIDTH" != "1024" || "$HEIGHT" != "1024" ]]; then
  echo "Icon source must be exactly 1024x1024; got ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET" "${OUTPUT:h}"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  size=${spec%% *}
  filename=${spec#* }
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$filename" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "$OUTPUT"
