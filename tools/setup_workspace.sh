#!/usr/bin/env bash
# 코드 세션 작업 공간(리눅스) 준비. 여러 번 돌려도 된다.
#   - Godot 편집기 (GitHub 릴리스)
#   - 안드로이드 내보내기 템플릿: 1.3GB 묶음에서 필요한 3개 파일만 범위 요청으로 받는다
#   - apksigner·zipalign (apt), Godot가 확인하는 최소한의 가짜 안드로이드 SDK
#   - 편집기 설정: SDK·자바 경로, 디버그 서명 키(저장소의 tools/keys/debug.keystore)
# Gradle 빌드(플러그인·위젯)는 이 작업 공간에서 Google·Gradle 저장소가 막혀 있어 안 된다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"
REL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

mkdir -p "$NEARWINGS_TOOLS/godot"
if [[ ! -x "$GODOT" ]]; then
  echo "== Godot ${GODOT_VERSION} 받는 중"
  curl -sSL --fail -o "$NEARWINGS_TOOLS/godot/godot.zip" "$REL/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  python3 -I -m zipfile -e "$NEARWINGS_TOOLS/godot/godot.zip" "$NEARWINGS_TOOLS/godot/"
  chmod +x "$GODOT"
fi
ln -sf "$GODOT" "$NEARWINGS_TOOLS/godot/godot"

if ! command -v apksigner >/dev/null || ! command -v zipalign >/dev/null || ! command -v xvfb-run >/dev/null; then
  echo "== apksigner, zipalign, xvfb 설치"
  apt-get update -qq && apt-get install -y -qq apksigner zipalign xvfb >/dev/null
fi
python3 -c "import requests, PIL, numpy" 2>/dev/null || pip install --break-system-packages -q requests pillow numpy

if [[ ! -f "$TEMPLATES/android_debug.apk" ]]; then
  echo "== 안드로이드 템플릿 받는 중 (필요한 파일만)"
  mkdir -p "$NEARWINGS_TOOLS/tpl_dl" "$TEMPLATES"
  python3 -I "$ROOT/tools/rangezip.py" "$REL/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    "$NEARWINGS_TOOLS/tpl_dl" templates/android_debug.apk templates/android_release.apk templates/version.txt
  cp "$NEARWINGS_TOOLS/tpl_dl/templates/"{android_debug.apk,android_release.apk,version.txt} "$TEMPLATES/"
fi

mkdir -p "$ANDROID_SDK/build-tools/34.0.0" "$ANDROID_SDK/platform-tools"
ln -sf "$(command -v apksigner)" "$ANDROID_SDK/build-tools/34.0.0/apksigner"
ln -sf "$(command -v zipalign)" "$ANDROID_SDK/build-tools/34.0.0/zipalign"
if [[ ! -x "$ANDROID_SDK/platform-tools/adb" ]]; then
  printf '#!/bin/sh\necho "adb stub: $*"\nexit 0\n' > "$ANDROID_SDK/platform-tools/adb"
  chmod +x "$ANDROID_SDK/platform-tools/adb"
fi

SETTINGS="$HOME/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
if [[ ! -f "$SETTINGS" ]]; then
  echo "== 편집기 설정 파일 만들기"
  "$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
fi
JAVA_HOME_GUESS="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
python3 -I - "$SETTINGS" "$ANDROID_SDK" "$JAVA_HOME_GUESS" "$ROOT/tools/keys/debug.keystore" <<'PY'
import re, sys
path, sdk, java, key = sys.argv[1:]
want = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": java,
    "export/android/debug_keystore": key,
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
text = open(path, encoding="utf-8").read()
for k, v in want.items():
    line = f'{k} = "{v}"'
    if re.search(rf"^{re.escape(k)} = .*$", text, flags=re.M):
        text = re.sub(rf"^{re.escape(k)} = .*$", line, text, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n" + line + "\n"
open(path, "w", encoding="utf-8").write(text)
print("편집기 설정:", ", ".join(want))
PY
echo "== 준비 끝: $GODOT"
