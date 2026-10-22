#!/usr/bin/env python3
"""임시 시간대 색표: 낮(day) 색표에서 새벽(dawn)·밤(night) 색표를 만들어 palettes.json에 넣는다.

배경은 시간대에 따라 바뀐다(결정 기록 2026-10-22). 시간대 색표는 디자인 세션이 줄 때까지 이 도구로 만든
임시 변환을 쓴다. 저녁(evening)은 canvas_import.py가 만든 임시 변환을 그대로 둔다.
선형 빛 공간에서 채널마다 곱하고 조금 더한다. 밤도 새를 찾을 수 있게 너무 어둡게 하지는 않았다.

사용법: python3 tools/time_palettes.py [서식지 폴더 ...]  → 이어서 python3 tools/bake_palettes.py
"""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
ORDER = ["day", "dawn", "evening", "night"]

# 이름: (곱, 더함)  선형 빛 기준
TRANSFORMS = {
    "dawn": ((0.78, 0.68, 0.76), (0.030, 0.012, 0.028)),    # 조금 어둡고 분홍·보라 기운
    "night": ((0.22, 0.26, 0.40), (0.004, 0.008, 0.022)),   # 어둡고 푸른 밤
}


def srgb_to_lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    s = np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
    return np.round(s * 255).astype(int)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return [int(h[k:k + 2], 16) for k in (0, 2, 4)]


def make(day_hex, mul, add):
    out = []
    for h in day_hex:
        lin = srgb_to_lin(hex_to_rgb(h)) * np.array(mul) + np.array(add)
        out.append("#%02x%02x%02x" % tuple(int(v) for v in lin_to_srgb(lin)))
    return out


def update(habitat: Path) -> None:
    path = habitat / "palettes.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    day = data["palettes"]["day"]
    for name, (mul, add) in TRANSFORMS.items():
        data["palettes"][name] = make(day, mul, add)
    data["order"] = [n for n in ORDER if n in data["palettes"]]
    data["note"] = ("임시: 디자인 캔버스 시안(폴더블 화면)에서 모은 색. 저녁·새벽·밤은 코드 세션이 낮 색에서 만든 임시 변환이다"
                    "(tools/canvas_import.py, tools/time_palettes.py). 디자인 세션의 시간대 색표가 오면 바꾼다.")
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{habitat.name}: {', '.join(data['order'])} ({len(day)}색)")


def main() -> None:
    folders = [Path(a) for a in sys.argv[1:]] or sorted((ROOT / "game/assets/habitats").iterdir())
    for f in folders:
        if (f / "palettes.json").exists():
            update(f)


if __name__ == "__main__":
    main()
