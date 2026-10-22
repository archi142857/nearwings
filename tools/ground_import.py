#!/usr/bin/env python3
"""발밑 바닥 가져오기: 디자인 세션이 벌마다 그린 바닥 그림(색을 입힌 1칸 = 1화소)을 색 번호 그림으로 바꾼다.

가방 메뉴를 열면 공원이 위로 빠지면서 발밑 바닥이 따라 올라온다(결정 기록 2026-10-22, 가방 메뉴 작업 기준).
바닥은 디자인 세션이 월드 색표 색만 써서 그렸다(공유 폴더 `디자인 원본\\1022 가방 메뉴\\바닥\\`).

입력: art/ground/<서식지>_<벌>_ground.png (벌: portrait 240×480, square 480×480, landscape 480×300)
출력: game/assets/habitats/<서식지>/<벌>/ground_index.png (칸마다 색 번호)
      색표(palettes.json)에 없는 색은 낮 색표 끝에 더하고, 저녁·새벽·밤 색은 지금 임시 변환으로 만들어 더한다.
이어서 tools/bake_palettes.py가 색표마다 ground_<색표>.png와 흐린 ground_blur_<색표>.png를 굽는다.

사용법: python3 tools/ground_import.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canvas_import import evening          # noqa: E402  임시 저녁 변환
from time_palettes import TRANSFORMS, make  # noqa: E402  임시 새벽·밤 변환

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "ground"
HABITATS = ROOT / "game" / "assets" / "habitats"
SETS = ("portrait", "square", "landscape")


def hex_of(c) -> str:
    return "#%02x%02x%02x" % tuple(int(v) for v in c)


def rgb_of(h: str):
    return tuple(int(h[k:k + 2], 16) for k in (1, 3, 5))


def import_habitat(habitat: str) -> None:
    folder = HABITATS / habitat
    path = folder / "palettes.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    pal = data["palettes"]
    lut = {rgb_of(h): i for i, h in enumerate(pal["day"])}
    added = []
    for s in SETS:
        src = ART / f"{habitat}_{s}_ground.png"
        if not src.exists():
            continue
        img = np.array(Image.open(src).convert("RGBA"))
        assert (img[..., 3] == 255).all(), f"{src.name}: 투명한 칸이 있다"
        scene = Image.open(folder / s / "index.png").size
        assert img.shape[1] == scene[0], f"{src.name}: 폭이 장면({scene[0]}칸)과 다르다"
        rgb = img[..., :3]
        for c in map(tuple, np.unique(rgb.reshape(-1, 3), axis=0)):
            if c not in lut:
                lut[c] = len(pal["day"])
                pal["day"].append(hex_of(c))
                added.append(hex_of(c))
                for name in pal:
                    if name == "day":
                        continue
                    if name == "evening":
                        pal[name].append(hex_of(evening(np.array(c))))
                    else:
                        mul, add = TRANSFORMS[name]
                        pal[name].append(make([hex_of(c)], mul, add)[0])
        index = np.zeros(rgb.shape[:2], np.uint8)
        for c, i in lut.items():
            index[(rgb == c).all(-1)] = i
        Image.fromarray(index, "L").save(folder / s / "ground_index.png")
        print(f"{habitat}/{s}: {img.shape[1]}×{img.shape[0]}칸")
    assert len(pal["day"]) <= 256
    if added:
        data["note"] = (data["note"].rstrip() + f" 발밑 바닥 색 {len(added)}개(디자인 세션 바닥)는 낮 색표 끝에 더했다(tools/ground_import.py).")
        path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"  색표에 더한 색: {', '.join(added)}")


def main() -> None:
    habitats = sorted({p.name.rsplit("_", 2)[0] for p in ART.glob("*_ground.png")})
    for h in habitats:
        import_habitat(h)


if __name__ == "__main__":
    main()
