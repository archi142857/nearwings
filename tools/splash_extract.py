#!/usr/bin/env python3
"""로딩 화면·앱 아이콘 원본 뽑기: 디자인 캔버스 '앱 아이콘 · 로딩 화면' 시안 화면에서 1칸 = 1화소 그림을 뽑는다.

디자인 세션이 1칸 = 1화소 원본을 넘기기 전까지 쓰는 방법이다. 원본이 오면 art/splash/의 *_1x.png와 layout.json을
그것으로 바꾸고 tools/splash_import.py만 돌린다.

입력 (art/splash/design/, 디자인 캔버스에서 받은 시안 화면, 폰 1080×2400, 2026-10-23):
  - final.png                   마지막 화면 (까치, 칸당 3화소, 이름 없음)
  - final_ko.png, final_en.png  마지막 화면 + 이름 (새바라기 / NearWings, 글자 칸 8화소)
  - mid.png                     중간 화면 (칸당 약 3.41화소, 뒤 날개가 82%쯤 들어온 때)
  - icon_b.png                  앱 아이콘 B (1024×1024, 칸당 8화소, 뒤 날개를 뺀 그림)
  - first.png                   첫 화면 (시스템 스플래시, 2.625배 기기). 검사 기준으로만 쓴다
출력 (art/splash/):
  - magpie_1x.png   까치 전체 (뒤 날개 포함, 마지막 화면 그대로). 바탕(#EFE6D2)은 투명
  - front_1x.png    앞 층만 그린 까치 (뒤 날개를 뺀 그림). 아이콘 B와 같은 방식이라 뒤 날개와 맞닿던 가장자리에 밝은 테가 있다
  - name_ko_1x.png, name_en_1x.png  이름 글자 (글자 칸 = 1화소)
  - layout.json     칸 격자 안 자리 (아이콘 창, 적응형 아이콘 창, 폰에서의 마지막 자리)

앞 층은 중간 화면에서 되살린다. 중간 화면 = 앞 층 × (1 − a) + 전체 × a 이고 a(뒤 날개 알파)는 칸마다 같다.
되살린 앞 층이 아이콘 B 창(128×128칸) 안에서 아이콘 B와 칸마다 같은지 확인한다.

사용법: python3 tools/splash_extract.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "splash" / "design"
OUT = ROOT / "art" / "splash"

PAPER = np.array([239, 230, 210])
REF_SCREEN = (1080, 2400)
REF_CELL = 3                  # 마지막 화면 칸당 화소
ICON_CELL = 8                 # 아이콘 B 칸당 화소
NAME_CELL = 8                 # 이름 글자 칸당 화소
ICON = 128                    # 아이콘 B 창 (칸)
ADAPTIVE = 192                # 적응형 아이콘 108dp 레이어 (72dp 보이는 곳 = 아이콘 창 128칸)
CANVAS_MARGIN = 8             # 까치·아이콘 창 둘레에 남길 바탕 (칸)


def load(name: str) -> np.ndarray:
    return np.array(Image.open(SRC / name).convert("RGB")).astype(np.int32)


def grid(img: np.ndarray, n: int):
    """n화소 칸 격자의 위상(왼쪽, 위)과 칸 그림. 모든 칸이 한 색이어야 한다."""
    for oy in range(n):
        for ox in range(n):
            h = (img.shape[0] - oy) // n
            w = (img.shape[1] - ox) // n
            b = img[oy:oy + h * n, ox:ox + w * n].reshape(h, n, w, n, 3)
            if (b == b[:, :1, :, :1]).all():
                return (ox, oy), b[:, 0, :, 0].copy()
    raise SystemExit(f"{n}화소 칸 격자를 찾지 못했다")


def is_paper(a: np.ndarray) -> np.ndarray:
    return (a == PAPER).all(axis=-1)


def find_window(cells: np.ndarray, win: np.ndarray, seed: int = 1) -> tuple:
    """win(바탕이 아닌 칸)이 cells 어디에 통째로 들어 있는지: (x, y). 칸 400개로 찾는다(찾은 뒤 전부 견주는 것은 부르는 쪽)."""
    pts = np.argwhere(~is_paper(win))
    rng = np.random.default_rng(seed)
    sel = pts[rng.choice(len(pts), min(400, len(pts)), replace=False)]
    vals = win[sel[:, 0], sel[:, 1]]
    best = None
    H, W = cells.shape[:2]
    for oy in range(0, H - win.shape[0] + 1):
        ys = sel[:, 0] + oy
        for ox in range(0, W - win.shape[1] + 1):
            sc = (cells[ys, sel[:, 1] + ox] == vals).all(axis=1).sum()
            if best is None or sc > best[0]:
                best = (int(sc), ox, oy)
    return best[1], best[2]


def boundaries(d: np.ndarray) -> np.ndarray:
    """줄마다 바뀐 화소 수(d)에서 칸 경계 자리를 고른다 (이웃보다 두 배 넘게 바뀐 곳)."""
    out = []
    for i in range(1, len(d) - 1):
        med = max(float(np.median(d[max(0, i - 6):i + 7])), 1.0)
        if d[i] >= 2 * med and d[i] >= d[i - 1] and d[i] >= d[i + 1] and d[i] > 100:
            out.append(i + 1)
    return np.array(out, float)


def fit_grid(img: np.ndarray):
    """가장 가까운 화소로 늘린 그림에서 칸 크기(화소)와 x·y 위상(화소)을 찾는다."""
    dx = (img[:, 1:] != img[:, :-1]).any(axis=2).sum(axis=0)
    dy = (img[1:, :] != img[:-1, :]).any(axis=2).sum(axis=1)
    bx, by = boundaries(dx), boundaries(dy)

    def score(b, s):
        t = np.arange(0.0, s, 0.01)
        r = (b[:, None] - t[None, :]) / s
        e = np.abs(r - np.round(r)) * s
        sc = (e < 0.6).sum(axis=0)
        i = int(sc.argmax())
        return int(sc[i]), float(t[i])

    best = None
    for s in np.arange(2.5, 4.5, 0.0005):
        sx, sy = score(bx, s), score(by, s)
        if best is None or sx[0] + sy[0] > best[0]:
            best = (sx[0] + sy[0], float(s), sx[1], sy[1])
    return best[1], best[2], best[3]


def main() -> None:
    final = load("final.png")
    assert final.shape[:2] == (REF_SCREEN[1], REF_SCREEN[0])
    (fx, fy), cells = grid(final, REF_CELL)
    print(f"마지막 화면: 칸 격자 위상 ({fx}, {fy}), {cells.shape[1]}×{cells.shape[0]}칸")
    palette = np.unique(cells.reshape(-1, 3), axis=0)
    print(f"  색 {len(palette)}개 (바탕 포함)")

    (ix, iy), icon = grid(load("icon_b.png"), ICON_CELL)
    assert icon.shape[:2] == (ICON, ICON) and (ix, iy) == (0, 0)
    wx, wy = find_window(cells, icon)
    win = cells[wy:wy + ICON, wx:wx + ICON]
    same = (win == icon).all(axis=2)
    fg = ~is_paper(icon)
    print(f"아이콘 B 창: 마지막 화면 칸 ({wx}, {wy}). 아이콘의 그림 칸 {fg.sum()}개 중 {int((same & fg).sum())}개가 같다")
    assert (same & fg).sum() >= fg.sum() - 40, "아이콘 B가 마지막 화면 까치와 맞지 않는다"

    # 중간 화면: 칸 크기와 위상을 찾아 칸 가운데를 읽고, 아이콘 창으로 자리를 맞춘다
    mid = load("mid.png")
    s, tx, ty = fit_grid(mid)
    nx, ny = int((mid.shape[1] - tx) / s), int((mid.shape[0] - ty) / s)
    xs = (tx + (np.arange(nx) + 0.5) * s).astype(int)
    ys = (ty + (np.arange(ny) + 0.5) * s).astype(int)
    mcells = mid[ys][:, xs]
    mx, my = find_window(mcells, icon)
    ox, oy = wx - mx, wy - my          # 중간 화면 칸 + (ox, oy) = 마지막 화면 칸
    print(f"중간 화면: 칸당 {s:.4f}화소, 위상 ({tx:.2f}, {ty:.2f}), 마지막 화면 칸 = 중간 칸 + ({ox}, {oy})")
    m_on_f = np.zeros_like(cells)
    m_on_f[:] = PAPER
    for y in range(cells.shape[0]):
        my_ = y - oy
        if not 0 <= my_ < mcells.shape[0]:
            continue
        x0 = max(0, ox)
        x1 = min(cells.shape[1], ox + mcells.shape[1])
        m_on_f[y, x0:x1] = mcells[my_, x0 - ox:x1 - ox]

    bird = ~is_paper(cells)
    differ = bird & ~(cells == m_on_f).all(axis=2)
    d = (cells - PAPER).astype(float)
    num = ((m_on_f - PAPER) * d).sum(axis=2)
    den = (d * d).sum(axis=2)
    use = differ & (den > 2000)
    alphas = num[use] / den[use]
    a = float(np.median(alphas))
    print(f"  뒤 날개 알파 {a:.4f} (칸 {use.sum()}개, 5~95% {np.percentile(alphas, 5):.4f}~{np.percentile(alphas, 95):.4f})")

    est = (m_on_f - a * cells) / (1.0 - a)
    pal = np.vstack([palette, PAPER[None]])
    dist = ((est[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(axis=3)
    snapped = pal[dist.argmin(axis=2)]
    err = np.sqrt(dist.min(axis=2))
    front = cells.copy()
    front[differ] = snapped[differ]
    print(f"  앞 층 되살리기: 칸 {differ.sum()}개, 색 맞춤 오차 최대 {err[differ].max():.1f}")
    fw = front[wy:wy + ICON, wx:wx + ICON]
    ok = (fw == icon).all(axis=2)
    print(f"  아이콘 창 안 앞 층 = 아이콘 B: {int(ok.sum())}/{ICON * ICON}칸")
    assert ok.all(), "되살린 앞 층이 아이콘 B와 다르다"
    back_cells = bird & is_paper(front)
    print(f"  뒤 날개(와 그림자) 칸 {int(back_cells.sum())}개, 앞 층 테 칸 {int((differ & ~is_paper(front)).sum())}개")

    # 이름: 마지막 화면과 다른 화소를 8화소 칸으로 읽는다
    names = {}
    for lang, fname in (("ko", "final_ko.png"), ("en", "final_en.png")):
        img = load(fname)
        diff = (img != final).any(axis=2)
        yy, xx = np.nonzero(diff)
        x0, y0 = int(xx.min()), int(yy.min())
        w = (int(xx.max()) - x0) // NAME_CELL + 1
        h = (int(yy.max()) - y0) // NAME_CELL + 1
        block = img[y0:y0 + h * NAME_CELL, x0:x0 + w * NAME_CELL].reshape(h, NAME_CELL, w, NAME_CELL, 3)
        assert (block == block[:, :1, :, :1]).all(), f"{lang} 이름이 8화소 칸에 맞지 않는다"
        dblock = diff[y0:y0 + h * NAME_CELL, x0:x0 + w * NAME_CELL].reshape(h, NAME_CELL, w, NAME_CELL)
        mask = dblock[:, 0, :, 0]
        ink = np.unique(img[diff].reshape(-1, 3), axis=0)
        assert len(ink) == 1
        names[lang] = (mask, x0, y0, tuple(int(v) for v in ink[0]))
        print(f"이름 {lang}: 화면 ({x0}, {y0})에서 {w}×{h}칸, 가운데 x {x0 + w * NAME_CELL / 2:.1f}, 색 {names[lang][3]}")

    # 캔버스: 까치·아이콘 창·적응형 아이콘 창을 다 담고 둘레에 바탕을 남긴다
    yy, xx = np.nonzero(bird)
    cx = wx + ICON // 2
    cy = wy + ICON // 2
    ax, ay = cx - ADAPTIVE // 2, cy - ADAPTIVE // 2
    left = min(int(xx.min()), ax) - CANVAS_MARGIN
    top = min(int(yy.min()), ay) - CANVAS_MARGIN
    right = max(int(xx.max()) + 1, ax + ADAPTIVE) + CANVAS_MARGIN
    bottom = max(int(yy.max()) + 1, ay + ADAPTIVE) + CANVAS_MARGIN
    cw, ch = right - left, bottom - top

    def rgba(a_cells: np.ndarray) -> Image.Image:
        crop = a_cells[top:bottom, left:right]
        alpha = np.where(is_paper(crop), 0, 255)
        return Image.fromarray(np.dstack([crop, alpha]).astype(np.uint8), "RGBA")

    OUT.mkdir(parents=True, exist_ok=True)
    rgba(cells).save(OUT / "magpie_1x.png")
    rgba(front).save(OUT / "front_1x.png")
    for lang, (mask, x0, y0, ink) in names.items():
        im = np.zeros(mask.shape + (4,), np.uint8)
        im[mask] = ink + (255,)
        Image.fromarray(im, "RGBA").save(OUT / f"name_{lang}_1x.png")

    ref_canvas_px = [fx + REF_CELL * left, fy + REF_CELL * top]
    layout = {
        "note": "칸 좌표는 캔버스(magpie_1x.png) 기준. reference는 디자인 마지막 화면(폰 1080×2400)의 자리다. "
                "tools/splash_extract.py가 디자인 시안 화면에서 뽑았다.",
        "paper": "#%02x%02x%02x" % tuple(PAPER),
        "ink": "#%02x%02x%02x" % names["ko"][3],
        "canvas_cells": [cw, ch],
        "icon_window": [wx - left, wy - top, ICON],
        "adaptive_window": [ax - left, ay - top, ADAPTIVE],
        "magpie_bbox": [int(xx.min()) - left, int(yy.min()) - top, int(xx.max()) + 1 - left, int(yy.max()) + 1 - top],
        "reference": {
            "screen": list(REF_SCREEN),
            "cell_px": REF_CELL,
            "canvas_px": ref_canvas_px,
            "name_top_px": names["ko"][2],
            "name_cell_px": NAME_CELL,
            "first_circle_dp": 192,
        },
        "names": {lang: {"cells": [int(m.shape[1]), int(m.shape[0])], "left_px": x0, "top_px": y0}
                  for lang, (m, x0, y0, ink) in names.items()},
        "mid": {"cell_px": round(s, 4), "back_alpha": round(a, 4),
                "canvas_px": [round(tx + (left - ox) * s, 2), round(ty + (top - oy) * s, 2)]},
    }
    (OUT / "layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"캔버스 {cw}×{ch}칸 (마지막 화면 칸 {left}, {top}부터). 폰에서 캔버스 왼쪽 위 = {ref_canvas_px}화소")
    print(json.dumps(layout, ensure_ascii=False))


if __name__ == "__main__":
    main()
