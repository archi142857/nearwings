#!/usr/bin/env python3
"""서식지 배경 굽기: <벌>/index.png(칸마다 색 번호) + palettes.json(색표들) → <벌>/baked_<색표>.png (1칸 = 1화소).
발밑 바닥(<벌>/ground_index.png)이 있으면 ground_<색표>.png도 굽고, 가방 메뉴에서 쓰는 흐린 그림
(baked_blur_<색표>.png, ground_blur_<색표>.png)도 굽는다.

서식지마다 세로형·정사각형·가로형 세 벌(portrait, square, landscape)이 있고 색표는 서식지에 하나다.
게임은 구운 그림을 그리고, 낮·저녁처럼 두 색표 사이는 구운 그림 두 장을 섞어 그린다.
칸마다 색만 바뀌므로 두 그림을 섞는 것은 색표를 섞는 것과 같다. 위젯도 구운 그림을 그대로 쓴다.
원본은 index.png와 palettes.json이고, 구운 그림은 이 도구로 언제든 다시 만든다.

흐린 그림은 디자인 세션 배치값(art/bag/design_layout.json 'focus_pull')을 따른다: 폰 화면(한 칸 5화소)에서
가우스 3.6화소로 흐린 뒤 5화소 칸마다 평균을 낸다. 같은 계산을 칸 단위로 바로 한다(KERNEL). 공원과 발밑 바닥은 한 장으로
이어지므로 장면 아래에 바닥을 붙여 함께 흐린 뒤 나눈다. 채도 빼기와 어둡게 하기는 게임이 흐린 정도에 맞춰 한다.

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
CELL_PX = 5        # 폰에서 배경 한 칸
BLUR_PX = 3.6      # 가방 메뉴를 다 열었을 때 흐림 (가우스 표준편차, 폰 화소)


def cell_kernel(cell: int = CELL_PX, sigma: float = BLUR_PX) -> np.ndarray:
    """칸을 cell화소로 키워 sigma화소로 흐리고 칸마다 평균을 내는 것과 같은 칸 단위 1차원 가중치."""
    reach = int(np.ceil(4.0 * sigma / cell)) + 1
    n = 2 * reach + 1
    x = np.zeros(n * cell)
    x[reach * cell:(reach + 1) * cell] = 1.0
    y = ndi.gaussian_filter1d(x, sigma, mode="constant")
    return y.reshape(n, cell).mean(axis=1)


KERNEL = cell_kernel()


def blur_cells(rgb: np.ndarray) -> np.ndarray:
    f = rgb.astype(float)
    for axis in (0, 1):
        f = ndi.convolve1d(f, KERNEL, axis=axis, mode="nearest")
    return np.clip(np.round(f), 0, 255).astype(np.uint8)


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
        g = None
        if (folder / "ground_index.png").exists():   # 발밑 바닥 (tools/ground_import.py)
            g = np.array(Image.open(folder / "ground_index.png").convert("L"))
        for name, (lut, n) in luts.items():
            assert index.max() < n, f"{habitat.name}/{s}: 색 번호 {index.max()}가 색표({n}개) 밖"
            scene = lut[index]
            Image.fromarray(scene, "RGB").save(folder / f"baked_{name}.png")
            if g is None:
                continue
            assert g.max() < n, f"{habitat.name}/{s}: 바닥 색 번호 {g.max()}가 색표({n}개) 밖"
            ground = lut[g]
            Image.fromarray(ground, "RGB").save(folder / f"ground_{name}.png")
            both = blur_cells(np.concatenate([scene, ground], axis=0))
            Image.fromarray(both[:scene.shape[0]], "RGB").save(folder / f"baked_blur_{name}.png")
            Image.fromarray(both[scene.shape[0]:], "RGB").save(folder / f"ground_blur_{name}.png")
        done.append(f"{s} {index.shape[1]}×{index.shape[0]}" + (" + 바닥" if g is not None else ""))
    print(f"{habitat.name}: {', '.join(done)} / 색표 {', '.join(data['order'])} 구움")


def main() -> None:
    folders = [Path(a) for a in sys.argv[1:]] or sorted((ROOT / "game/assets/habitats").iterdir())
    for f in folders:
        if (f / "palettes.json").exists():
            bake(f)


if __name__ == "__main__":
    main()
