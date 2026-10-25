#!/usr/bin/env python3
"""Central Code Cinema audio farm.

Generates the procedural child-cry variants, validates all SFX paths in the
audio manifest, and prints a concise setup report.

Usage:
  python cc_sfx.py --project D:/code-cinema/studio
  python cc_sfx.py --project D:/code-cinema/studio --only girl_cry.sobbing --force
"""

from __future__ import annotations

import argparse
import json
import math
import random
import wave
from array import array
from pathlib import Path

from cc_common import PipelineError, ensure_dir, fail, log

SR = 48000


def _n(seconds: float) -> int:
    return max(1, int(round(seconds * SR)))


def _safe_float(value, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize(left: list[float], right: list[float], peak: float = 0.88) -> None:
    top = 1e-9
    for value in left:
        top = max(top, abs(value))
    for value in right:
        top = max(top, abs(value))
    scale = peak / top
    for i in range(len(left)):
        left[i] *= scale
        right[i] *= scale


def _fade_edges(left: list[float], right: list[float], fade_in: float, fade_out: float) -> None:
    n = len(left)
    a = min(n, _n(fade_in))
    b = min(n, _n(fade_out))
    for i in range(a):
        gain = i / max(1, a)
        left[i] *= gain
        right[i] *= gain
    for i in range(b):
        gain = i / max(1, b)
        left[n - 1 - i] *= gain
        right[n - 1 - i] *= gain


def _lowpass_inplace(left: list[float], right: list[float], amount: float) -> None:
    amount = max(0.02, min(0.95, amount))
    yl = 0.0
    yr = 0.0
    for i in range(len(left)):
        yl += amount * (left[i] - yl)
        yr += amount * (right[i] - yr)
        left[i] = yl
        right[i] = yr


def _highpass_inplace(left: list[float], right: list[float], amount: float) -> None:
    amount = max(0.0001, min(0.99, amount))
    prev_l = 0.0
    prev_r = 0.0
    for i in range(len(left)):
        out_l = amount * (left[i] - prev_l)
        out_r = amount * (right[i] - prev_r)
        prev_l = left[i]
        prev_r = right[i]
        left[i] = out_l
        right[i] = out_r


def _room(left: list[float], right: list[float], amount: float) -> None:
    if amount <= 0.0:
        return
    source_l = left[:]
    source_r = right[:]
    taps = ((0.017, 0.32), (0.031, 0.24), (0.053, 0.18), (0.079, 0.12), (0.113, 0.08))
    for delay, gain in taps:
        offset = _n(delay)
        for i in range(offset, len(left)):
            left[i] += source_l[i - offset] * gain * amount
            right[i] += source_r[i - offset] * gain * amount


def _write_wav(path: Path, left: list[float], right: list[float]) -> None:
    _normalize(left, right)
    frames = array("h")
    for l_value, r_value in zip(left, right):
        frames.append(int(max(-1.0, min(1.0, l_value)) * 32000))
        frames.append(int(max(-1.0, min(1.0, r_value)) * 32000))
    ensure_dir(path.parent)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(frames.tobytes())


def _child_cry(seed: int, duration: float, *, dry: float, room_amount: float, bandwidth: float) -> tuple[list[float], list[float]]:
    """Deterministic child-sobbing synth: wavering voice, breath, small stereo room."""
    rng = random.Random(seed)
    total = _n(duration)
    left = [0.0] * total
    right = [0.0] * total

    phrases = [
        (0.18, 1.25, 486), (1.55, 1.05, 430), (2.72, 1.35, 522),
        (4.18, 0.85, 402), (5.12, 1.12, 456),
    ]

    def synth_phrase(start_at: float, length: float, base_pitch: float, gain: float, pan: float) -> None:
        start = _n(start_at)
        count = _n(length)
        phase = rng.random() * math.tau
        breath_state = 0.0
        for i in range(count):
            if start + i >= total:
                break
            t = i / SR
            progress = t / max(0.08, length)
            onset = min(1.0, t / 0.075) * min(1.0, max(0.0, (length - t) / 0.28))
            cry_wave = 0.52 + 0.48 * (0.5 + 0.5 * math.sin(math.tau * 4.7 * t + start_at))
            pitch = base_pitch * (1.0 + 0.075 * math.sin(math.tau * 5.4 * t + 0.5))
            pitch *= 1.0 - 0.08 * progress
            phase += math.tau * pitch / SR
            wobble = 1.0 + 0.014 * math.sin(math.tau * 11.0 * t)
            voice = (
                math.sin(phase * wobble)
                + 0.52 * math.sin(phase * 2.0 * wobble)
                + 0.24 * math.sin(phase * 3.0 * wobble)
                + 0.10 * math.sin(phase * 4.0 * wobble)
            )
            breath = rng.uniform(-1.0, 1.0)
            breath_state += 0.18 * (breath - breath_state)
            sig = (voice * 0.62 + breath_state * 0.28) * onset * cry_wave * gain
            l_gain = 1.0 if pan < 0 else math.cos(pan * math.pi / 2)
            r_gain = 1.0 if pan > 0 else math.sin(abs(pan) * math.pi / 2)
            left[start + i] += sig * l_gain
            right[start + i] += sig * r_gain

    for index, (start_at, length, pitch) in enumerate(phrases):
        amp = 0.9 if index % 2 == 0 else 0.76
        pan = ((index % 3) - 1) * 0.22
        synth_phrase(start_at, length, pitch, amp, pan)

    # Gasping/sobbing between the main wails.
    for at, amp in ((1.38, 0.2), (2.58, 0.18), (4.04, 0.16), (6.02, 0.14)):
        breath_start = _n(at)
        length = _n(0.34)
        for burst in range(3):
            start = breath_start + _n(0.06 * burst)
            for i in range(_n(0.05)):
                if start + i >= total:
                    break
                env = math.exp(-i / SR * 26.0)
                left[start + i] += rng.uniform(-1.0, 1.0) * env * amp
                right[start + i] += rng.uniform(-1.0, 1.0) * env * amp * 0.92

    _lowpass_inplace(left, right, bandwidth)
    _highpass_inplace(left, right, 0.004)
    _room(left, right, room_amount)
    # Dry/wet balance and very light highpass to remove DC and room mud.
    for i in range(len(left)):
        left[i] *= dry
        right[i] *= dry
    _highpass_inplace(left, right, 0.0008)
    _fade_edges(left, right, 0.045, 0.22)
    return left, right


GENERATORS = {
    "girl_cry.sobbing": lambda: _child_cry(731, 7.1, dry=0.92, room_amount=0.35, bandwidth=0.42),
    "girl_cry.muffled": lambda: _child_cry(179, 7.1, dry=0.78, room_amount=0.68, bandwidth=0.16),
    "girl_cry.distant": lambda: _child_cry(409, 7.1, dry=0.55, room_amount=1.0, bandwidth=0.10),
}


def project_audio_dir(project: Path) -> Path:
    return project / "code_cinema" / "kit" / "audio"


def load_manifest(project: Path) -> dict:
    path = project / "code_cinema" / "audio_manifest.json"
    if not path.exists():
        fail(f"Audio manifest missing: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        fail(f"Audio manifest must be an object: {path}")
    return data


def process(project: Path, only: list[str], force: bool) -> int:
    manifest = load_manifest(project)
    audio_dir = project_audio_dir(project)
    ensure_dir(audio_dir)
    sounds = manifest.get("sounds", {})
    if not isinstance(sounds, dict):
        fail("audio_manifest.json sounds must be an object.")

    names = list(only) or sorted(sounds.keys())
    unknown = [name for name in names if name not in sounds]
    if unknown:
        raise PipelineError(f"Unknown audio manifest sound(s): {', '.join(unknown)}")

    print(f"Audio farm: {audio_dir}")
    missing: list[str] = []
    generated = 0
    reused = 0
    for name in names:
        entry = sounds.get(name, {})
        if not isinstance(entry, dict):
            raise PipelineError(f"Sound '{name}' must be an object.")
        relative = str(entry.get("path", ""))
        if not relative:
            raise PipelineError(f"Sound '{name}' has no path.")
        target = project / relative if not str(relative).startswith("/") else Path(relative)
        generator = entry.get("generator")
        if generator:
            if generator not in GENERATORS:
                raise PipelineError(f"Sound '{name}' uses unknown generator '{generator}'.")
            if force or not target.exists():
                left, right = GENERATORS[generator]()
                _write_wav(target, left, right)
                generated += 1
                print(f"  generated {name}: {target.name} ({target.stat().st_size / 1024:.0f} KB)")
            else:
                reused += 1
                print(f"  exists    {name}: {target.name}")
        else:
            if target.exists():
                reused += 1
                print(f"  exists    {name}: {target.name}")
            else:
                missing.append(name)
                print(f"  MISSING   {name}: {target}")

    voices_path = project / str(manifest.get("voices_file", "code_cinema/voices.json"))
    if voices_path.exists():
        voices = json.loads(voices_path.read_text(encoding="utf-8"))
        roles = voices.get("roles", {})
        print(f"Voices: {len(roles)} role(s) -> {voices_path.name}")
    else:
        missing.append("voices.json")
        print(f"  MISSING   voices.json: {voices_path}")

    print("")
    print(f"Generated: {generated}")
    print(f"Existing: {reused}")
    print(f"Missing: {len(missing)}")
    if missing:
        raise PipelineError("Audio farm validation failed: " + ", ".join(missing))
    print("Audio farm OK.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate and validate the Code Cinema audio farm.")
    parser.add_argument("--project", required=True, help="Godot studio directory.")
    parser.add_argument("--only", default="", help="Comma-separated sound keys.")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)

    project = Path(args.project).expanduser().resolve()
    if not (project / "project.godot").exists():
        parser.error(f"Not a Godot project: {project}")
    only = [x.strip() for x in args.only.split(",") if x.strip()]
    return process(project, only, args.force)


if __name__ == "__main__":
    raise SystemExit(main())
