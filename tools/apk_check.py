#!/usr/bin/env python3
"""만든 APK에서 이름·아이콘·스플래시 설정이 들어갔는지 본다 (androguard 필요: pip install androguard).

- 패키지 이름 com.nearwings.app (결정 기록 2026-10-23)
- 앱 이름: 기본 NearWings, 한국어 새바라기
- 시스템 스플래시: 바탕색 #EFE6D2(색 값), 그림 splash_icon(576×576), Godot 부트 스플래시 끔(--disable_godot_splash)
- 적응형 아이콘 앞·뒤·단색 레이어

사용법: python3 tools/apk_check.py <apk>
"""
import io
import re
import sys
import zipfile

try:
    from loguru import logger
    logger.remove()
except ImportError:
    pass
from androguard.core.apk import APK
from PIL import Image

PACKAGE = "com.nearwings.app"
SPLASH_BG = 0xFFEFE6D2


def main() -> None:
    path = sys.argv[1]
    a = APK(path)
    arsc = a.get_android_resources()
    rpkg = arsc.get_packages_names()[0]
    pub = arsc.get_public_resources(rpkg).decode()
    ids = {int(m.group(3), 16): (m.group(1), m.group(2))
           for m in re.finditer(r'<public type="(\w+)" name="([^"]+)" id="(0x[0-9a-f]+)"', pub)}
    by_name = {v: k for k, v in ids.items()}
    problems = []

    pkg = a.get_package()
    print(f"패키지 {pkg}, 버전 {a.get_androidversion_name()} ({a.get_androidversion_code()})")
    if pkg != PACKAGE:
        problems.append(f"패키지 이름이 {PACKAGE}가 아니다")

    rid = by_name[("string", "godot_project_name_string")]
    labels = {}
    for cfg, entry in arsc.get_res_configs(rid):
        q = cfg.get_qualifier() or "기본"
        labels[q] = arsc.get_resolved_res_configs(rid, cfg)[0][1]
    print(f"앱 이름: 기본 {labels.get('기본')}, ko {labels.get('ko')}, en {labels.get('en')}, ja {labels.get('ja')}")
    if labels.get("기본") != "NearWings" or labels.get("ko") != "새바라기":
        problems.append("앱 이름이 기본 NearWings / 한국어 새바라기가 아니다")

    rid = by_name[("style", "GodotAppSplashTheme")]
    bg = None
    for cfg, entry in arsc.get_res_configs(rid):
        if (cfg.get_qualifier() or "") != "v31":
            continue
        for key, val in entry.item.items:
            if key == 0x0101062C:
                bg = (val.data_type, val.data)
    print(f"스플래시 바탕 (v31): 형식 0x{bg[0]:02x}, 값 0x{bg[1] & 0xFFFFFFFF:08x}" if bg else "스플래시 바탕 없음")
    if not bg or bg[0] != 0x1C or (bg[1] & 0xFFFFFFFF) != SPLASH_BG:
        problems.append("스플래시 바탕이 #EFE6D2 색 값이 아니다")

    z = zipfile.ZipFile(path)
    cl = z.read("assets/_cl_") if "assets/_cl_" in z.namelist() else b""
    print(f"엔진 실행 인자에 --disable_godot_splash: {b'--disable_godot_splash' in cl}")
    if b"--disable_godot_splash" not in cl:
        problems.append("Godot 부트 스플래시가 꺼지지 않았다")

    def img(name):
        return Image.open(io.BytesIO(z.read(name)))

    sp = img("res/drawable/splash_icon.webp")
    print(f"스플래시 그림 {sp.size} {sp.mode}")
    if sp.size != (576, 576):
        problems.append("스플래시 그림 크기가 576이 아니다")
    for layer in ("icon_foreground", "icon_background", "icon_monochrome", "icon"):
        sizes = []
        for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
            n = f"res/mipmap-{d}-v4/{layer}.webp"
            sizes.append(img(n).size[0] if n in z.namelist() else 0)
        print(f"{layer}: {sizes}")
    fg = img("res/mipmap-xxxhdpi-v4/icon_foreground.webp").convert("RGBA")
    bgimg = img("res/mipmap-xxxhdpi-v4/icon_background.webp").convert("RGB")
    c = bgimg.getpixel((10, 10))
    print(f"뒤 레이어 색 {c}, 앞 레이어 불투명 화소 {sum(1 for p in fg.get_flattened_data() if p[3] > 0)}")
    if any(abs(c[i] - (0xEF, 0xE6, 0xD2)[i]) > 2 for i in range(3)):
        problems.append("적응형 아이콘 뒤 레이어가 #EFE6D2가 아니다")

    if problems:
        for p in problems:
            print("문제: " + p)
        sys.exit(1)
    print("APK 확인 통과")


if __name__ == "__main__":
    main()
