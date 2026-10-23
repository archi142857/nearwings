#!/usr/bin/env python3
"""소리 확인: 게임을 무비 메이커(--write-movie)로 돌려 실제로 섞여 나온 소리를 잰다.

공원 음악(시간대 섞기 시험 줄기, --sound=1)을 낮 12시에 틀고, 가방을 닫았을 때와 다 열었을 때 6초씩 녹음해
- 닫았을 때 음량이 바탕 + 낮 줄기 섞음 정도인지(RMS −27~−17dBFS, 피크 −1dBFS 아래: Master 리미터),
- 열었을 때 World 버스가 먹먹해지는지(2kHz 위 에너지가 줄고, 음량이 4dB 넘게 작아짐)를 본다.
처음 1.5초는 켤 때 커지는 구간이라 2초부터 잰다.

사용법: python3 tools/audio_check.py
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parent.parent


def godot_path():
    tools = os.environ.get("NEARWINGS_TOOLS") or ("/home/claude/tools" if Path("/home/claude").is_dir() else str(Path.home() / "nearwings-tools"))
    return os.environ.get("GODOT") or f"{tools}/godot/Godot_v4.7.2-stable_linux.x86_64"


def record(out_dir: Path, bag: str) -> Path:
    out = out_dir / bag / "f.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["xvfb-run", "-a", "-s", "-screen 0 1200x1400x24", godot_path(), "--path", str(ROOT / "game"),
           "--rendering-driver", "opengl3", "--resolution", "270x600", "--write-movie", str(out),
           "--fixed-fps", "30", "--quit-after", "180", "--",
           "--density=0.65", "--seed=7", "--hour=12", "--sound=1", "--nosplash", f"--bag={bag}"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    errors = [l for l in (r.stdout + r.stderr).splitlines()
              if ("ERROR" in l or "SCRIPT ERROR" in l) and "resources still in use at exit" not in l and "ALSA" not in l]
    if errors:
        raise SystemExit("엔진 오류: " + errors[0])
    return out.with_suffix(".wav")


def measure(path: Path):
    sr, x = wavfile.read(path)
    x = x.astype(np.float64)
    if np.abs(x).max() > 2.0:
        x /= 2147483648.0
    seg = x[int(2.0 * sr):]
    rms = 20 * np.log10(np.sqrt((seg ** 2).mean()) + 1e-12)
    peak = 20 * np.log10(np.abs(seg).max() + 1e-12)
    m = seg.mean(axis=1)
    f = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    freqs = np.fft.rfftfreq(len(m), 1 / sr)
    hi = f[freqs > 2000].sum() / max(f.sum(), 1e-30)
    return rms, peak, hi


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        closed = measure(record(tmp, "0"))
        opened = measure(record(tmp, "1"))
    print(f"가방 닫음: RMS {closed[0]:.1f}dBFS, 피크 {closed[1]:.1f}dBFS, 2kHz 위 {closed[2] * 100:.3f}%")
    print(f"가방 엶:   RMS {opened[0]:.1f}dBFS, 피크 {opened[1]:.1f}dBFS, 2kHz 위 {opened[2] * 100:.3f}%")
    ok = (-27.0 <= closed[0] <= -17.0 and closed[1] <= -1.0
          and opened[0] <= closed[0] - 4.0 and opened[2] < closed[2] * 0.5)
    print(("ok " if ok else "!! ") + "소리 확인: 공원 음악이 섞여 나오고, 가방을 열면 먹먹해진다")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
