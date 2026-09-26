#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(node -e 'const fs=require("node:fs"); process.stdout.write(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).version)' "$ROOT_DIR/manifest.json")
DIST_DIR="$ROOT_DIR/dist"
OUTPUT="$DIST_DIR/repost-companion-$VERSION.zip"

mkdir -p "$DIST_DIR"
cd "$ROOT_DIR"
zip -q -r -X -FS "$OUTPUT" manifest.json popup.html popup.css src/core.js src/popup.js icons/icon-16.png icons/icon-48.png icons/icon-128.png
printf 'Created %s\n' "$OUTPUT"
