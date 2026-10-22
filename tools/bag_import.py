#!/usr/bin/env python3
"""가방 메뉴 그림 만들기 (임시): 디자인 캔버스 '가방 메뉴' 시안과 도감 그림 키트에서 게임용 그림을 뽑는다.

임시 도구다. 디자인 세션이 가방·도구·이름표를 1칸 = 1화소로 따로 넘겨주면 이 도구 대신 그 파일을 그대로 쓴다.

입력 (art/bag/):
  - canvas_bag_screen.png 캔버스 '도감 그림 칸'의 '넣어 본 모습': 1080×2400 가방 속 화면(키트 예시 도감과
                          10-22에 다시 그린 지붕형 프리즘 쌍안경·세로 그립 미러리스). 가방은 5화소 칸, 도구는 4화소 칸
  - canvas_main.png       캔버스 '가방 메뉴 · 여는 움직임'의 1번 그림(기본 화면): 가방 윗단 위 화살표 둘
  - kit_dogam.png         키트로 만든 도감 그림(1칸 = 1화소, 둘레에 빈 칸 하나). 이 파일만 바꾸면 도감 그림이 바뀐다
  - kit_tag_dogam.png     키트의 '도감' 이름표 (4화소 칸)
출력 (game/assets/bag/):
  - bag.png               가방 (206×248칸). 안감 위 도구·이름표·그림자는 지우고 안감 무늬를 다시 그렸다
  - dogam.png, binoculars.png, camera.png, arrows.png  (도구 칸 = 1화소, 배경 투명)
  - tag_*.png              이름표 (시안 화소 그대로: 글자가 4화소 칸에 딱 맞지 않는다)
  - bag.json              시안(1080×2400)에서 잰 자리와 늘이고 줄일 수 있는 줄·칸

시안 좌표: 가방 한 칸 = 5화소(배경 칸), 도구 한 칸 = 4화소(새 칸). 가방 윗단은 화면 위에서 1160화소.

사용법: python3 tools/bag_import.py
"""
import json
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "bag"
OUT = ROOT / "game" / "assets" / "bag"

BAG_CELL = 5
TOOL_CELL = 4
BAG_X0, BAG_Y0, BAG_W, BAG_H = 5, 232, 206, 248     # 가방 자리 (시안의 배경 칸)
LINING_BASE = (0xE7, 0xDE, 0xC7)
LINING_DOT = (0xDC, 0xD2, 0xB8)
TOOL_SHADOW = (0xD3, 0xC9, 0xAE)
ARROW_COLORS = {(0x6F, 0x62, 0x50), (0x90, 0x8B, 0x72)}

# 도구와 이름표 (시안 화소). 도감은 키트 예시 대신 kit_dogam.png를 키트 규칙대로 놓는다.
# crop: 오려 낼 범위, grid: 4화소 칸이 시작하는 화소(x, y) 나머지
PIECES = {
    "binoculars": {"crop": (600, 1296, 912, 1644), "cell": TOOL_CELL},
    "camera": {"crop": (540, 1752, 932, 2096), "cell": TOOL_CELL},
    # 이름표 글자는 4화소 칸에 딱 맞지 않아 시안 화소 그대로 오린다
    "tag_binoculars": {"crop": (652, 1644, 852, 1736), "cell": 1},
    "tag_camera": {"crop": (632, 2092, 836, 2184), "cell": 1},
}
DOGAM_CENTER = (290, 1680)     # 도감 그림이 있는 부분의 가운데 (키트 규칙)
TAG_GAP = 8                    # 이름표는 그림 아래 8화소


def components(mask: np.ndarray):
    """8방향으로 이어진 덩어리: (번호 그림, {번호: 칸 수})."""
    h, w = mask.shape
    lab = np.zeros((h, w), int)
    sizes = {}
    n = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not lab[y, x]:
                n += 1
                lab[y, x] = n
                q = deque([(y, x)])
                s = 0
                while q:
                    cy, cx = q.popleft()
                    s += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = n
                                q.append((ny, nx))
                sizes[n] = s
    return lab, sizes


def cut_piece(screen: np.ndarray, crop, cell):
    """cell화소 칸으로 오려 안감·그림자 색을 투명하게 한다. (RGBA 그림, 왼쪽 위 화소)"""
    x0, y0, x1, y1 = crop
    x0 -= x0 % cell
    y0 -= y0 % cell
    w, h = (x1 - x0) // cell, (y1 - y0) // cell
    c = cell // 2
    cells = screen[y0 + c:y0 + cell * h:cell, x0 + c:x0 + cell * w:cell]
    bg = {LINING_BASE, LINING_DOT, TOOL_SHADOW}
    keep = np.array([[tuple(c) not in bg for c in row] for row in cells])
    lab, sizes = components(keep)
    keep = np.isin(lab, [k for k, s in sizes.items() if s >= 30])
    ys, xs = np.where(keep)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.zeros(cells.shape[:2] + (4,), np.uint8)
    rgba[..., :3] = cells
    rgba[..., 3] = keep * 255
    return rgba[t:b, l:r], (x0 + cell * int(l), y0 + cell * int(t))


def clean_bag(screen: np.ndarray):
    """가방 칸(206×248)을 뽑고, 안감 위에 놓인 것(도구·이름표·그림자)을 지워 안감 무늬로 다시 채운다."""
    cells = screen[2::BAG_CELL, 2::BAG_CELL]
    bag = cells[BAG_Y0:BAG_Y0 + BAG_H, BAG_X0:BAG_X0 + BAG_W].copy()
    lining = (bag == LINING_BASE).all(-1) | (bag == LINING_DOT).all(-1)
    rows = [y for y in range(BAG_H) if lining[y].any()]
    top, bottom = rows[0], rows[-1]
    left = [int(np.where(lining[y])[0].min()) for y in range(top, bottom + 1)]
    right = [int(np.where(lining[y])[0].max()) for y in range(top, bottom + 1)]
    for i, y in enumerate(range(top, bottom + 1)):
        for x in range(left[i], right[i] + 1):
            sx = x + BAG_X0
            dot = ((y - 29) % 12 == 0 and sx % 8 in (1, 2)) or ((y - 29) % 12 == 6 and sx % 8 in (5, 6))
            bag[y, x] = LINING_DOT if dot else LINING_BASE
    return bag, top, bottom, left, right


def periodic_runs(a: np.ndarray, period: int, axis: int):
    """axis 방향으로 i번째 줄과 i+period번째 줄이 같은 i들의 구간 [(처음, 끝)]."""
    n = a.shape[axis]
    same = []
    for i in range(n - period):
        u = a[:, i] if axis == 1 else a[i]
        v = a[:, i + period] if axis == 1 else a[i + period]
        same.append(bool((u == v).all()))
    runs = []
    start = None
    for i, s in enumerate(same + [False]):
        if s and start is None:
            start = i
        elif not s and start is not None:
            runs.append([start, i - 1])
            start = None
    return runs


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    screen = np.array(Image.open(ART / "canvas_bag_screen.png").convert("RGB"))
    assert screen.shape[:2] == (2400, 1080), "1080×2400 시안이어야 한다"

    bag, top, bottom, left, right = clean_bag(screen)
    Image.fromarray(bag, "RGB").save(OUT / "bag.png")
    col_runs = [r for r in periodic_runs(bag, 8, 1) if r[1] - r[0] >= 16]
    row_runs = [r for r in periodic_runs(bag, 12, 0) if r[1] - r[0] >= 24]

    pieces = {}
    for name, spec in PIECES.items():
        img, tl = cut_piece(screen, spec["crop"], spec["cell"])
        Image.fromarray(img, "RGBA").save(OUT / f"{name}.png")
        pieces[name] = {"file": f"{name}.png", "size": [int(img.shape[1]), int(img.shape[0])], "tl_px": [int(tl[0]), int(tl[1])],
                        "px_per_cell": spec["cell"]}

    # 도감: 키트 그림을 그대로 쓰고, 그림이 있는 부분의 가운데를 DOGAM_CENTER에 4화소 칸으로 맞춘다
    dogam = np.array(Image.open(ART / "kit_dogam.png").convert("RGBA"))
    Image.fromarray(dogam, "RGBA").save(OUT / "dogam.png")
    ys, xs = np.where(dogam[..., 3] > 0)
    vis = (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))
    vis_tl = [math.floor((DOGAM_CENTER[i] - vis[i] * TOOL_CELL / 2) / TOOL_CELL + 0.5) * TOOL_CELL for i in (0, 1)]
    dogam_tl = [vis_tl[0] - int(xs.min()) * TOOL_CELL, vis_tl[1] - int(ys.min()) * TOOL_CELL]
    pieces["dogam"] = {"file": "dogam.png", "size": [int(dogam.shape[1]), int(dogam.shape[0])], "tl_px": dogam_tl,
                       "px_per_cell": TOOL_CELL}
    # 이름표는 그림(빈 둘레 포함) 아래 8화소, 가운데 맞춤 (키트의 preview와 같다)
    tag = np.array(Image.open(ART / "kit_tag_dogam.png").convert("RGBA"))
    Image.fromarray(tag, "RGBA").save(OUT / "tag_dogam.png")
    art_bottom = dogam_tl[1] + dogam.shape[0] * TOOL_CELL
    pieces["tag_dogam"] = {"file": "tag_dogam.png", "size": [int(tag.shape[1]), int(tag.shape[0])],
                           "tl_px": [DOGAM_CENTER[0] - tag.shape[1] // 2, art_bottom + TAG_GAP], "px_per_cell": 1}

    # 화살표 둘: 기본 화면에서 화살표 색 칸만 4화소 칸으로 오린다
    main_screen = np.array(Image.open(ART / "canvas_main.png").convert("RGB"))
    hit = np.zeros(main_screen.shape[:2], bool)
    for c in ARROW_COLORS:
        hit |= (main_screen == c).all(-1)
    hit[:2200] = False
    ys, xs = np.where(hit)
    x0, y0 = int(xs.min()), int(ys.min())
    w = (int(xs.max()) - x0) // TOOL_CELL + 1
    h = (int(ys.max()) - y0) // TOOL_CELL + 1
    cells = main_screen[y0 + 2:y0 + TOOL_CELL * h:TOOL_CELL, x0 + 2:x0 + TOOL_CELL * w:TOOL_CELL]
    arrows = np.zeros((h, w, 4), np.uint8)
    arrows[..., :3] = cells
    arrows[..., 3] = np.array([[tuple(c) in ARROW_COLORS for c in row] for row in cells]) * 255
    Image.fromarray(arrows, "RGBA").save(OUT / "arrows.png")
    pieces["arrows"] = {"file": "arrows.png", "size": [w, h], "tl_px": [x0, y0], "px_per_cell": TOOL_CELL}

    data = {
        "note": "임시: 디자인 캔버스 '가방 메뉴'의 가방 속 화면(10-22 쌍안경·카메라)과 도감 그림 키트에서 tools/bag_import.py가 뽑았다. 좌표는 1080×2400 시안 화소.",
        "design_px": [1080, 2400],
        "bag_cell_px": BAG_CELL,
        "tool_cell_px": TOOL_CELL,
        "bag": {"file": "bag.png", "size": [BAG_W, BAG_H], "tl_px": [BAG_X0 * BAG_CELL, BAG_Y0 * BAG_CELL]},
        "lining": {"top": top, "bottom": bottom, "left": left, "right": right},
        "stretch": {"col_period": 8, "col_runs": col_runs, "row_period": 12, "row_runs": row_runs},
        "hint_rows": 16,
        "tools": [
            {"id": "dogam", "art": "dogam", "tag": "tag_dogam"},
            {"id": "binoculars", "art": "binoculars", "tag": "tag_binoculars"},
            {"id": "camera", "art": "camera", "tag": "tag_camera"},
        ],
        "pieces": pieces,
        "tool_shadow": {"color": "#d3c9ae", "offset_cells": [2, 3]},
        "bag_shadow": {"cells": 6, "strength": 0.11},
    }
    (OUT / "bag.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"가방 {BAG_W}×{BAG_H}칸, 안감 {top}~{bottom}행, 늘일 칸 {col_runs}, 늘일 줄 {row_runs}")
    for k, v in pieces.items():
        print(f"  {k}: {v['size'][0]}×{v['size'][1]} (한 칸 {v['px_per_cell']}화소), 왼쪽 위 {v['tl_px']}화소")


if __name__ == "__main__":
    main()
