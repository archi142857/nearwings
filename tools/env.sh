# 도구 위치. 다른 스크립트가 source 한다.
# NEARWINGS_TOOLS를 지정하지 않으면 /home/claude/tools(클라우드 작업 공간)나 ~/nearwings-tools를 쓴다.
GODOT_VERSION="4.7.2"
if [[ -z "${NEARWINGS_TOOLS:-}" ]]; then
  if [[ -d /home/claude ]]; then NEARWINGS_TOOLS=/home/claude/tools; else NEARWINGS_TOOLS="$HOME/nearwings-tools"; fi
fi
export NEARWINGS_TOOLS
GODOT="${GODOT:-$NEARWINGS_TOOLS/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64}"
ANDROID_SDK="$NEARWINGS_TOOLS/android-sdk"
TEMPLATES="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
