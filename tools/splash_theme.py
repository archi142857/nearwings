#!/usr/bin/env python3
"""안드로이드 내보내기 템플릿에서 시스템 스플래시 바탕색을 #EFE6D2로 박은 사본을 만든다.

Godot 4.7.2 템플릿(Gradle 없이 내보내기)은 스플래시 테마(GodotAppSplashTheme, API 31+)의
android:windowSplashScreenBackground를 @mipmap/icon_background(적응형 아이콘 뒤 레이어 그림)로 둔다.
이 속성은 색만 받으므로 그림을 가리키면 안드로이드가 읽지 못하고 창 바탕의 어림 색(어두운 테마 색일 수 있다)을 쓴다.
Gradle 빌드라면 내보내기 설정 splash_screen/background_color로 바꾸지만 이 작업 공간에서는 Gradle을 못 쓴다.
그래서 템플릿의 resources.arsc에서 그 값(참조, 8바이트)을 같은 크기의 색 값(TYPE_INT_COLOR_ARGB8)으로 바꾼다.
나머지 파일은 그대로 옮긴다. 내보낼 때 Godot가 다시 정렬하고 서명한다.

사용법: python3 tools/splash_theme.py <원본 android_debug.apk> <만들 apk> [색, 기본 efe6d2]
"""
import struct
import sys
import zipfile

ATTR_SPLASH_BG = 0x0101062C        # android:windowSplashScreenBackground
TYPE_REFERENCE = 0x01
TYPE_INT_COLOR_ARGB8 = 0x1C


def patch_arsc(data: bytes, rgb: int) -> bytes:
    # ResTable_map: name(uint32) + Res_value(size uint16 = 8, res0 uint8, dataType uint8, data uint32)
    key = struct.pack("<IHBB", ATTR_SPLASH_BG, 8, 0, TYPE_REFERENCE)
    hits = []
    i = data.find(key)
    while i >= 0:
        hits.append(i)
        i = data.find(key, i + 1)
    if len(hits) != 1:
        raise SystemExit(f"resources.arsc에서 스플래시 바탕 참조를 {len(hits)}곳 찾았다 (1곳이어야 한다)")
    at = hits[0]
    old_ref = struct.unpack_from("<I", data, at + 8)[0]
    out = bytearray(data)
    struct.pack_into("<BI", out, at + 7, TYPE_INT_COLOR_ARGB8, 0xFF000000 | rgb)
    print(f"resources.arsc {at:#x}: 0x{old_ref:08x}(참조) → #{rgb:06x}(색)")
    return bytes(out)


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    rgb = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xEFE6D2
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info)
            if info.filename == "resources.arsc":
                data = patch_arsc(data, rgb)
            zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zout.writestr(zi, data)


if __name__ == "__main__":
    main()
