#!/usr/bin/env bash
# 자동 검사: 리소스 가져오기 → 단위 시험 → 기기마다 앉을 자리 → 자체 시험(입력 흉내) → 소리 → 기기 크기별 화면 캡처.
# 사용법: tools/check.sh [--no-shots]
set -euo pipefail
SHOTS="${1:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"
cd "$ROOT"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
unit="$("$GODOT" --headless --path game -s res://tests/run_tests.gd 2>&1 || true)"
echo "$unit" | grep -v -E "^Godot Engine|^\s*$" | grep -v -E "^\s+(at:|GDScript backtrace|\[[0-9]+\])" | head -40
if echo "$unit" | grep -q -E "SCRIPT ERROR|^ERROR|실패 [1-9]|단위 시험 0개"; then echo "단위 시험 실패"; exit 1; fi
# 기기마다 새 오는 확률이 같으려면 어느 화면에서나 모든 종이 앉을 자리가 있어야 한다
python3 -I tools/perch_check.py | tail -n 5
# 자체 시험: 가상 화면에서 입력을 흉내 내 가방 여닫기·카메라·셔터·배경 벌·뷰파인더·도감·뒤로 가기를 해 본다 (벌 세 가지를 다 거친다)
# 태블릿은 세로로 시작해 가로로 돌려 본다(벌이 바뀌고 앉은 새를 다시 앉힌다)
# 폰은 로딩 화면을 띄운 채 시작해서 눌러 넘기기부터 해 본다
# 소리(공원 음악, 가방을 열면 먹먹해짐)는 기본으로 켜져 있고, 태블릿 세로는 소리를 끈 채 해 본다
for dev in "1080x2400 2.625 portrait --splash_live" "2400x2160 2.625 square" "1600x2560 2.0 portrait --rotate --sound=0" "2560x1600 2.0 landscape"; do
  set -- $dev
  out="$(xvfb-run -a -s "-screen 0 3200x3200x24" "$GODOT" --path game --rendering-driver opengl3 --audio-driver Dummy \
    --resolution "$1" -- --density="$2" --seed=7 --prewarm --hour=12 --fresh --save=user://selftest_save.json --expect_set="$3" ${4:-} --selftest 2>&1 || true)"
  echo "$out" | grep -E "자체 시험" | sed "s/^/[$1] /"
  errs="$(echo "$out" | grep -E "^(ERROR|SCRIPT ERROR)" | grep -v -i -E "alsa|audio" || true)"
  if [[ -n "$errs" ]]; then echo "$errs" | head -5 | sed "s/^/[$1] /"; echo "엔진 오류 ($1)"; exit 1; fi
  echo "$out" | grep -q "자체 시험 통과" || { echo "자체 시험 실패 ($1)"; exit 1; }
done
# 소리: 무비 메이커로 실제 섞여 나온 소리를 잰다 (공원 음악, 가방을 열면 먹먹해짐)
python3 -I tools/audio_check.py
if [[ "$SHOTS" != "--no-shots" ]]; then
  python3 -I tools/screenshots.py
fi
