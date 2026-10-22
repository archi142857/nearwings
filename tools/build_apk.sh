#!/usr/bin/env bash
# 안드로이드 시험용 APK(디버그 서명) 만들기 → build/nearwings-<버전>-<번호>.apk
# 버전 번호(versionCode)는 2026-01-01부터 지난 분이라 늘 커진다. 같은 서명 키라 이전 시험판 위에 덮어 깔린다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"
cd "$ROOT"
VERSION="$(cat VERSION)"
CODE=$(( ($(date -u +%s) - 1767225600) / 60 ))
OUT="$ROOT/build/nearwings-${VERSION}-${CODE}.apk"
mkdir -p build
cp game/export_presets.cfg build/.export_presets.bak
trap 'cp build/.export_presets.bak game/export_presets.cfg' EXIT
sed -i -E "s/^version\/code=.*/version\/code=${CODE}/; s/^version\/name=.*/version\/name=\"${VERSION}\"/" game/export_presets.cfg
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
"$GODOT" --headless --path game --export-debug "Android" "$OUT" 2>&1 | grep -E "ERROR|error|Exporting" | grep -v -i "adb stub" || true
apksigner verify "$OUT"
ls -la "$OUT"
echo "$OUT"
