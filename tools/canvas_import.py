#!/usr/bin/env python3
"""디자인 캔버스 '새바라기 까치 디자인 시안'의 시안 PNG에서 M1 시험용 그림을 만든다.

임시 도구다. 디자인 세션이 `03_개발 계획.md`의 '그림 넘겨받기' 형식(1칸 = 1화소 원본)으로
그림을 넘겨주면 이 도구 대신 그 파일을 그대로 쓴다.

입력: 캔버스에서 내려받은 PNG가 있는 폴더(파일 이름은 캔버스의 그림 id).
  - Pg_Lineup: 새 10종 기본 자세 (칸 하나를 4화소로 키운 그림)
  - Pg_Devices: 폴더블 펼침 가로·세로 화면 (배경 칸 5화소, 새 칸 4화소)
출력: game/assets/birds/*.png, game/assets/habitats/urban_river_park/palettes.json,
      art/habitats/urban_river_park/world_index.png (480×480 월드. 횃대는 같은 폴더의 world_perches.json, 손으로 잡음)
      이어서 tools/temp_sets.py가 월드에서 세로형·정사각형·가로형 임시 벌을 잘라 만들고,
      tools/bake_palettes.py가 벌마다 구운 배경(baked_*.png)을 만든다.

배경은 두 기기 화면을 이어 붙여 480×480 월드를 만들고, 그 위에 그려진 새를 지운 뒤
주변 색으로 메운다. 오른쪽 위 48×60칸은 어느 화면에도 없어서 왼쪽 하늘을 이어 그렸다.

사용법: python3 tools/canvas_import.py <캔버스 PNG 폴더>
"""
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game" / "assets"

LINEUP = {  # 종 ID -> 캔버스 그림 id (Pg_Lineup)
    "ardea_cinerea": "6c6330057c50557c6726f0d2de5e9da2",
    "anas_platyrhynchos": "970124d39426417804b4290e60b9f096",
    "corvus_macrorhynchos": "7d3cc38b1963214d61efd4b48b4228cc",
    "pica_serica": "6155d5cb4dbb1d01816886aef979f4e5",
    "streptopelia_orientalis": "eeb0828813be4e99ae7559aa2098176c",
    "hypsipetes_amaurotis": "364d0b636b9c9c26687b10393176f216",
    "parus_minor": "560428448115a0ccd71b54f7bb123192",
    "passer_montanus": "c42c398159b03bff2b49401fac7986a6",
    "poecile_palustris": "fadf66a25388c1a56b47ecb6b960ed86",
    "suthora_webbiana": "f534b2129f66b6f43469d1bfaacca750",
}
FOLD_LAND = "735d68b8a5736e923b6ba810d5e6f7ba"  # 480×432칸, 월드 60행부터 (아래 12행은 월드 밖이라 검정)
FOLD_PORT = "471bf4b2d1c379817fca60fec494a948"  # 432×480칸, 월드 0열부터

# 장면 속 새 (폴더블 가로 화면 기준 월드 칸 범위): 비행 그림과 헤엄 자세를 여기서 오린다
SCENE_BIRDS = {
    "pica_serica_fly1": ((338, 116, 382, 141), None),
    "anas_platyrhynchos_swim": ((43, 285, 89, 312), None),
    "passer_montanus_fly1": ((392, 366, 432, 383), "left"),
}


def cells_of(px, cell):
    h, w, c = px.shape
    b = px.reshape(h // cell, cell, w // cell, cell, c).transpose(0, 2, 1, 3, 4)
    b = b.reshape(h // cell, w // cell, cell * cell, c)
    center = b[:, :, (cell // 2) * cell + cell // 2, :]
    mixed = ~np.all(b == b[:, :, :1, :], axis=(2, 3))
    return center, mixed


def load(src, key, mode="RGB"):
    return np.array(Image.open(src / f"{key}.png").convert(mode))


def lineup_sprites(src):
    for sid, key in LINEUP.items():
        a = load(src, key, "RGBA")
        ys, xs = np.nonzero(a[:, :, 3])
        sub = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        cells = sub[2::4, 2::4]
        assert (np.repeat(np.repeat(cells, 4, 0), 4, 1) == sub).all(), sid
        Image.fromarray(cells).save(ASSETS / "birds" / f"{sid}.png")
        print(f"새 {sid}: {cells.shape[1]}×{cells.shape[0]}칸")


def build_world(src):
    fl, fl_mix = cells_of(load(src, FOLD_LAND), 5)
    fp, fp_mix = cells_of(load(src, FOLD_PORT), 5)
    world = np.zeros((480, 480, 3), np.uint8)
    mixed = np.zeros((480, 480), bool)
    world[60:480], mixed[60:480] = fl[:420], fl_mix[:420]
    world[0:60, 0:432], mixed[0:60, 0:432] = fp[0:60], fp_mix[0:60]
    for y in range(60):
        world[y, 432:] = world[y, 431]
    # 새가 덮은 칸: 칸 하나에 색이 섞인 곳(새 테두리) + 배경에 드문 색, 그 안쪽까지
    first = ndi.binary_fill_holes(ndi.binary_dilation(mixed, iterations=1))
    outside = ~ndi.binary_dilation(first, iterations=2)
    common = {c for c, n in Counter(map(tuple, world[outside])).items() if n >= 20}
    rare = np.array([[tuple(world[y, x]) not in common for x in range(480)] for y in range(480)])
    mask = ndi.binary_fill_holes(ndi.binary_dilation(first | rare, iterations=1))
    labels, n = ndi.label(mask)
    raw = world.copy()
    todo = mask.copy()
    for _ in range(300):  # 주변에서 가장 흔한 색으로 바깥부터 메운다 (가로 이웃에 가중치)
        if not todo.any():
            break
        fills = {}
        for y, x in zip(*np.nonzero(todo)):
            c = Counter()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if (dy or dx) and 0 <= yy < 480 and 0 <= xx < 480 and not todo[yy, xx]:
                        c[tuple(world[yy, xx])] += 3 if dy == 0 else 1
            if sum(c.values()) >= 5:
                fills[(y, x)] = c.most_common(1)[0][0]
        for (y, x), col in fills.items():
            world[y, x] = col
            todo[y, x] = False
    print(f"월드 480×480칸, 지운 새 {n}마리, 색 {len(set(map(tuple, world.reshape(-1, 3))))}개")
    return world, raw


def scene_birds(src, world_clean):
    px = load(src, FOLD_LAND).astype(np.int16)
    bg = np.repeat(np.repeat(world_clean.astype(np.int16), 5, 0), 5, 1)[300:300 + px.shape[0]]
    for name, ((x0, y0, x1, y1), half) in SCENE_BIRDS.items():
        X0, X1, Y0, Y1 = x0 * 5, x1 * 5, (y0 - 60) * 5, (y1 - 60) * 5
        P, B = px[Y0:Y1, X0:X1], bg[Y0:Y1, X0:X1]
        diff = np.any(P != B, axis=2)
        best = None
        for ox in range(4):
            for oy in range(4):
                h = np.any(P[:, 1:] != P[:, :-1], axis=2) & (diff[:, 1:] | diff[:, :-1])
                v = np.any(P[1:] != P[:-1], axis=2) & (diff[1:] | diff[:-1])
                bad = ((np.nonzero(h)[1] + 1 + X0 - ox) % 4 != 0).sum() + ((np.nonzero(v)[0] + 1 + Y0 - oy) % 4 != 0).sum()
                if best is None or bad < best[0]:
                    best = (bad, ox, oy)
        _, ox, oy = best
        gx0, gy0 = X0 + (ox - X0) % 4, Y0 + (oy - Y0) % 4
        ny, nx = (Y1 - gy0) // 4, (X1 - gx0) // 4
        out = np.zeros((ny, nx, 4), np.uint8)
        for j in range(ny):
            for i in range(nx):
                yy, xx = gy0 + j * 4 + 2 - Y0, gx0 + i * 4 + 2 - X0
                out[j, i, :3] = P[yy, xx]
                out[j, i, 3] = 255 if diff[yy, xx] else 0
        filled = ndi.binary_fill_holes(out[:, :, 3] > 0)
        out[:, :, 3] = np.where(filled, 255, 0)
        # 물결처럼 배경 쪽 밝은 하늘색 칸은 뺀다
        light = (out[:, :, 0] > 150) & (out[:, :, 2] > 190) & (out[:, :, 2] > out[:, :, 0] + 10)
        out[light, 3] = 0
        lab, n = ndi.label(out[:, :, 3] > 0)
        if n > 1:
            sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
            keep = np.argsort(sizes)[::-1][:2 if half else 1] + 1
            out[~np.isin(lab, keep), 3] = 0
        if half == "left":
            ys, xs = np.nonzero(out[:, :, 3])
            mid = (xs.min() + xs.max() + 1) // 2
            out[:, mid:, 3] = 0
        ys, xs = np.nonzero(out[:, :, 3])
        out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        out[out[:, :, 3] == 0] = 0
        Image.fromarray(out).save(ASSETS / "birds" / f"{name}.png")
        print(f"장면 새 {name}: {out.shape[1]}×{out.shape[0]}칸")


def srgb_to_lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    s = np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
    return np.round(s * 255).astype(int)


def evening(rgb):
    """임시 저녁 색: 따뜻하게 물들이고 조금 어둡게. 디자인 세션의 저녁 색표가 오면 바꾼다."""
    lin = srgb_to_lin(rgb)
    lin = lin * np.array([1.0, 0.80, 0.64]) * 0.80 + np.array([0.05, 0.022, 0.018])
    return tuple(lin_to_srgb(lin))


def write_habitat(world):
    out = ASSETS / "habitats" / "urban_river_park"
    art = ROOT / "art" / "habitats" / "urban_river_park"
    art.mkdir(parents=True, exist_ok=True)
    counts = Counter(map(tuple, world.reshape(-1, 3)))
    colors = [c for c, _ in counts.most_common()]
    assert len(colors) <= 256
    lut = {c: i for i, c in enumerate(colors)}
    index = np.array([[lut[tuple(world[y, x])] for x in range(480)] for y in range(480)], np.uint8)
    Image.fromarray(index, "L").save(art / "world_index.png")
    hexs = lambda cs: ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in cs]
    data = {
        "note": "임시: 디자인 캔버스 시안(폴더블 화면)에서 모은 색. 저녁은 코드 세션이 만든 임시 변환이다.",
        "order": ["day", "evening"],
        "palettes": {"day": hexs(colors), "evening": hexs([evening(c) for c in colors])},
    }
    (out / "palettes.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"배경: 색 번호 {len(colors)}개. 다음: python3 tools/temp_sets.py && python3 tools/bake_palettes.py")


def main():
    src = Path(sys.argv[1])
    (ASSETS / "birds").mkdir(parents=True, exist_ok=True)
    (ASSETS / "habitats" / "urban_river_park").mkdir(parents=True, exist_ok=True)
    lineup_sprites(src)
    world, _ = build_world(src)
    scene_birds(src, world)
    write_habitat(world)


if __name__ == "__main__":
    main()
