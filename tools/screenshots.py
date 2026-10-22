#!/usr/bin/env python3
"""기기 크기별 화면 캡처. 가상 화면(xvfb)에서 Godot를 소프트웨어 OpenGL로 띄워 찍는다.

결과: build/shots/<기기>.png 와 한눈에 보는 build/shots/sheet.png
사용법: python3 tools/screenshots.py [기기 이름 ...] [-- 게임 인자 ...]
"""
import math
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "shots"

# 이름, 너비, 높이, 1dp 화소 수
DEVICES = [
    ("phone_1080x2400", 1080, 2400, 2.625),   # 갤럭시 A·S FHD+ (기준 폰: 한 칸 5화소)
    ("phone_1080x2340", 1080, 2340, 2.625),   # 갤럭시 S 19.5:9 (한 칸 4.88화소)
    ("iphone_1179x2556", 1179, 2556, 3.0),    # 아이폰 (한 칸 5.33화소)
    ("flip_1080x2640", 1080, 2640, 2.625),    # 갤럭시 Z 플립 (22:9)
    ("fold_2160x2400", 2160, 2400, 2.625),    # 폴더블 펼침 세로
    ("fold_2400x2160", 2400, 2160, 2.625),    # 폴더블 펼침 가로
    ("tablet_1600x2560", 1600, 2560, 2.0),    # 태블릿 세로
    ("tablet_2560x1600", 2560, 1600, 2.0),    # 태블릿 가로
    ("split_1080x1150", 1080, 1150, 2.625),   # 창 나누기 (화면 절반)
]


# 장면 말고 다른 화면도 찍어 본다: 이름, 기기, 게임 인자
FOUND = "--found=pica_serica,parus_minor,anas_platyrhynchos,ardea_cinerea,passer_montanus"
VARIANTS = [
    ("dex_phone", "phone_1080x2400", ["--dex", FOUND, "--save=user://shot_save.json"]),
    ("dex_fold_land", "fold_2400x2160", ["--dex", FOUND, "--save=user://shot_save.json"]),
    ("detail_phone", "phone_1080x2400", ["--dex", "--detail=pica_serica", FOUND, "--save=user://shot_save.json"]),
    # 카메라를 든 화면 (뷰파인더·셔터), 찍은 뒤 알림
    ("camera_phone", "phone_1080x2400", ["--tool=camera"]),
    ("shoot_phone", "phone_1080x2400", ["--tool=camera", "--shoot", "--fresh", "--save=user://shot_save.json"]),
    # 가방 메뉴: 반쯤 연 것, 다 연 것 (폰은 시안과 화소까지 같아야 한다), 넓은 화면은 도구가 한 줄
    ("bag_half_phone", "phone_1080x2400", ["--bag=0.5"]),
    ("bag_phone", "phone_1080x2400", ["--bag=1"]),
    ("bag_fold", "fold_2160x2400", ["--bag=1"]),
    ("bag_fold_land", "fold_2400x2160", ["--bag=1"]),
    ("bag_tablet", "tablet_1600x2560", ["--bag=1"]),
    ("bag_tablet_land", "tablet_2560x1600", ["--bag=1"]),
    ("bag_night_phone", "phone_1080x2400", ["--bag=1", "--hour=23"]),
    # 시간대: 기본 캡처는 정오(--hour=12)에 멈춰 찍고, 새벽·해 질 녘·밤은 따로 찍는다
    ("dawn_phone", "phone_1080x2400", ["--hour=5.75"]),
    ("dusk_phone", "phone_1080x2400", ["--hour=18.5"]),
    ("night_phone", "phone_1080x2400", ["--hour=23"]),
    ("night_tablet_land", "tablet_2560x1600", ["--hour=23"]),
]


def godot_path():
    tools = os.environ.get("NEARWINGS_TOOLS") or ("/home/claude/tools" if Path("/home/claude").is_dir() else str(Path.home() / "nearwings-tools"))
    return os.environ.get("GODOT") or f"{tools}/godot/Godot_v4.7.2-stable_linux.x86_64"


def capture(name, w, h, dens, extra, scene_args=("--prewarm", "--hour=12")):
    out = OUT / f"{name}.png"
    if out.exists():
        out.unlink()
    cmd = ["xvfb-run", "-a", "-s", "-screen 0 3200x3200x24", godot_path(), "--path", str(ROOT / "game"),
           "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", f"{w}x{h}", "--position", "0,0", "--",
           f"--capture={out}", f"--density={dens}", "--seed=7", "--frames=40", *scene_args, *extra]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    errors = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "SCRIPT ERROR" in l) and "ALSA" not in l and "audio" not in l.lower()]
    ok = out.exists() and Image.open(out).size == (w, h)
    return ok, errors


HABITAT = ROOT / "game/assets/habitats/urban_river_park"
SET_LABEL = {"portrait": "세로형", "square": "정사각형", "landscape": "가로형"}


def scene_for(w, h):
    """게임과 같은 규칙으로 고른 배경 벌과 그 장면 크기 (layout.gd choose_set)."""
    sizes = {s: Image.open(HABITAT / s / "index.png").size for s in SET_LABEL if (HABITAT / s / "index.png").exists()}
    name = min(sizes, key=lambda s: abs(math.log((w / h) / (sizes[s][0] / sizes[s][1]))))
    return name, sizes[name]


def color_check():
    """기준 폰(한 칸 5화소, 세로형 240칸 가운데 216칸이 보임) 캡처의 배경 색이 구운 그림과 같은지 본다.
    색 공간 실수(어둡게·진하게 나오는 것)를 잡으려는 검사다. 새가 가린 점이 있을 수 있어 12점 중 9점 이상이면 통과."""
    shot = Image.open(OUT / "phone_1080x2400.png").convert("RGB")
    name, scene = scene_for(1080, 2400)
    ref = Image.open(HABITAT / name / "baked_day.png").convert("RGB")
    px = max(1080 / scene[0], 2400 / scene[1])
    off = (round((scene[0] - 1080 / px) / 2), round((scene[1] - 2400 / px) / 2))   # 양쪽을 똑같이 자른 만큼
    # 화면 요소(위 FPS·설정, 가운데 뷰파인더, 아래 안내·셔터)를 피한 배경 점들
    cells = [(150, 70), (200, 100), (195, 160), (30, 190), (150, 255), (200, 255),
             (60, 280), (110, 300), (200, 310), (40, 345), (150, 350), (200, 375)]
    good = 0
    for cx, cy in cells:
        a = shot.getpixel((cx * 5 + 2, cy * 5 + 2))
        b = ref.getpixel((cx + off[0], cy + off[1]))
        good += max(abs(a[i] - b[i]) for i in range(3)) <= 3
    need = len(cells) - 3   # 새가 가린 점이 몇 개 있을 수 있다
    print(f"{'ok ' if good >= need else '!! '} 배경 색 확인: {good}/{len(cells)}점이 구운 그림과 같다")
    return good >= need


def bag_check():
    """폰에서 다 연 가방이 디자인 시안(캔버스 '도감 그림 칸'의 가방 속 화면, art/bag/canvas_bag_screen.png)과
    화소까지 같은지 본다. 바닥은 시안과 다르게 그렸고 도감 그림은 키트 예시 대신 다른 그림을 넣었으니,
    가방 자리(위에서 1160화소부터)에서 도감 자리만 빼고 견준다."""
    shot = Image.open(OUT / "bag_phone.png").convert("RGB")
    ref = Image.open(ROOT / "art/bag/canvas_bag_screen.png").convert("RGB")
    bad = 0
    for y in range(1160, 2400):
        for x in range(25, 1055):
            if 150 <= x < 440 and 1495 <= y < 1955:   # 도감 그림·그림자·이름표
                continue
            p, q = shot.getpixel((x, y)), ref.getpixel((x, y))
            bad += max(abs(p[i] - q[i]) for i in range(3)) > 2
    ok = bad == 0
    print(f"{'ok ' if ok else '!! '} 가방 확인: 폰에서 연 가방이 시안과 {'같다' if ok else f'{bad}화소 다르다'} (도감 자리 빼고)")
    return ok


def sprite_color_check():
    """도감 상세(까치를 크게 그린 화면)에 까치 그림의 색이 그대로 다 나오는지 본다.
    셰이더에서 그림 색을 두 번 곱하는 실수(어두워짐)를 잡으려는 검사다."""
    shot = Image.open(OUT / "detail_phone.png").convert("RGB")
    have = set(shot.get_flattened_data())
    sprite = Image.open(ROOT / "game/assets/birds/pica_serica.png").convert("RGBA")
    want = {p[:3] for p in sprite.get_flattened_data() if p[3] == 255}
    missing = [c for c in want if c not in have]
    ok = not missing
    print(f"{'ok ' if ok else '!! '} 새 그림 색 확인: 까치 색 {len(want) - len(missing)}/{len(want)}개가 그대로 나온다")
    return ok


def sheet(names, labels=None):
    ims = [(n, Image.open(OUT / f"{n}.png").convert("RGB")) for n in names if (OUT / f"{n}.png").exists()]
    H = 640
    thumbs = [(n, im.resize((max(1, round(im.width * H / im.height)), H), Image.LANCZOS)) for n, im in ims]
    W = sum(t.width for _, t in thumbs) + 20 * (len(thumbs) + 1)
    S = Image.new("RGB", (W, H + 60), (46, 41, 34))
    d = ImageDraw.Draw(S)
    font = ImageFont.truetype(str(ROOT / "game/assets/fonts/Galmuri11-ksx1001.ttf"), 15)   # 한글 이름이 보이게
    x = 20
    for n, t in thumbs:
        S.paste(t, (x, 20))
        d.text((x, H + 22), (labels or {}).get(n, n), fill=(246, 241, 230), font=font)
        x += t.width + 20
    S.save(OUT / "sheet.png")


def main():
    args = sys.argv[1:]
    extra = []
    if "--" in args:
        i = args.index("--")
        args, extra = args[:i], args[i + 1:]
    OUT.mkdir(parents=True, exist_ok=True)
    chosen = [d for d in DEVICES if not args or d[0] in args]
    failed = 0
    for name, w, h, dens in chosen:
        ok, errors = capture(name, w, h, dens, extra)
        print(f"{'ok ' if ok and not errors else '!! '} {name} {w}x{h} @{dens}" + (f"  오류 {len(errors)}건: {errors[0]}" if errors else ""))
        failed += (not ok) or bool(errors)
    names = [d[0] for d in chosen]
    if not args:
        size = {d[0]: d[1:] for d in DEVICES}
        for name, dev, vargs in VARIANTS:
            w, h, dens = size[dev]
            hour = [] if any(a.startswith("--hour=") for a in vargs) else ["--hour=12"]
            ok, errors = capture(name, w, h, dens, extra, ("--prewarm", *hour, *vargs))
            print(f"{'ok ' if ok and not errors else '!! '} {name} ({dev})" + (f"  오류 {len(errors)}건: {errors[0]}" if errors else ""))
            failed += (not ok) or bool(errors)
            names.append(name)
    if not extra and any(d[0] == "phone_1080x2400" for d in chosen):
        failed += not color_check()
    if not args and not extra:
        failed += not sprite_color_check()
        failed += not bag_check()
    size = {d[0]: d[1:3] for d in DEVICES}
    dev_of = {v[0]: v[1] for v in VARIANTS}
    labels = {}
    for n in names:
        w, h = size[dev_of.get(n, n)]
        labels[n] = f"{n} · {SET_LABEL[scene_for(w, h)[0]]}"
    sheet(names, labels)
    print(f"화면 캡처: {OUT}/sheet.png")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
