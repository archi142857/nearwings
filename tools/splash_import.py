#!/usr/bin/env python3
"""로딩 화면과 앱 아이콘 파일 만들기: art/splash/의 1칸 = 1화소 원본에서 게임용 그림과 안드로이드 아이콘을 만든다.

입력 (art/splash/, tools/splash_extract.py가 디자인 시안 화면에서 뽑은 것):
  - magpie_1x.png   까치 전체 (뒤 날개 포함)
  - front_1x.png    앞 층만 (뒤 날개를 뺀 그림, 아이콘과 로딩 첫 장면)
  - name_ko_1x.png, name_en_1x.png  이름 글자
  - layout.json     칸 격자 안 자리
출력:
  game/assets/splash/
    - full.png, front.png   캔버스 그림 (바탕 #EFE6D2를 채운 불투명 그림. 셰이더가 둘을 뒤 날개 알파만큼 섞는다)
    - name_ko.png, name_en.png
    - splash.json           자리와 크기 (layout.json에서 게임에 필요한 것)
  game/assets/icon/
    - adaptive_fg.png       적응형 아이콘 앞 레이어 432×432 (108dp = 192칸, 앞 층, 바탕 투명)
    - adaptive_bg.png       뒤 레이어 432×432 (#EFE6D2)
    - adaptive_mono.png     테마 아이콘(안드로이드 13+) 단색 레이어 432×432: 밝기 120 미만인 칸만 채운다(흰 깃은 비움)
    - icon_192.png          옛 안드로이드용 아이콘 192×192 (아이콘 B, 바탕 채움)
    - splash_icon.png       시스템 스플래시 그림 576×576 (적응형 앞 레이어와 같은 192칸, 칸당 3화소)
  game/icon.png             프로젝트 아이콘 256×256 (아이콘 B, 칸당 2화소)

아이콘을 칸당 정수가 아닌 화소로 줄일 때(432 = 칸당 2.25화소, 192 = 1.5화소)는 칸 넓이만큼 평균한다.

사용법: python3 tools/splash_import.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "splash"
OUT = ROOT / "game" / "assets" / "splash"
ICON_OUT = ROOT / "game" / "assets" / "icon"
MONO_LUMA = 120     # 디자인의 테마 아이콘 시안과 칸마다 같은 기준 (밝기 = 0.299R + 0.587G + 0.114B)


def rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA")).astype(np.float64)


def hex_rgb(s: str) -> np.ndarray:
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], np.float64)


def on_paper(a: np.ndarray, paper: np.ndarray) -> np.ndarray:
    """투명한 칸을 바탕색으로 채운 불투명 그림 (uint8 RGB)."""
    al = a[..., 3:4] / 255.0
    return np.round(a[..., :3] * al + paper * (1.0 - al)).astype(np.uint8)


def area_resize(a: np.ndarray, cells: int, size: int) -> np.ndarray:
    """cells×cells칸 RGBA를 size×size화소로: 칸을 넓이만큼 평균한다(알파를 곱해 평균한 뒤 나눈다)."""
    from math import gcd
    g = gcd(cells, size)
    up = size // g            # 칸을 up배로 늘린 뒤
    down = cells // g         # down×down 화소씩 평균
    big = a.repeat(up, axis=0).repeat(up, axis=1)
    pm = big.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    n = big.shape[0] // down
    pm = pm.reshape(n, down, n, down, 4).mean(axis=(1, 3))
    out = pm.copy()
    al = out[..., 3:4]
    out[..., :3] = np.where(al > 0, out[..., :3] * 255.0 / np.maximum(al, 1e-9), 0)
    return np.clip(np.round(out), 0, 255).astype(np.uint8)


def save(a: np.ndarray, path: Path, mode: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(a, mode).save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)} {Image.open(path).size}")


def main() -> None:
    lay = json.loads((ART / "layout.json").read_text(encoding="utf-8"))
    paper = hex_rgb(lay["paper"])
    full = rgba(ART / "magpie_1x.png")
    front = rgba(ART / "front_1x.png")
    assert full.shape == front.shape
    cw, ch = lay["canvas_cells"]
    assert full.shape[:2] == (ch, cw)

    print("로딩 화면 그림")
    save(on_paper(full, paper), OUT / "full.png", "RGB")
    save(on_paper(front, paper), OUT / "front.png", "RGB")
    names = {}
    for lang in ("ko", "en"):
        img = np.array(Image.open(ART / f"name_{lang}_1x.png").convert("RGBA"))
        save(img, OUT / f"name_{lang}.png", "RGBA")
        names[lang] = [int(img.shape[1]), int(img.shape[0])]

    ix, iy, isz = lay["icon_window"]
    ax, ay, asz = lay["adaptive_window"]
    ref = lay["reference"]
    k = ref["cell_px"]
    sw, sh = ref["screen"]
    # 폰(1080×2400)의 마지막 자리를 화면 가운데에서 잰 칸 수로 둔다 (다른 화면은 칸 배율만 바꿔 같은 자리에)
    canvas_from_center = [(ref["canvas_px"][0] - sw / 2) / k, (ref["canvas_px"][1] - sh / 2) / k]
    name_top_from_center = (ref["name_top_px"] - sh / 2) / k
    mb = lay["magpie_bbox"]
    splash = {
        "note": "tools/splash_import.py가 art/splash/layout.json에서 만든다. 칸 좌표는 캔버스(full.png) 기준",
        "paper": lay["paper"],
        "ink": lay["ink"],
        "canvas_cells": [cw, ch],
        "icon_center": [ix + isz / 2, iy + isz / 2],
        "icon_cells": isz,
        "magpie_bbox": mb,
        "reference_screen": [sw, sh],
        "reference_cell_px": k,
        "canvas_from_center": canvas_from_center,
        "name_top_from_center": name_top_from_center,
        "name_cell_ratio": ref["name_cell_px"] / k,
        "names": names,
        "first_circle_dp": ref["first_circle_dp"],
    }
    (OUT / "splash.json").write_text(json.dumps(splash, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"  game/assets/splash/splash.json: 화면 가운데에서 캔버스 {canvas_from_center}칸, 이름 위 {name_top_from_center:.3f}칸")

    print("앱 아이콘")
    afront = front[ay:ay + asz, ax:ax + asz]
    save(area_resize(afront, asz, 432), ICON_OUT / "adaptive_fg.png", "RGBA")
    bg = np.zeros((432, 432, 4), np.uint8)
    bg[..., :3] = paper.astype(np.uint8)
    bg[..., 3] = 255
    save(bg, ICON_OUT / "adaptive_bg.png", "RGBA")
    luma = afront[..., 0] * 0.299 + afront[..., 1] * 0.587 + afront[..., 2] * 0.114
    mono = np.zeros(afront.shape, np.float64)
    mono[..., :3] = 255.0
    mono[..., 3] = np.where((afront[..., 3] > 0) & (luma < MONO_LUMA), 255.0, 0.0)
    save(area_resize(mono, asz, 432), ICON_OUT / "adaptive_mono.png", "RGBA")
    icon_b = front[iy:iy + isz, ix:ix + isz].copy()
    icon_b_paper = np.dstack([on_paper(icon_b, paper).astype(np.float64), np.full(icon_b.shape[:2], 255.0)])
    save(area_resize(icon_b_paper, isz, 192)[..., :3].copy(), ICON_OUT / "icon_192.png", "RGB")
    splash_icon = afront.repeat(3, axis=0).repeat(3, axis=1).astype(np.uint8)
    save(splash_icon, ICON_OUT / "splash_icon.png", "RGBA")
    proj = on_paper(icon_b, paper).repeat(2, axis=0).repeat(2, axis=1)
    save(proj, ROOT / "game" / "icon.png", "RGB")


if __name__ == "__main__":
    main()
