#!/usr/bin/env python3
"""발밑 바닥 그림 만들기 (임시): 벌마다 장면 바로 아래로 이어지는 땅을 색 번호로 그린다.

가방 메뉴를 열면 공원이 위로 빠지면서 발밑 바닥이 따라 올라온다(결정 기록 2026-10-22, 가방 메뉴 작업 기준).
디자인 시안에는 폰 화면 하나 분량의 바닥만 있어서, 디자인 세션이 벌마다 바닥을 그려 주기 전까지 이 도구로 만든다.
도시 하천 공원은 풀밭에 풀 자국, 조약돌, 낙엽, 꽃잎을 흩뿌린다(시안의 바닥과 같은 재료, 장면 색표의 색 번호).

출력: game/assets/habitats/<서식지>/<벌>/ground_index.png (장면과 같은 크기, 칸마다 색 번호)
이어서 tools/bake_palettes.py가 색표마다 ground_<색표>.png와 흐린 ground_blur_<색표>.png를 굽는다.

사용법: python3 tools/make_ground.py
"""
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
HABITAT = ROOT / "game" / "assets" / "habitats" / "urban_river_park"
SETS = ("portrait", "square", "landscape")

GRASS = 1          # 풀밭
MARK = 20          # 풀 자국 (조금 진한 풀색)
TUFT = 6           # 밝은 풀포기
PEBBLE = 27        # 조약돌
PEBBLE_SHADE = 13  # 조약돌 아랫면
LEAVES = (18, 12)  # 낙엽 (갈색, 올리브 갈색)
PETAL = 26         # 꽃잎 (분홍)


def ground(w: int, h: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    g = np.full((h, w), GRASS, np.uint8)

    def put(y, x, v):
        if 0 <= y < h and 0 <= x < w:
            g[y, x] = v

    area = w * h

    def row() -> int:
        # 장면과 맞닿는 위쪽은 장면 풀밭처럼 성기게, 60줄쯤 내려가면 바닥 밀도가 된다
        while True:
            y = int(rng.integers(h))
            if rng.random() < min(1.0, 0.35 + y / 90.0):
                return y

    for _ in range(area // 150):          # 풀 자국: 두 칸짜리 빗금이나 세로줄
        y, x = row(), int(rng.integers(w))
        kind = rng.integers(3)
        put(y, x, MARK)
        if kind == 0:
            put(y - 1, x + 1, MARK)
        elif kind == 1:
            put(y - 1, x - 1, MARK)
        else:
            put(y - 1, x, MARK)
    for _ in range(area // 900):          # 밝은 풀포기: 'V' 모양 세 칸
        y, x = row(), int(rng.integers(w))
        put(y, x, TUFT)
        put(y - 1, x - 1, TUFT)
        put(y - 1, x + 1, TUFT)
    for _ in range(area // 1100):         # 조약돌: 두세 칸, 아랫면이 조금 어둡다
        y, x = row(), int(rng.integers(w))
        n = int(rng.integers(2, 4))
        for i in range(n):
            put(y, x + i, PEBBLE)
            put(y + 1, x + i, PEBBLE_SHADE)
    for _ in range(area // 1300):         # 낙엽: 한두 칸
        y, x = row(), int(rng.integers(w))
        c = int(LEAVES[int(rng.integers(len(LEAVES)))])
        put(y, x, c)
        if rng.random() < 0.6:
            put(y, x + 1, c)
    for _ in range(area // 1600):         # 꽃잎: 한 칸
        put(row(), int(rng.integers(w)), PETAL)
    return g


def main() -> None:
    for s in SETS:
        folder = HABITAT / s
        if not (folder / "index.png").exists():
            continue
        w, h = Image.open(folder / "index.png").size
        img = ground(w, h, zlib.crc32(s.encode()))
        Image.fromarray(img, "L").save(folder / "ground_index.png")
        print(f"{s}: 발밑 바닥 {w}×{h}칸")


if __name__ == "__main__":
    main()
