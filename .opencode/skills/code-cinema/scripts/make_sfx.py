"""Generate the starter kit's procedural sound effects (stdlib only)."""

from __future__ import annotations

import argparse
import math
import random
import wave
from array import array
from pathlib import Path

from cc_common import PipelineError, ensure_dir, log

SR = 48000


def _n(duration: float) -> int:
    return max(1, int(round(duration * SR)))


def _blank(duration: float) -> tuple[list[float], list[float]]:
    n = _n(duration)
    return [0.0] * n, [0.0] * n


def _pan(p: float) -> tuple[float, float]:
    p = max(-1.0, min(1.0, p))
    angle = (p + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def _put(buf: list[float], index: int, value: float) -> None:
    if 0 <= index < len(buf):
        buf[index] += value


def _reverb(left: list[float], right: list[float], mix: float = 0.18) -> None:
    taps = ((0.029, 0.5), (0.041, 0.32), (0.067, 0.22), (0.103, 0.12))
    src_l = left[:]
    src_r = right[:]
    for delay, gain in taps:
        offset = int(delay * SR)
        for i in range(offset, len(left)):
            left[i] += src_l[i - offset] * gain * mix
            right[i] += src_r[i - offset] * gain * mix


def _fade_edges(left: list[float], right: list[float], fade_in: float, fade_out: float) -> None:
    n = len(left)
    a = min(n, int(fade_in * SR))
    b = min(n, int(fade_out * SR))
    for i in range(a):
        g = i / max(1, a)
        left[i] *= g
        right[i] *= g
    for i in range(b):
        g = i / max(1, b)
        left[n - 1 - i] *= g
        right[n - 1 - i] *= g


def _normalize(left: list[float], right: list[float], peak: float = 0.89) -> None:
    top = 1e-9
    for l, r in zip(left, right):
        top = max(top, abs(l), abs(r))
    scale = peak / top
    for i in range(len(left)):
        left[i] *= scale
        right[i] *= scale


def write_wav(path: Path, left: list[float], right: list[float]) -> None:
    _normalize(left, right)
    data = array("h")
    for l, r in zip(left, right):
        data.append(int(max(-1.0, min(1.0, l)) * 32767))
        data.append(int(max(-1.0, min(1.0, r)) * 32767))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(data.tobytes())


def make_knock(duration: float = 1.55) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng = random.Random(11)
    times = (0.03, 0.32, 0.67)
    for index, start in enumerate(times):
        amp = 1.0 if index < 2 else 0.82
        length = _n(0.24)
        for i in range(length):
            t = i / SR
            env = math.exp(-t * 26.0)
            freq = 62.0 + 70.0 * math.exp(-t * 22.0)
            body = math.sin(2.0 * math.pi * freq * t) * env
            body += 0.45 * math.sin(2.0 * math.pi * 173.0 * t) * math.exp(-t * 34.0)
            click = rng.uniform(-1.0, 1.0) * math.exp(-t * 110.0) * 0.35
            sample = (body * 0.85 + click) * amp
            base = int(start * SR)
            _put(left, base + i, sample)
            _put(right, base + i, sample)
    _reverb(left, right, 0.26)
    _fade_edges(left, right, 0.002, 0.08)
    return left, right


def make_thud(duration: float = 1.2) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng = random.Random(23)
    low = 0.0
    for i in range(_n(duration)):
        t = i / SR
        env = math.exp(-t * 9.0)
        freq = 34.0 + 38.0 * math.exp(-t * 13.0)
        sub = math.sin(2.0 * math.pi * freq * t) * env
        low += 0.08 * (rng.uniform(-1.0, 1.0) - low)
        rumble = low * math.exp(-t * 5.5) * 0.9
        sample = sub * 0.95 + rumble
        left[i] += sample
        right[i] += sample
    _reverb(left, right, 0.3)
    _fade_edges(left, right, 0.002, 0.12)
    return left, right


def make_heartbeat(duration: float = 6.2) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    period = 60.0 / 46.0
    rng = random.Random(31)
    beat = 0.12
    while beat < duration - 0.4:
        for offset, amp in ((0.0, 1.0), (0.19, 0.62)):
            start = beat + offset
            length = _n(0.34)
            for i in range(length):
                t = i / SR
                env = math.exp(-t * 20.0)
                freq = 31.0 + 28.0 * math.exp(-t * 18.0)
                sample = math.sin(2.0 * math.pi * freq * t) * env * amp
                sample += rng.uniform(-1.0, 1.0) * math.exp(-t * 120.0) * 0.05 * amp
                base = int(start * SR) + i
                _put(left, base, sample * 0.95)
                _put(right, base, sample * 0.95)
        beat += period
    _reverb(left, right, 0.22)
    _fade_edges(left, right, 0.05, 0.3)
    return left, right


def make_wind(duration: float = 10.0) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng_l = random.Random(41)
    rng_r = random.Random(42)
    lp_l = 0.0
    lp_r = 0.0
    brown_l = 0.0
    brown_r = 0.0
    for i in range(_n(duration)):
        t = i / SR
        gust = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(2.0 * math.pi * 0.11 * t + 0.4))
        gust *= 0.75 + 0.25 * math.sin(2.0 * math.pi * 0.037 * t + 1.7)
        n_l = rng_l.uniform(-1.0, 1.0)
        n_r = rng_r.uniform(-1.0, 1.0)
        lp_l += 0.035 * (n_l - lp_l)
        lp_r += 0.035 * (n_r - lp_r)
        brown_l = brown_l * 0.997 + n_l * 0.06
        brown_r = brown_r * 0.997 + n_r * 0.06
        whistle = math.sin(2.0 * math.pi * (520.0 + 90.0 * math.sin(2.0 * math.pi * 0.07 * t)) * t)
        whistle *= 0.05 * (0.5 + 0.5 * math.sin(2.0 * math.pi * 0.19 * t + 0.9))
        sample_l = (lp_l * 1.6 + brown_l * 0.8 + whistle) * gust
        sample_r = (lp_r * 1.6 + brown_r * 0.8 + whistle * 0.8) * gust
        left[i] += sample_l
        right[i] += sample_r
    _fade_edges(left, right, 1.2, 1.6)
    _normalize(left, right, 0.55)
    return left, right


def make_stinger(duration: float = 2.8) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng = random.Random(53)
    root = 55.0
    cluster = (1.0, 1.335, 1.587, 2.0, 2.118, 2.997)
    for index, ratio in enumerate(cluster):
        freq = root * ratio * (1.0 + 0.002 * (index - 2))
        phase = rng.random() * math.tau
        for i in range(_n(duration)):
            t = i / SR
            attack = min(1.0, t / 0.012)
            env = attack * math.exp(-t * 1.35)
            wobble = 1.0 + 0.006 * math.sin(2.0 * math.pi * 5.2 * t + index)
            sample = math.sin(2.0 * math.pi * freq * wobble * t + phase) * env
            sample += 0.35 * math.sin(4.0 * math.pi * freq * t + phase) * env
            sample *= 0.16
            left[i] += sample * (0.75 if index % 2 else 1.0)
            right[i] += sample * (1.0 if index % 2 else 0.75)
    for i in range(_n(1.4)):
        t = i / SR
        env = math.exp(-t * 6.0)
        low = math.sin(2.0 * math.pi * (28.0 + 22.0 * math.exp(-t * 8.0)) * t) * env * 0.8
        left[i] += low
        right[i] += low
    for i in range(_n(0.5)):
        t = i / SR
        noise = rng.uniform(-1.0, 1.0) * math.exp(-t * 16.0) * 0.25
        left[i] += noise
        right[i] += noise
    _reverb(left, right, 0.5)
    _fade_edges(left, right, 0.01, 0.35)
    return left, right


def make_door_creak(duration: float = 2.4) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng = random.Random(67)
    phase = 0.0
    lp = 0.0
    for i in range(_n(1.55)):
        t = i / SR
        env = math.sin(min(1.0, t / 0.12) * math.pi / 2.0) * math.exp(-max(0.0, t - 0.9) * 4.0)
        freq = 128.0 + 55.0 * math.sin(2.0 * math.pi * 2.7 * t) - 38.0 * t
        phase += math.tau * max(30.0, freq) / SR
        saw = 2.0 * (phase / math.tau - math.floor(phase / math.tau + 0.5))
        friction = rng.uniform(-1.0, 1.0)
        lp += 0.22 * (friction - lp)
        creak = (saw * 0.22 + lp * 0.5) * env
        creak *= 0.7 + 0.3 * math.sin(2.0 * math.pi * 19.0 * t)
        left[i] += creak
        right[i] += creak
    for start, amp in ((1.18, 0.9), (1.62, 0.6)):
        length = _n(0.3)
        for i in range(length):
            t = i / SR
            env = math.exp(-t * 24.0)
            freq = 48.0 + 34.0 * math.exp(-t * 16.0)
            sample = math.sin(2.0 * math.pi * freq * t) * env * amp
            sample += rng.uniform(-1.0, 1.0) * math.exp(-t * 100.0) * 0.12 * amp
            base = int(start * SR) + i
            _put(left, base, sample)
            _put(right, base, sample)
    _reverb(left, right, 0.28)
    _fade_edges(left, right, 0.01, 0.25)
    return left, right


def make_tension_loop(duration: float = 12.0) -> tuple[list[float], list[float]]:
    left, right = _blank(duration)
    rng = random.Random(79)
    drone = (55.0, 82.5, 110.0, 65.41 * 2.0)
    phases = [rng.random() * math.tau for _ in drone]
    lp = 0.0
    for i in range(_n(duration)):
        t = i / SR
        pulse = 0.65 + 0.35 * (0.5 + 0.5 * math.sin(2.0 * math.pi * 0.75 * t))
        sample_l = 0.0
        sample_r = 0.0
        for index, freq in enumerate(drone):
            detune = 1.0 + 0.0015 * math.sin(2.0 * math.pi * (0.11 + 0.03 * index) * t + phases[index])
            value = math.sin(2.0 * math.pi * freq * detune * t + phases[index])
            value += 0.3 * math.sin(4.0 * math.pi * freq * detune * t + phases[index])
            sample_l += value * (0.55 if index % 2 else 1.0)
            sample_r += value * (1.0 if index % 2 else 0.55)
        shimmer = math.sin(2.0 * math.pi * 660.0 * t) * (0.5 + 0.5 * math.sin(2.0 * math.pi * 0.19 * t))
        shimmer *= 0.035
        lp += 0.03 * (rng.uniform(-1.0, 1.0) - lp)
        bed = lp * 0.5
        left[i] += (sample_l * 0.055 + shimmer + bed) * pulse
        right[i] += (sample_r * 0.055 + shimmer * 0.8 + bed) * pulse
    _normalize(left, right, 0.5)
    return left, right


BUILDERS = {
    "knock": make_knock,
    "thud": make_thud,
    "heartbeat": make_heartbeat,
    "wind": make_wind,
    "stinger": make_stinger,
    "door_creak": make_door_creak,
    "tension_loop": make_tension_loop,
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate starter SFX for Code Cinema.")
    parser.add_argument("--out", required=True, help="Output directory (e.g. studio/kit/audio).")
    parser.add_argument("--force", action="store_true", help="Overwrite existing WAV files.")
    parser.add_argument("--only", default="", help="Comma-separated subset of sound names.")
    args = parser.parse_args()

    out_dir = ensure_dir(Path(args.out).resolve())
    names = [n.strip() for n in args.only.split(",") if n.strip()] or list(BUILDERS)
    unknown = [n for n in names if n not in BUILDERS]
    if unknown:
        raise PipelineError(f"Unknown sound(s): {', '.join(unknown)}")
    for name in names:
        path = out_dir / f"{name}.wav"
        if path.exists() and not args.force:
            log(f"skip {path.name}")
            continue
        log(f"generating {name}...")
        left, right = BUILDERS[name]()
        write_wav(path, left, right)
        log(f"  {path} ({path.stat().st_size / 1024:.0f} KB)")
    log(f"SFX ready in {out_dir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PipelineError as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(1) from exc
