#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build artifacts
bash scripts/build-icon.sh
APP="$PWD/artifacts/LED MØNSTER.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos13.0 -module-cache-path "$PWD/build/module-cache" Sources/*.swift -o "$APP/Contents/MacOS/LEDMonster" -framework SwiftUI -framework AppKit -framework CoreBluetooth -framework CoreMIDI
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
cp protocol-analysis/confirmed-profile.json "$APP/Contents/Resources/"
cp Resources/MonsterRGB-Mouth.png "$APP/Contents/Resources/"
cp PROTOCOL.md "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/artifacts/LED-Monster-Mac.zip"
printf 'Built %s\n' "$APP"
