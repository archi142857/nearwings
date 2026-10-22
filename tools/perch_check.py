#!/usr/bin/env python3
"""기기마다 새 오는 확률이 같은지 보는 검사.

게임은 어떤 새가 올지를 화면과 상관없이 정하고, 그 새를 지금 보이는 횃대에 앉힌다(bird_spawner.gd).
그래서 어느 기기에서든 모든 종이 앉을 자리가 화면 안(위·아래 버튼 줄은 빼고)에 있어야 확률이 같다.
이 도구는 여러 기기 화면마다 게임과 같은 규칙으로 배경 벌·배율·보이는 곳을 계산하고,
종마다 앉을 자리가 있는지 본다. 벌마다 그 벌을 쓰는 기기 모두에 늘 보이는 '새 놓을 곳'(안전 영역)도 알려 준다.

사용법: python3 tools/perch_check.py [서식지 ...] [--draw 그림.png]   (하나라도 빠지면 종료 코드 1)
  --draw: 벌마다 늘 보이는 새 놓을 곳(빨간 테두리)과 횃대(파랑)를 배경 위에 그린 그림을 만든다 (디자인 세션용)
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
SETS = ("portrait", "square", "landscape")
LABEL = {"portrait": "세로형", "square": "정사각형", "landscape": "가로형"}
MARGIN = 3.0      # bird_spawner.gd MARGIN
BIRD_CELL = 0.8   # 배경 칸 1.25배

# 이름, 너비, 높이, 1dp 화소 수 (스크린샷 기기 9종 + 그 밖에 흔한 비율)
DEVICES = [
    ("폰 1080x2400", 1080, 2400, 2.625),
    ("폰 1080x2340", 1080, 2340, 2.625),
    ("폰 16:9 1080x1920", 1080, 1920, 2.625),
    ("아이폰 1179x2556", 1179, 2556, 3.0),
    ("플립 1080x2640", 1080, 2640, 2.625),
    ("폴더블 바깥 904x2316", 904, 2316, 2.625),
    ("폴더블 펼침 1812x2176", 1812, 2176, 2.625),
    ("폴더블 펼침 2160x2400", 2160, 2400, 2.625),
    ("폴더블 펼침 가로 2400x2160", 2400, 2160, 2.625),
    ("펼친 폴더블 가로 2208x1840", 2208, 1840, 2.625),
    ("창 나누기 1080x1150", 1080, 1150, 2.625),
    ("태블릿 나누기 1280x1600", 1280, 1600, 2.0),
    ("태블릿 세로 1600x2560", 1600, 2560, 2.0),
    ("태블릿 세로 3:2 1600x2400", 1600, 2400, 2.0),
    ("태블릿 세로 4:3 1536x2048", 1536, 2048, 2.0),
    ("태블릿 가로 2560x1600", 2560, 1600, 2.0),
    ("태블릿 가로 4:3 2048x1536", 2048, 1536, 2.0),
    ("가로 16:9 1920x1080", 1920, 1080, 1.5),
]


def png_size(path: Path):
    return Image.open(path).size


def load(habitat: Path):
    sets = {}
    for s in SETS:
        if (habitat / s / "index.png").exists():
            sets[s] = {
                "size": png_size(habitat / s / "index.png"),
                "perches": json.loads((habitat / s / "perches.json").read_text(encoding="utf-8"))["perches"],
            }
    species = json.loads((GAME / "data" / "species.json").read_text(encoding="utf-8"))
    species = species["species"] if isinstance(species, dict) else species
    for sp in species:
        birds = GAME / "assets" / "birds"
        sp["stand"] = png_size(birds / f"{sp['id']}.png")
        swim = birds / f"{sp['id']}_swim.png"
        sp["swim"] = png_size(swim) if swim.exists() else None
    return sets, species


def choose(w, h, sets):
    a = w / h
    return min(sets, key=lambda s: abs(math.log(a / (sets[s]["size"][0] / sets[s]["size"][1]))))


def landing_rect(w, h, dens, scene):
    """layout.gd·main.gd·capture_ui.gd와 같은 셈: 꽉 채우는 배율, 가운데 창, 위·아래 버튼 줄을 뺀 곳 (화면 여백 0)."""
    px = max(w / scene[0], h / scene[1])
    vw, vh = w / px, h / px
    x0, y0 = (scene[0] - vw) / 2, (scene[1] - vh) / 2
    dp = lambda v: v * dens
    top = dp(64)
    k = max(round(px), math.ceil(dp(64) / 22))
    bottom = h - dp(20) - 22 * k - dp(8)
    play = (x0, y0 + top / px, x0 + vw, y0 + bottom / px)
    inner = (play[0] + MARGIN, play[1] + MARGIN, play[2] - MARGIN, play[3] - MARGIN)
    return px, (x0, y0, x0 + vw, y0 + vh), inner


def bounds(p):
    if p["shape"] == "area":
        return tuple(p["rect"])
    if p["shape"] == "segment":
        a, b = p["a"], p["b"]
        return (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))
    return (p["a"][0], p["a"][1], p["a"][0], p["a"][1])


def point_on(p, rng):
    if p["shape"] == "point":
        return tuple(p["a"])
    if p["shape"] == "segment":
        t = rng.random()
        a, b = p["a"], p["b"]
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    r = p["rect"]
    return (rng.uniform(r[0], r[2]), rng.uniform(r[1], r[3]))


def spots(sp, perches, inner, rng, tries=300):
    """이 종이 inner 안에 앉을 수 있는 횃대 id들 (find_spot과 같은 조건)."""
    out = []
    for p in perches:
        if p["kind"] not in sp["perches"] or sp["stand"][0] > p["max_w"]:
            continue
        water = p["kind"] == "water"
        if water and sp["swim"] is None:
            continue
        b = bounds(p)
        g = (b[0] - 1, b[1] - 1, b[2] + 1, b[3] + 1)
        if not (inner[0] < g[2] and g[0] < inner[2] and inner[1] < g[3] and g[1] < inner[3]):
            continue
        sw, sh = sp["swim"] if water else sp["stand"]
        for _ in range(tries):
            x, y = point_on(p, rng)
            y += 0.6
            r = (x - sw * BIRD_CELL / 2, y - sh * BIRD_CELL, x + sw * BIRD_CELL / 2, y)
            if r[0] >= inner[0] and r[1] >= inner[1] and r[2] <= inner[2] and r[3] <= inner[3]:
                out.append(p["id"])
                break
    return out


def check(habitat: Path) -> int:
    sets, species = load(habitat)
    rng = random.Random(1)
    bad = 0
    safe = {}
    print(f"[{habitat.name}] 기기마다 고른 벌과 앉을 자리가 없는 종")
    for name, w, h, dens in DEVICES:
        s = choose(w, h, sets)
        px, view, inner = landing_rect(w, h, dens, sets[s]["size"])
        missing = [sp["ko"] for sp in species if not spots(sp, sets[s]["perches"], inner, rng)]
        bad += bool(missing)
        prev = safe.get(s)
        safe[s] = inner if prev is None else (max(prev[0], inner[0]), max(prev[1], inner[1]), min(prev[2], inner[2]), min(prev[3], inner[3]))
        vis = f"{view[2] - view[0]:.0f}×{view[3] - view[1]:.0f}"
        print(f"  {'ok' if not missing else '!!'} {name:<26} {LABEL[s]:<5} 한 칸 {px:4.2f}화소, 보이는 칸 {vis:<8}"
              + (f" 빠진 종: {', '.join(missing)}" if missing else ""))
    print(f"[{habitat.name}] 벌마다 늘 보이는 새 놓을 곳 (위 기기 모두에서, 위·아래 버튼 줄과 가장자리 {MARGIN:.0f}칸 뺌)")
    for s in SETS:
        if s not in safe:
            continue
        r = safe[s]
        size = sets[s]["size"]
        everywhere = [sp["ko"] for sp in species if not spots(sp, sets[s]["perches"], r, rng)]
        print(f"  {LABEL[s]} {size[0]}×{size[1]}: x {r[0]:.0f}~{r[2]:.0f}, y {r[1]:.0f}~{r[3]:.0f}"
              f" ({(r[2] - r[0]) / size[0] * 100:.0f}%×{(r[3] - r[1]) / size[1] * 100:.0f}%)"
              + (f", 이 안에 자리가 없는 종: {', '.join(everywhere)}" if everywhere else ", 10종 모두 자리 있음"))
    if DRAW:
        draw(habitat, sets, safe, DRAW)
    return bad


def draw(habitat: Path, sets, safe, out: Path, k: int = 2) -> None:
    """벌마다 배경(2배) 위에 늘 보이는 새 놓을 곳과 횃대를 그린다."""
    font = ImageFont.truetype(str(GAME / "assets/fonts/Galmuri11-ksx1001.ttf"), 22)
    tiles = []
    for s in SETS:
        if s not in sets:
            continue
        im = Image.open(habitat / s / "baked_day.png").convert("RGB")
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for p in sets[s]["perches"]:
            b = [v * k for v in bounds(p)]
            if p["shape"] == "area":
                d.rectangle(b, outline=(40, 90, 200), width=2)
            elif p["shape"] == "segment":
                d.line([p["a"][0] * k, p["a"][1] * k, p["b"][0] * k, p["b"][1] * k], fill=(40, 90, 200), width=4)
            else:
                d.ellipse([b[0] - 5, b[1] - 5, b[0] + 5, b[1] + 5], fill=(40, 90, 200))
        r = [v * k for v in safe[s]]
        for i in range(3):
            d.rectangle([r[0] - i, r[1] - i, r[2] + i, r[3] + i], outline=(220, 40, 40))
        tiles.append((f"{LABEL[s]} {sets[s]['size'][0]}×{sets[s]['size'][1]}", im))
    gap, head = 24, 40
    W = sum(t.width for _, t in tiles) + gap * (len(tiles) + 1)
    H = max(t.height for _, t in tiles) + head + gap
    sheet = Image.new("RGB", (W, H), (46, 41, 34))
    d = ImageDraw.Draw(sheet)
    x = gap
    for label, t in tiles:
        d.text((x, 8), label, fill=(246, 241, 230), font=font)
        sheet.paste(t, (x, head))
        x += t.width + gap
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"그림: {out}")


DRAW = None


def main() -> None:
    global DRAW
    if "--draw" in sys.argv:
        i = sys.argv.index("--draw")
        DRAW = Path(sys.argv[i + 1])
        del sys.argv[i:i + 2]
    habitats = [Path(a) for a in sys.argv[1:]] or sorted((GAME / "assets" / "habitats").iterdir())
    bad = sum(check(h) for h in habitats if (h / "palettes.json").exists())
    print("앉을 자리 검사:", "통과" if not bad else f"기기 {bad}곳에서 빠진 종이 있다")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
