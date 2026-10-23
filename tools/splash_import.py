#!/usr/bin/env python3
"""로딩 화면과 앱 아이콘 파일 만들기: 디자인 세션 원본(1칸 = 1화소)에서 게임용 그림과 안드로이드 아이콘을 만든다.

입력 (art/splash/, 사용자 컴퓨터 `멀티 세션용 공유 폴더\\디자인 원본\\1023 로딩 화면·아이콘\\`에서 그대로 옮긴 것, 10-23):
  - magpie_full_paper_1x.png   까치 전체(267×317칸), 종이색(#EFE6D2) 바탕
  - magpie_front_paper_1x.png  뒤 날개를 뺀 앞 층 (같은 크기·자리, 아이콘과 로딩 첫 장면)
  - icon_b_paper_1x.png        아이콘 B 128×128칸 (앞 층의 창)
  - name_ko_1x.png, name_en_1x.png  이름 글자 (새바라기·NearWings, 글자 한 칸 = 1화소)
  - design_layout.json         원본의 `배치.json` 그대로 (격자, 아이콘 창, 적응형 창, 폰 마지막 화면 자리, 첫 장면)
  - design/final_ko.png, final_en.png, first.png, icon_b.png  디자인 캔버스 시안 화면 (확인용)
출력:
  game/assets/splash/
    - full.png, front.png   캔버스 그림 (종이색 바탕. 셰이더가 둘을 뒤 날개 알파만큼 섞는다).
                            원본 둘레에 종이색 PAD칸을 둔다(원본 아래 끝 줄에 그림자가 닿아서, 셰이더가 캔버스 밖을
                            가장자리 색으로 읽어도 종이색이 되게).
    - name_ko.png, name_en.png
    - splash.json           자리와 크기 (칸 좌표는 PAD를 둔 캔버스 기준)
  game/assets/icon/
    - adaptive_fg.png       적응형 아이콘 앞 레이어 432×432 (108dp = 192칸, 앞 층, 바탕 투명)
    - adaptive_bg.png       뒤 레이어 432×432 (#EFE6D2)
    - adaptive_mono.png     테마 아이콘(안드로이드 13+) 단색 레이어 432×432: 밝기 120 미만인 칸만 채운다(흰 깃은 비움)
    - icon_192.png          옛 안드로이드용 아이콘 192×192 (아이콘 B, 바탕 채움)
    - splash_icon.png       시스템 스플래시 그림 576×576 (적응형 앞 레이어와 같은 192칸, 칸당 3화소)
  game/icon.png             프로젝트 아이콘 256×256 (아이콘 B, 칸당 2화소)

적응형 앞 레이어는 원본의 투명판(adaptive_foreground_1x.png) 대신 종이색판에서 종이색 칸만 투명하게 해서 만든다.
투명판은 종이 위에 얹으면 어두운 칸 일부의 색이 종이색판과 다르고(아이콘 B 창 안 262칸, 예: #293144 → #312F2B),
뒤 레이어가 종이색이라 이렇게 하면 아이콘 B와 화소까지 같다.
아이콘을 칸당 정수가 아닌 화소로 줄일 때(432 = 칸당 2.25화소, 192 = 1.5화소)는 칸 넓이만큼 평균한다.
만들기 전에 원본끼리(아이콘 B = 앞 층의 창)와 디자인 시안 화면(폰 마지막 화면·아이콘 B)을 화소까지 견준다.

사용법: python3 tools/splash_import.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "splash"
DESIGN = ART / "design"
OUT = ROOT / "game" / "assets" / "splash"
ICON_OUT = ROOT / "game" / "assets" / "icon"
MONO_LUMA = 120     # 디자인의 테마 아이콘 시안과 칸마다 같은 기준 (밝기 = 0.299R + 0.587G + 0.114B)
PAD = 8             # 게임 캔버스 둘레의 종이색 칸


def rgb(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGB")).astype(np.uint8)


def hex_rgb(s: str) -> np.ndarray:
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


def cut_paper(a: np.ndarray, paper: np.ndarray) -> np.ndarray:
    """종이색 칸만 투명하게 한 RGBA (float)."""
    alpha = np.where((a == paper).all(-1), 0.0, 255.0)
    return np.dstack([a.astype(np.float64), alpha])


def pad(a: np.ndarray, n: int, fill) -> np.ndarray:
    out = np.empty((a.shape[0] + 2 * n, a.shape[1] + 2 * n, a.shape[2]), a.dtype)
    out[...] = fill
    out[n:n + a.shape[0], n:n + a.shape[1]] = a
    return out


def window(a: np.ndarray, x: int, y: int, size: int, margin: int) -> np.ndarray:
    """margin칸 둘레를 둔 그림에서 원본 칸 좌표 (x, y)부터 size칸 창."""
    return a[y + margin:y + margin + size, x + margin:x + margin + size]


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


def compose_final(full: np.ndarray, name: np.ndarray, paper: np.ndarray, screen, k: int, topleft, name_k: int, name_top: int) -> np.ndarray:
    """디자인 배치값대로 그린 폰 마지막 화면 (RGB)."""
    w, h = screen
    out = np.empty((h, w, 3), np.float64)
    out[...] = paper
    big = full.repeat(k, axis=0).repeat(k, axis=1)
    x0, y0 = int(topleft[0]), int(topleft[1])
    out[y0:y0 + big.shape[0], x0:x0 + big.shape[1]] = big
    nb = name.astype(np.float64).repeat(name_k, axis=0).repeat(name_k, axis=1)
    nx = (w - nb.shape[1]) // 2
    region = out[name_top:name_top + nb.shape[0], nx:nx + nb.shape[1]]
    al = nb[..., 3:4] / 255.0
    region[...] = nb[..., :3] * al + region * (1.0 - al)
    return np.round(out).astype(np.uint8)


def main() -> None:
    lay = json.loads((ART / "design_layout.json").read_text(encoding="utf-8"))
    paper = hex_rgb(lay["paper"])
    full = rgb(ART / "magpie_full_paper_1x.png")
    front = rgb(ART / "magpie_front_paper_1x.png")
    cw, ch = lay["grid"]["canvas_cells"]
    assert full.shape[:2] == (ch, cw) and front.shape == full.shape, "까치 원본 크기가 배치값과 다르다"
    names = {lang: np.array(Image.open(ART / f"name_{lang}_1x.png").convert("RGBA")) for lang in ("ko", "en")}
    for lang, img in names.items():
        assert [img.shape[1], img.shape[0]] == lay["names"][lang]["size_px_1x"], f"이름 {lang} 크기"

    iw = lay["icon_b"]["window_cells"]
    aw = lay["adaptive"]["window_cells"]
    fin = lay["final_screen_1080x2400"]
    first = lay["first_frame"]
    k = int(fin["cell_px"])
    assert k == fin["cell_px"], "마지막 화면 칸 배율은 정수"
    name_k = int(fin["name"]["glyph_scale"])
    name_top = int(fin["name"]["top_px"])
    screen = (1080, 2400)
    assert abs(first["cell_px"] - first["circle_diameter_dp"] / iw["size"] * first["dp_px"]) < 1e-9, "첫 장면: 192dp 원 = 아이콘 B 창"

    print("원본 확인")
    margin = max(0, -min(iw["x"], iw["y"], aw["x"], aw["y"]))
    front_a = pad(cut_paper(front, paper), margin, np.array([*paper, 0.0]))   # 투명한 칸도 RGB는 종이색 (늘릴 때 번지지 않게)
    front_p = pad(front, margin, paper)
    icon_b = rgb(ART / "icon_b_paper_1x.png")
    assert (window(front_p, iw["x"], iw["y"], iw["size"], margin) == icon_b).all(), "아이콘 B가 앞 층의 창과 다르다"
    print("  아이콘 B = 앞 층의 창 (128칸)")
    ok = True
    if (DESIGN / "icon_b.png").exists():
        same = (icon_b.repeat(8, axis=0).repeat(8, axis=1) == rgb(DESIGN / "icon_b.png")).all()
        print(f"  아이콘 B 1024 (칸당 8화소): 디자인 시안과 {'같다' if same else '다르다'}")
        ok &= bool(same)
    for lang in ("ko", "en"):
        ref = DESIGN / f"final_{lang}.png"
        if ref.exists():
            shot = compose_final(full, names[lang], paper, screen, k, fin["bird_topleft_px"], name_k, name_top)
            diff = int((shot != rgb(ref)).any(-1).sum())
            print(f"  폰 마지막 화면({lang}): 디자인 시안과 다른 화소 {diff}")
            ok &= diff == 0
    if not ok:
        sys.exit("원본과 디자인 시안 화면이 다르다")

    print("로딩 화면 그림")
    save(pad(full, PAD, paper), OUT / "full.png", "RGB")
    save(pad(front, PAD, paper), OUT / "front.png", "RGB")
    for lang, img in names.items():
        save(img, OUT / f"name_{lang}.png", "RGBA")
    nonpaper = ~(full == paper).all(-1)
    ys, xs = np.nonzero(nonpaper)
    bbox = [int(xs.min()) + PAD, int(ys.min()) + PAD, int(xs.max()) + 1 + PAD, int(ys.max()) + 1 + PAD]
    tl = fin["bird_topleft_px"]
    # 폰(1080×2400)의 마지막 자리를 화면 가운데에서 잰 칸 수로 둔다 (다른 화면은 칸 배율만 바꿔 같은 자리에)
    canvas_from_center = [(tl[0] - screen[0] / 2) / k - PAD, (tl[1] - screen[1] / 2) / k - PAD]
    name_top_from_center = (name_top - screen[1] / 2) / k
    splash = {
        "note": "tools/splash_import.py가 art/splash/의 디자인 원본과 배치값(design_layout.json)에서 만든다. "
                "칸 좌표는 캔버스(full.png = 원본 둘레에 종이색 pad칸) 기준",
        "paper": lay["paper"],
        "ink": lay["name_color"],
        "pad": PAD,
        "canvas_cells": [cw + 2 * PAD, ch + 2 * PAD],
        "icon_center": [iw["x"] + iw["size"] / 2 + PAD, iw["y"] + iw["size"] / 2 + PAD],
        "icon_cells": iw["size"],
        "magpie_bbox": bbox,
        "reference_screen": list(screen),
        "reference_cell_px": k,
        "canvas_from_center": canvas_from_center,
        "name_top_from_center": name_top_from_center,
        "name_cell_ratio": name_k / k,
        "names": {lang: [int(img.shape[1]), int(img.shape[0])] for lang, img in names.items()},
        "first_circle_dp": first["circle_diameter_dp"],
    }
    (OUT / "splash.json").write_text(json.dumps(splash, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"  game/assets/splash/splash.json: 화면 가운데에서 캔버스 {canvas_from_center}칸, 이름 위 {name_top_from_center:.3f}칸, 까치 {bbox}")

    print("앱 아이콘")
    afront = window(front_a, aw["x"], aw["y"], aw["size"], margin)
    save(area_resize(afront, aw["size"], 432), ICON_OUT / "adaptive_fg.png", "RGBA")
    bg = np.zeros((432, 432, 4), np.uint8)
    bg[..., :3] = paper
    bg[..., 3] = 255
    save(bg, ICON_OUT / "adaptive_bg.png", "RGBA")
    luma = afront[..., 0] * 0.299 + afront[..., 1] * 0.587 + afront[..., 2] * 0.114
    mono = np.zeros(afront.shape, np.float64)
    mono[..., :3] = 255.0
    mono[..., 3] = np.where((afront[..., 3] > 0) & (luma < MONO_LUMA), 255.0, 0.0)
    save(area_resize(mono, aw["size"], 432), ICON_OUT / "adaptive_mono.png", "RGBA")
    icon_b_a = np.dstack([icon_b.astype(np.float64), np.full(icon_b.shape[:2], 255.0)])
    save(area_resize(icon_b_a, iw["size"], 192)[..., :3].copy(), ICON_OUT / "icon_192.png", "RGB")
    splash_icon = afront.repeat(3, axis=0).repeat(3, axis=1).astype(np.uint8)
    save(splash_icon, ICON_OUT / "splash_icon.png", "RGBA")
    save(icon_b.repeat(2, axis=0).repeat(2, axis=1), ROOT / "game" / "icon.png", "RGB")


if __name__ == "__main__":
    main()
