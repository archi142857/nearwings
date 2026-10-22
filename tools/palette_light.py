# '아주 옅게' 재질별 색표 (디자인 캔버스 Pg_Tint, 2026-10-19). 밝은 칸 -> 어두운 칸 7단계.
MATERIALS = [
    ("beige",   "베이지 (기준)",   ["f6f0e3","efe6d2","e2d5ba","d2c19f","bca985","a08d6c","6f6250"]),
    ("sky",     "하늘",           ["ebf2f6","dfe8ef","ccd8e2","b6c5d1","9eaebb","84929e","5d656d"]),
    ("sun",     "해 · 구름",       ["f4f0e4","ede7d4","dfd6bc","cdc3a2","b7ab88","9a8f6f","6a6451"]),
    ("far",     "먼 산 · 빌딩",    ["ebf1f8","dfe8f2","ccd8e6","b6c4d6","9fadc0","8491a3","5e656f"]),
    ("tree",    "나무",           ["f0f2e4","e5ead4","d1dbbe","b9caa6","9eb48f","809878","596958"]),
    ("grass",   "풀 · 잔디",       ["f2f1e4","e8e8d4","d7d9bd","c1c7a4","a7b18c","8a9574","5f6855"]),
    ("paddy",   "추수한 논",       ["f9efe0","f3e5cd","e6d4b3","d5c196","bcaa7b","9e8f63","6b644b"]),
    ("water",   "물",             ["e8f3f5","daeaee","c5dbe0","adc8d1","95b1bb","7b949f","59676d"]),
    ("sand",    "모래",           ["f6f0e1","f0e6d0","e3d5b7","d5c09b","c0a881","a48b68","71614e"]),
    ("mudflat", "갯벌",           ["f4f0e8","ede6db","dfd5c6","cfc1af","b9a996","9d8d7c","6c6259"]),
    ("reed",    "갈대",           ["fbeee1","f5e4cf","e8d3b5","d7bf98","bfa97d","9f8e64","6c644b"]),
    ("trunk",   "나무 기둥 · 가지", ["f6f0e2","f0e6d1","e5d4b9","d7bf9e","c2a685","a68a6d","726051"]),
]
def hex2rgb(h):
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def lookup():
    t = {}
    for mi, (_, _, cols) in enumerate(MATERIALS):
        for li, h in enumerate(cols):
            t.setdefault(hex2rgb(h), []).append((li, mi))
    return t
