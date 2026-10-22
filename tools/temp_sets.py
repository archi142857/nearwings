#!/usr/bin/env python3
"""임시 세 벌 만들기: 디자인 캔버스에서 뽑은 480×480 월드 하나로 세로형·정사각형·가로형 배경을 잘라 만든다.

결정(2026-10-22): 배경은 서식지마다 세로형·정사각형·가로형 세 벌을 그리고, 기기 화면 비율에 가장 가까운 벌을
화면에 꽉 차게 쓴다. 디자인 세션이 세 벌을 따로 그려 주기 전까지 이 도구로 만든 임시 벌을 쓴다.

입력: art/habitats/<서식지>/world_index.png (칸마다 색 번호, 480×480), world_perches.json (월드 칸 좌표)
출력: game/assets/habitats/<서식지>/<벌>/index.png, perches.json  (구운 그림은 tools/bake_palettes.py)

벌마다 월드에서 자를 곳 (월드 칸). 왼쪽 끝 나무 줄기가 잘리지 않게, 비율이 조금 다른 기기에서 가장자리가
잘려도 줄기가 남도록 왼쪽에 0번 열을 몇 칸 이어 붙인다(임시 그림이라 줄기가 조금 굵어 보일 수 있다).

사용법: python3 tools/temp_sets.py [서식지 ...]   (생략하면 art/habitats/* 전부)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# 벌 이름: (크기 w×h, 왼쪽에 이어 붙일 열 수, 월드에서 자를 x0, y0)
SETS = {
    "portrait": ((240, 480), 12, 0, 0),     # 폰 세로에서는 가운데 216칸 = 월드 왼쪽 216칸(지금까지와 같은 창)
    "square": ((480, 480), 24, 0, 0),       # 폴더블 펼침 세로에서는 가운데 432칸 = 월드 왼쪽 432칸
    "landscape": ((480, 300), 0, 0, 120),   # 월드 아래쪽 띠: 길·벤치·갈대·강이 다 들어가게
}
CUT_MARGIN = 4.0   # 잘린 그림 끝에 걸친 점 횃대(갈대 등)는 뺀다


def make_index(world: np.ndarray, size, pad, x0, y0) -> np.ndarray:
    w, h = size
    src = world[y0:y0 + h]
    if pad:
        src = np.concatenate([np.repeat(src[:, :1], pad, axis=1), src], axis=1)
    out = src[:, x0:x0 + w]
    assert out.shape == (h, w), out.shape
    return out


def move_perch(p: dict, dx: float, dy: float, w: float, h: float):
    """월드 칸 → 벌 칸. 벌 밖으로 나가는 부분은 잘라 내고, 거의 다 밖이면 뺀다."""
    q = dict(p)
    if p["shape"] == "point":
        x, y = p["a"][0] + dx, p["a"][1] + dy
        if not (CUT_MARGIN <= x <= w - CUT_MARGIN and 0 <= y <= h):
            return None
        q["a"] = [x, y]
    elif p["shape"] == "segment":
        a = np.array(p["a"], float) + (dx, dy)
        b = np.array(p["b"], float) + (dx, dy)
        lo, hi = np.array([0.0, 0.0]), np.array([w, h])
        if (np.minimum(a, b) < lo).any() or (np.maximum(a, b) > hi).any():
            return None   # 선 횃대(가지·벤치)는 통째로 들어올 때만 쓴다
        q["a"], q["b"] = [round(float(v), 2) for v in a], [round(float(v), 2) for v in b]
    else:
        r = np.array(p["rect"], float) + (dx, dy, dx, dy)
        r = [max(r[0], 0.0), max(r[1], 0.0), min(r[2], w), min(r[3], h)]
        if r[2] - r[0] < 8 or r[3] - r[1] < 2:
            return None
        q["rect"] = [round(v, 2) for v in r]
    return q


def build(habitat: Path) -> None:
    world = np.array(Image.open(habitat / "world_index.png").convert("L"))
    perches = json.loads((habitat / "world_perches.json").read_text(encoding="utf-8"))["perches"]
    out_root = ROOT / "game" / "assets" / "habitats" / habitat.name
    for name, (size, pad, x0, y0) in SETS.items():
        w, h = size
        out = out_root / name
        out.mkdir(parents=True, exist_ok=True)
        Image.fromarray(make_index(world, size, pad, x0, y0), "L").save(out / "index.png")
        dx, dy = pad - x0, -y0
        moved = [q for q in (move_perch(p, dx, dy, w, h) for p in perches) if q is not None]
        data = {
            "habitat": habitat.name,
            "set": name,
            "size": [w, h],
            "note": "임시: tools/temp_sets.py가 디자인 캔버스 월드(art/habitats)에서 잘라 만든 벌. "
                    "단위는 이 벌의 배경 칸. y는 새 발끝이 닿는 면. max_w는 앉을 수 있는 새 그림의 가장 큰 너비(새 칸).",
            "perches": moved,
        }
        (out / "perches.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{habitat.name}/{name}: {w}×{h}칸, 횃대 {len(moved)}개 ({', '.join(sorted({q['kind'] for q in moved}))})")


def main() -> None:
    habitats = [Path(a) for a in sys.argv[1:]] or sorted((ROOT / "art" / "habitats").iterdir())
    for h in habitats:
        if (h / "world_index.png").exists():
            build(h)


if __name__ == "__main__":
    main()
