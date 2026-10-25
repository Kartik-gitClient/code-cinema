"""Audio assembly, muxing, posters, subtitles and transcripts."""

from __future__ import annotations

from pathlib import Path

from cc_common import (
    PipelineError,
    ensure_dir,
    fail,
    fmt_clock,
    fmt_srt,
    log,
    media_info,
    run,
)


def _cue_list(resolved: dict) -> tuple[list[dict], list[dict]]:
    cues = resolved.get("cues", {})
    if not isinstance(cues, dict):
        return [], []
    dialogue = [c for c in cues.get("dialogue", []) if isinstance(c, dict)]
    sfx = [c for c in cues.get("sfx", []) if isinstance(c, dict)]
    return dialogue, sfx


def _music_cue(resolved: dict) -> dict | None:
    cues = resolved.get("cues", {})
    if not isinstance(cues, dict):
        return None
    music = cues.get("music", [])
    if isinstance(music, list) and music:
        return music[0]
    return None


def _retro_filters(kind: str = "vo") -> str:
    """Return a comma-suffixed retro/radio/vinyl filter chain."""
    if kind == "sfx":
        return (
            "highpass=f=55,"
            "lowpass=f=6500,"
            "equalizer=f=140:t=q:w=1:g=3,"
            "equalizer=f=4200:t=q:w=1:g=-4,"
            "acrusher=bits=15:mode=log:mix=0.06,"
            "aphaser=type=triangular:speed=0.3,"
            "aecho=in_gain=0.5:out_gain=0.4:delays=55|95:decays=0.09|0.06,"
        )
    if kind == "music":
        return (
            "highpass=f=45,"
            "lowpass=f=5500,"
            "equalizer=f=120:t=q:w=1:g=3,"
            "equalizer=f=4500:t=q:w=1:g=-6,"
            "acrusher=bits=15:mode=log:mix=0.05,"
            "aphaser=type=triangular:speed=0.25,"
            "aecho=in_gain=0.5:out_gain=0.4:delays=65:decays=0.07,"
        )
    return (
        "highpass=f=190,"
        "lowpass=f=3400,"
        "equalizer=f=120:t=q:w=1:g=4,"
        "equalizer=f=2600:t=q:w=1:g=-6,"
        "acrusher=bits=14:mode=log:mix=0.12,"
        "aphaser=type=triangular:speed=0.4,"
        "vibrato=f=5:d=0.11,"
        "aecho=in_gain=0.45:out_gain=0.35:delays=45|85:decays=0.12|0.08,"
    )


def audio_mp3(
    wav: Path,
    out_mp3: Path,
    ffmpeg: str,
    *,
    title: str = "",
    bitrate: str = "192k",
) -> Path:
    out_mp3 = ensure_dir(out_mp3.parent) / out_mp3.name
    cmd = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav)]
    if title:
        cmd += ["-metadata", f"title={title}"]
    cmd += ["-vn", "-c:a", "libmp3lame", "-b:a", bitrate, "-ar", "48000", "-ac", "2", str(out_mp3)]
    run(cmd)
    log(f"MP3: {out_mp3}")
    return out_mp3


def build_mix(
    resolved: dict,
    out_wav: Path,
    ffmpeg: str,
    *,
    loudness_lufs: float = -16.0,
) -> Path:
    total = float(resolved.get("duration", 0.0))
    if total <= 0.0:
        fail("Cannot mix audio: film duration is zero.")

    dialogue, sfx = _cue_list(resolved)
    music = _music_cue(resolved)
    audio_cfg = resolved.get("audio", {})
    if not isinstance(audio_cfg, dict):
        audio_cfg = {}
    retro_cfg = audio_cfg.get("retro", {})
    if not isinstance(retro_cfg, dict):
        retro_cfg = {}
    retro_vo = _retro_filters("vo") if bool(retro_cfg.get("vo", False)) else ""
    retro_sfx = _retro_filters("sfx") if bool(retro_cfg.get("sfx", False)) else ""
    retro_music = _retro_filters("music") if bool(retro_cfg.get("music", False)) else ""
    dialog_gain = max(0.0, float(audio_cfg.get("dialog_gain", 2.8)))
    sfx_gain = max(0.0, float(audio_cfg.get("sfx_gain", 0.4)))
    music_mix_gain = max(0.0, float(audio_cfg.get("music_gain", 0.5)))

    items: list[dict] = []
    for cue in dialogue:
        path = cue.get("path")
        if path:
            items.append(
                {
                    "path": path,
                    "start": max(0.0, float(cue.get("start", 0.0))),
                    "volume": float(cue.get("volume", 1.0)),
                    "kind": "vo",
                }
            )
    for cue in sfx:
        path = cue.get("path")
        if path:
            items.append(
                {
                    "path": path,
                    "start": max(0.0, float(cue.get("start", 0.0))),
                    "volume": float(cue.get("volume", 1.0)),
                    "kind": "sfx",
                }
            )

    out_wav = ensure_dir(out_wav.parent) / out_wav.name
    cmd: list[str] = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error"]
    cmd += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=r=48000:cl=stereo"]

    for item in items:
        if not Path(item["path"]).exists():
            fail(f"Audio cue file missing: {item['path']}")
        cmd += ["-i", str(item["path"])]

    music_index = None
    if music:
        track_path = music.get("path")
        if track_path and Path(track_path).exists():
            music_index = 1 + len(items)
            cmd += ["-stream_loop", "-1", "-i", str(track_path)]
        elif track_path:
            fail(f"Music track missing: {track_path}")

    if not items and music_index is None:
        cmd += ["-map", "0:a", "-t", f"{total:.3f}", "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", str(out_wav)]
        run(cmd)
        log(f"Audio (silent): {out_wav}")
        return out_wav

    lines: list[str] = []
    lines.append(f"[0:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS[base]")
    mix_inputs = ["[base]"]
    for i, item in enumerate(items, start=1):
        delay_ms = int(round(item["start"] * 1000.0))
        volume = max(0.0, item["volume"])
        if item["kind"] == "vo":
            volume *= dialog_gain
        else:
            volume *= sfx_gain
        chain = (
            f"[{i}:a]aresample=48000,"
            f"aformat=sample_fmts=fltp:channel_layouts=stereo,"
            f"volume={volume:.4f},"
            f"{retro_vo if item['kind'] == 'vo' else retro_sfx}"
            f"adelay={delay_ms}:all=1[a{i}]"
        )
        lines.append(chain)
        mix_inputs.append(f"[a{i}]")

    if music_index is not None:
        music_volume = float(music.get("volume", 0.18)) * music_mix_gain
        fade_out_start = max(0.0, total - 3.0)
        lines.append(
            f"[{music_index}:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,"
            f"aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,"
            f"volume={music_volume:.4f},"
            f"{retro_music}"
            f"afade=t=in:st=0:d=2.0,"
            f"afade=t=out:st={fade_out_start:.3f}:d=3.0[am]"
        )
        mix_inputs.append("[am]")

    mix = (
        "".join(mix_inputs)
        + f"amix=inputs={len(mix_inputs)}:normalize=0:duration=first:dropout_transition=0,"
        + f"loudnorm=I={loudness_lufs}:TP=-1.5:LRA=11,"
        + "alimiter=limit=0.95,aresample=48000[mix]"
    )
    lines.append(mix)

    filter_path = out_wav.parent / "mix.filter"
    filter_path.write_text(";\n".join(lines) + "\n", encoding="utf-8")
    cmd += ["-filter_complex_script", str(filter_path), "-map", "[mix]"]
    cmd += ["-t", f"{total:.3f}", "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", str(out_wav)]
    run(cmd)
    log(f"Audio mix: {out_wav}")
    return out_wav


def mux(
    video: Path,
    audio: Path,
    out_mp4: Path,
    ffmpeg: str,
    *,
    width: int = 0,
    height: int = 0,
    fps: float = 0.0,
    title: str = "",
    crf: int = 18,
    preset: str = "medium",
) -> Path:
    out_mp4 = ensure_dir(out_mp4.parent) / out_mp4.name
    cmd: list[str] = [
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(video), "-i", str(audio),
        "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "libx264", "-preset", preset, "-crf", str(crf),
        "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.2",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
        "-shortest", "-movflags", "+faststart",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
    ]
    filters = []
    if width > 0 and height > 0:
        filters.append(f"scale={int(width)}:{int(height)}:flags=lanczos")
    filters.append("setsar=1")
    cmd += ["-vf", ",".join(filters)]
    if fps > 0:
        cmd += ["-r", f"{fps:.6g}"]
    if title:
        cmd += ["-metadata", f"title={title}"]
    cmd += [str(out_mp4)]
    run(cmd)
    log(f"MP4: {out_mp4}")
    return out_mp4


def poster(video: Path, out_jpg: Path, ffmpeg: str, at: float = 1.0) -> Path:
    out_jpg = ensure_dir(out_jpg.parent) / out_jpg.name
    run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-ss", f"{max(0.0, at):.3f}", "-i", str(video),
        "-frames:v", "1", "-q:v", "2", str(out_jpg),
    ])
    return out_jpg


def extract_frames(video: Path, out_dir: Path, ffmpeg: str, times: list[float]) -> list[Path]:
    ensure_dir(out_dir)
    frames: list[Path] = []
    for index, at in enumerate(times, start=1):
        path = out_dir / f"frame_{index:02d}_{at:05.2f}s.jpg"
        run([
            ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
            "-ss", f"{max(0.0, at):.3f}", "-i", str(video),
            "-frames:v", "1", "-q:v", "3", str(path),
        ])
        frames.append(path)
    return frames


def write_srt(captions: list[dict], path: Path) -> Path:
    path = ensure_dir(path.parent) / path.name
    lines: list[str] = []
    index = 1
    for caption in captions:
        text = str(caption.get("text", "")).strip()
        if not text:
            continue
        start = float(caption.get("start", 0.0))
        end = float(caption.get("end", start + 2.0))
        if end <= start:
            end = start + 1.0
        lines.append(str(index))
        lines.append(f"{fmt_srt(start)} --> {fmt_srt(end)}")
        lines.append(text.replace("\n", " "))
        lines.append("")
        index += 1
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def write_transcript(resolved: dict, path: Path) -> Path:
    path = ensure_dir(path.parent) / path.name
    title = resolved.get("title", "Untitled")
    logline = resolved.get("logline", "")
    duration = float(resolved.get("duration", 0.0))
    lines: list[str] = [f"# {title}", ""]
    if logline:
        lines += [logline, ""]
    lines += [f"Runtime: {fmt_clock(duration)}", ""]
    opening = resolved.get("opening", {})
    if opening and float(opening.get("duration", 0.0)) > 0:
        lines += [f"[00:00] TITLE: {opening.get('title', '')}", ""]
    for shot in resolved.get("shots", []):
        start = float(shot.get("start", 0.0))
        lines.append(f"## {fmt_clock(start)} — {shot.get('id', 'shot')} @ {shot.get('location', '')}")
        camera = shot.get("camera", {})
        if camera:
            lines.append(
                f"Camera: {camera.get('move', 'static')} / {camera.get('anchor', '')}"
            )
        for line in shot.get("dialogue", []):
            if not isinstance(line, dict):
                continue
            at = float(shot.get("start", 0.0)) + float(line.get("start", 0.0))
            lines.append(f"- [{fmt_clock(at)}] {line.get('speaker', 'narrator')}: {line.get('text', '')}")
        if not shot.get("dialogue"):
            lines.append("- (no dialogue)")
        lines.append("")
    ending = resolved.get("ending", {})
    if ending:
        lines += [
            f"## {fmt_clock(float(ending.get('start', 0.0)))} — ENDING CARD",
            f"**{ending.get('question', '')}**",
            "Options: " + " / ".join(str(o) for o in ending.get("options", [])),
            "",
        ]
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def write_post(resolved: dict, path: Path) -> Path:
    path = ensure_dir(path.parent) / path.name
    title = resolved.get("title", "Untitled")
    logline = resolved.get("logline", "")
    ending = resolved.get("ending", {})
    question = ending.get("question", "")
    options = ending.get("options", ["YES", "NO"])
    tags = resolved.get("post", {}).get("hashtags", [])
    if not tags:
        tags = ["#horror", "#zombie", "#chooseyourownadventure", "#shortfilm", "#3danimation"]
    lines = [
        f"# {title}",
        "",
        "## Caption",
        logline,
        "",
        "## Vote",
        question,
        " / ".join(str(o) for o in options),
        "",
        "## Hashtags",
        " ".join(str(t) for t in tags),
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def film_audio_info(wav: Path, ffprobe: str) -> dict:
    return media_info(wav, ffprobe)
