#!/usr/bin/env python3
"""가방 메뉴 그림 만들기: 디자인 세션이 넘긴 원본(1칸 = 1화소)과 배치값에서 게임용 그림과 bag.json을 만든다.

원본은 사용자 컴퓨터 `멀티 세션용 공유 폴더\\디자인 원본\\1022 가방 메뉴\\`(디자인 세션, 2026-10-22)를 옮겨 둔 것이다.

입력 (art/bag/):
  - bag_1x.png            도구를 뺀 가방 (배경 칸, 216×248칸. 양옆 5칸은 비어 있다)
  - bino_1x.png, camera_1x.png  쌍안경·카메라 (새 칸, 기울기는 그림에 들어 있다)
  - tag_*_1x.png, chevron_1x.png  이름표와 기본 화면 화살표 (새 칸)
  - design_layout.json    디자인 세션의 배치값(`배치.json`): 폰 화면 자리, 그림자, 움직임
  - kit_dogam.png         키트로 만든 도감 그림(1칸 = 1화소). 게임의 도감은 이 그림을 쓴다. 이 파일만 바꾸면 도감 그림이 바뀐다
  - bag_f4.png            원본과 배치값으로 그린 가방 속 화면 (tools/screenshots.py가 견주는 기준)
출력 (game/assets/bag/):
  - bag.png               가방 (206×248칸)
  - dogam.png, binoculars.png, camera.png, arrows.png, tag_*.png  (새 칸 = 1화소, 배경 투명)
  - bag.json              폰(1080×2400) 화면 자리, 늘이고 줄일 수 있는 줄·칸, 그림자

시안 좌표: 가방 한 칸 = 5화소(배경 칸), 도구 한 칸 = 4화소(새 칸). 가방 윗단은 다 열었을 때 화면 위에서 1160화소.

사용법: python3 tools/bag_import.py
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "bag"
OUT = ROOT / "game" / "assets" / "bag"

BAG_CELL = 5
TOOL_CELL = 4
LINING_BASE = (0xE7, 0xDE, 0xC7)
LINING_DOT = (0xDC, 0xD2, 0xB8)
DOGAM_CENTER = (290, 1680)     # 도감 그림이 있는 부분의 가운데 (결정 기록 '도감 그림 칸')
TAG_GAP = 8                    # 이름표는 그림 아래 8화소
HINT_PX = 80                   # 기본 화면에 보이는 가방 윗단
ARROW_GAP = 6                  # 화살표 아랫변은 닫힌 가방 윗단에서 6칸(새 칸) 위


def opaque(path: Path):
    """그림과 불투명한 부분의 범위 (왼쪽, 위, 오른쪽 끝, 아래 끝)."""
    img = np.array(Image.open(path).convert("RGBA"))
    ys, xs = np.where(img[..., 3] > 0)
    return img, (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


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


def piece(name: str, src: str, tl_px, out_name: str):
    """원본을 그림이 있는 부분만 남겨 저장하고 자리(화면 화소)를 맞춘다."""
    img, (l, t, r, b) = opaque(ART / src)
    Image.fromarray(img[t:b, l:r], "RGBA").save(OUT / out_name)
    return {"file": out_name, "size": [r - l, b - t], "tl_px": [tl_px[0] + l * TOOL_CELL, tl_px[1] + t * TOOL_CELL],
            "px_per_cell": TOOL_CELL}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lay = json.loads((ART / "design_layout.json").read_text(encoding="utf-8"))
    assert lay["screen_px"] == [1080, 2400], "1080×2400 폰 기준 배치여야 한다"

    # 가방: 양옆 빈 칸을 떼고, 안감(크림색 바탕과 점무늬) 범위를 잰다
    full, (bl, bt, br, bb) = opaque(ART / "bag_1x.png")
    bag = full[bt:bb, bl:br, :3].copy()
    bag_w, bag_h = br - bl, bb - bt
    Image.fromarray(bag, "RGB").save(OUT / "bag.png")
    bag_top = int(lay["bag"]["top_when_open_px"])
    bag_tl = [bl * BAG_CELL, bag_top]
    lining = (bag == LINING_BASE).all(-1) | (bag == LINING_DOT).all(-1)
    rows = [y for y in range(bag_h) if lining[y].any()]
    top, bottom = rows[0], rows[-1]
    left = [int(np.where(lining[y])[0].min()) for y in range(top, bottom + 1)]
    right = [int(np.where(lining[y])[0].max()) for y in range(top, bottom + 1)]
    col_runs = [r for r in periodic_runs(bag, 8, 1) if r[1] - r[0] >= 16]
    row_runs = [r for r in periodic_runs(bag, 12, 0) if r[1] - r[0] >= 24]

    tools = lay["tools"]
    pieces = {
        "binoculars": piece("binoculars", "bino_1x.png", tools["bino"]["topleft_screen_px"], "binoculars.png"),
        "camera": piece("camera", "camera_1x.png", tools["camera"]["topleft_screen_px"], "camera.png"),
        "tag_binoculars": piece("tag_binoculars", "tag_bino_1x.png", tools["bino"]["tag"]["topleft_screen_px"], "tag_binoculars.png"),
        "tag_camera": piece("tag_camera", "tag_camera_1x.png", tools["camera"]["tag"]["topleft_screen_px"], "tag_camera.png"),
    }

    # 도감: 키트 그림을 그대로 쓰고, 그림이 있는 부분의 가운데를 DOGAM_CENTER에 4화소 칸으로 맞춘다
    dogam = np.array(Image.open(ART / "kit_dogam.png").convert("RGBA"))
    Image.fromarray(dogam, "RGBA").save(OUT / "dogam.png")
    ys, xs = np.where(dogam[..., 3] > 0)
    vis = (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))
    vis_tl = [math.floor((DOGAM_CENTER[i] - vis[i] * TOOL_CELL / 2) / TOOL_CELL + 0.5) * TOOL_CELL for i in (0, 1)]
    dogam_tl = [vis_tl[0] - int(xs.min()) * TOOL_CELL, vis_tl[1] - int(ys.min()) * TOOL_CELL]
    pieces["dogam"] = {"file": "dogam.png", "size": [int(dogam.shape[1]), int(dogam.shape[0])], "tl_px": dogam_tl,
                       "px_per_cell": TOOL_CELL}
    # 이름표는 그림(빈 둘레 포함) 아래 8화소, 가운데 맞춤 (키트의 미리보기와 같다)
    tag, (l, t, r, b) = opaque(ART / "tag_dogam_1x.png")
    tag = tag[t:b, l:r]
    Image.fromarray(tag, "RGBA").save(OUT / "tag_dogam.png")
    art_bottom = dogam_tl[1] + dogam.shape[0] * TOOL_CELL
    tag_x = DOGAM_CENTER[0] - tag.shape[1] * TOOL_CELL // 2
    pieces["tag_dogam"] = {"file": "tag_dogam.png", "size": [int(tag.shape[1]), int(tag.shape[0])],
                           "tl_px": [tag_x - tag_x % TOOL_CELL, art_bottom + TAG_GAP], "px_per_cell": TOOL_CELL}

    # 화살표 둘 (아랫줄은 반투명): 화면 가운데, 닫힌 가방 윗단에서 6칸 위
    arrows = np.array(Image.open(ART / "chevron_1x.png").convert("RGBA"))
    Image.fromarray(arrows, "RGBA").save(OUT / "arrows.png")
    aw, ah = arrows.shape[1], arrows.shape[0]
    closed_top = lay["screen_px"][1] - HINT_PX
    pieces["arrows"] = {"file": "arrows.png", "size": [aw, ah],
                        "tl_px": [(lay["screen_px"][0] - aw * TOOL_CELL) // 2, closed_top - (ARROW_GAP + ah) * TOOL_CELL],
                        "px_per_cell": TOOL_CELL}

    shadow = lay["tool_shadow"]
    bag_shadow = lay["motion"]["bag_shadow_on_ground"]
    data = {
        "note": "디자인 세션 원본(1칸 = 1화소, 2026-10-22)과 배치값(art/bag/design_layout.json)에서 tools/bag_import.py가 만들었다. "
                "도감 그림은 키트로 만든 그림(art/bag/kit_dogam.png). 좌표는 1080×2400 폰 화소.",
        "design_px": lay["screen_px"],
        "bag_cell_px": BAG_CELL,
        "tool_cell_px": TOOL_CELL,
        "bag": {"file": "bag.png", "size": [bag_w, bag_h], "tl_px": bag_tl},
        "lining": {"top": top, "bottom": bottom, "left": left, "right": right},
        "stretch": {"col_period": 8, "col_runs": col_runs, "row_period": 12, "row_runs": row_runs},
        "hint_rows": HINT_PX // BAG_CELL,
        "tools": [
            {"id": "dogam", "art": "dogam", "tag": "tag_dogam"},
            {"id": "binoculars", "art": "binoculars", "tag": "tag_binoculars"},
            {"id": "camera", "art": "camera", "tag": "tag_camera"},
        ],
        "pieces": pieces,
        "tool_shadow": {"color": shadow["color"].lower(),
                        "offset_cells": [shadow["offset_px"][0] // TOOL_CELL, shadow["offset_px"][1] // TOOL_CELL]},
        # 가방 둘레 바닥 그림자: 가방 모양을 max_filter_px만큼 넓혀 blur_px(가우스 표준편차)로 흐린 것.
        # 세기 = strength × max(흐림 정도, min_focus). 화소는 폰(가방 한 칸 5화소) 기준
        "bag_shadow": {"max_filter_px": int(bag_shadow["max_filter_px"]), "blur_px": float(bag_shadow["gaussian_blur_px"]),
                       "strength": 0.28, "min_focus": 0.25},
    }
    assert "0.28*max(a, 0.25)" in bag_shadow["strength"], "그림자 세기 식이 바뀌었으면 위 값도 고친다"
    (OUT / "bag.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"가방 {bag_w}×{bag_h}칸, 안감 {top}~{bottom}행, 늘일 칸 {col_runs}, 늘일 줄 {row_runs}")
    for k, v in pieces.items():
        print(f"  {k}: {v['size'][0]}×{v['size'][1]} (한 칸 {v['px_per_cell']}화소), 왼쪽 위 {v['tl_px']}화소")


if __name__ == "__main__":
    main()
