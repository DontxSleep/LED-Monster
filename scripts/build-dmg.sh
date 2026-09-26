#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash build.sh
task_dmg_dir=$(mktemp -d "$PWD/build/dmg.XXXXXX")
task_dmg_stage="$task_dmg_dir/contents"
task_dmg_mount="$task_dmg_dir/mounted"
task_dmg_image="$task_dmg_dir/LED Monster.dmg"
task_dmg_attached=false
cleanup() {
    if [ "$task_dmg_attached" = true ]; then
        hdiutil detach "$task_dmg_mount" >/dev/null || true
    fi
}
trap cleanup EXIT

mkdir -p "$task_dmg_stage" "$task_dmg_mount"
ditto "artifacts/LED MØNSTER.app" "$task_dmg_stage/LED MØNSTER.app"
cp "read me.md" "$task_dmg_stage/read me.md"
ln -s /Applications "$task_dmg_stage/Applications"

hdiutil create -volname "LED Monster" -fs HFS+ -format UDZO \
    -srcfolder "$task_dmg_stage" "$task_dmg_image"
hdiutil verify "$task_dmg_image"
hdiutil attach -readonly -nobrowse -mountpoint "$task_dmg_mount" "$task_dmg_image"
task_dmg_attached=true
codesign --verify --deep --strict "$task_dmg_mount/LED MØNSTER.app"
test -x "$task_dmg_mount/LED MØNSTER.app/Contents/MacOS/LEDMonster"
test "$(readlink "$task_dmg_mount/Applications")" = /Applications
cmp "read me.md" "$task_dmg_mount/read me.md"
cmp "artifacts/LED MØNSTER.app/Contents/Info.plist" "$task_dmg_mount/LED MØNSTER.app/Contents/Info.plist"
hdiutil detach "$task_dmg_mount"
task_dmg_attached=false

if [ -f "artifacts/LED Monster.dmg" ]; then
    cp "artifacts/LED Monster.dmg" "$task_dmg_dir/LED Monster-before-rebuild.dmg"
fi
cp "$task_dmg_image" "artifacts/LED Monster.dmg"
printf 'Built and verified %s\n' "$PWD/artifacts/LED Monster.dmg"
