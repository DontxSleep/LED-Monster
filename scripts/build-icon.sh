#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICONSET="$PWD/build/LEDMonster.iconset"
mkdir -p "$ICONSET"
xcrun swift scripts/prepare-icon.swift Resources/LED-MONSTER-Icon.png Resources/LED-MONSTER-Icon-Fitted.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/LED-MONSTER-Icon-Fitted.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" Resources/LED-MONSTER-Icon-Fitted.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
