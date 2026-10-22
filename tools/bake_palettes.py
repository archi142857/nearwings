#!/usr/bin/env python3
"""서식지 배경 굽기: <벌>/index.png(칸마다 색 번호) + palettes.json(색표들) → <벌>/baked_<색표>.png (1칸 = 1화소).
발밑 바닥(<벌>/ground_index.png)이 있으면 ground_<색표>.png와 흐린 ground_blur_<색표>.png도 굽는다(가방 메뉴).

서식지마다 세로형·정사각형·가로형 세 벌(portrait, square, landscape)이 있고 색표는 서식지에 하나다.
게임은 구운 그림을 그리고, 낮·저녁처럼 두 색표 사이는 구운 그림 두 장을 섞어 그린다.
칸마다 색만 바뀌므로 두 그림을 섞는 것은 색표를 섞는 것과 같다. 위젯도 구운 그림을 그대로 쓴다.
원본은 index.png와 palettes.json이고, 구운 그림은 이 도구로 언제든 다시 만든다.

사용법: python3 tools/bake_palettes.py [서식지 폴더 ...]  (생략하면 game/assets/habitats/* 전부)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
SETS = ("portrait", "square", "landscape")
GROUND_BLUR = 1.1   # 가방 메뉴에서 흐려진 발밑 바닥 (가우스 흐림, 칸 단위). 흐린 뒤에도 1칸 = 1화소라 칸 느낌이 남는다


def bake(habitat: Path) -> None:
    data = json.loads((habitat / "palettes.json").read_text(encoding="utf-8"))
    luts = {}
    for name in data["order"]:
        cols = data["palettes"][name]
        lut = np.zeros((256, 3), np.uint8)
        for i, h in enumerate(cols):
            h = h.lstrip("#")
            lut[i] = [int(h[k:k + 2], 16) for k in (0, 2, 4)]
        luts[name] = (lut, len(cols))
    done = []
    for s in SETS:
        folder = habitat / s
        if not (folder / "index.png").exists():
            continue
        index = np.array(Image.open(folder / "index.png").convert("L"))
        for name, (lut, n) in luts.items():
            assert index.max() < n, f"{habitat.name}/{s}: 색 번호 {index.max()}가 색표({n}개) 밖"
            Image.fromarray(lut[index], "RGB").save(folder / f"baked_{name}.png")
        done.append(f"{s} {index.shape[1]}×{index.shape[0]}")
        if (folder / "ground_index.png").exists():   # 발밑 바닥: 또렷한 그림과 흐린 그림 (tools/make_ground.py)
            g = np.array(Image.open(folder / "ground_index.png").convert("L"))
            for name, (lut, n) in luts.items():
                assert g.max() < n, f"{habitat.name}/{s}: 바닥 색 번호 {g.max()}가 색표({n}개) 밖"
                sharp = lut[g]
                Image.fromarray(sharp, "RGB").save(folder / f"ground_{name}.png")
                blur = np.stack([ndi.gaussian_filter(sharp[..., c].astype(float), GROUND_BLUR, mode="nearest") for c in range(3)], -1)
                Image.fromarray(np.clip(np.round(blur), 0, 255).astype(np.uint8), "RGB").save(folder / f"ground_blur_{name}.png")
            done[-1] += " + 바닥"
    print(f"{habitat.name}: {', '.join(done)} / 색표 {', '.join(data['order'])} 구움")


def main() -> None:
    folders = [Path(a) for a in sys.argv[1:]] or sorted((ROOT / "game/assets/habitats").iterdir())
    for f in folders:
        if (f / "palettes.json").exists():
            bake(f)


if __name__ == "__main__":
    main()
