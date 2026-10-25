#!/usr/bin/env python3
"""Code Cinema command line: init, validate, voice, render, mix, mux."""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
from pathlib import Path

from cc_audio import (
    audio_mp3,
    build_mix,
    extract_frames,
    mux as mux_media,
    poster as make_poster,
    write_post,
    write_srt,
    write_transcript,
)
from cc_common import (
    PipelineError,
    SKILL_ROOT,
    SCRIPTS_DIR,
    copy_template,
    detect_ffmpeg,
    detect_ffprobe,
    detect_godot,
    ensure_dir,
    fail,
    find_project,
    load_dotenv,
    load_json,
    log,
    media_info,
    res_path,
    resolve_format,
    resolve_screenplay,
    run,
    save_json,
    slugify,
    tail,
    warn,
)
from cc_kit import load_kit, print_validation, scan_kit, validate
from cc_timeline import estimate_vo_from_script, resolve_timeline, timeline_stats
from cc_tts import DEFAULT_MODEL, collect_lines, generate_all, load_vo


DEFAULT_STUDIO = SKILL_ROOT.parent.parent.parent / "studio"


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _project(args) -> Path:
    project = find_project(explicit=args.project)
    load_dotenv(project)
    return project


def _model(args, screenplay: dict) -> str:
    audio = screenplay.get("audio") if isinstance(screenplay.get("audio"), dict) else {}
    tts = audio.get("tts") if isinstance(audio.get("tts"), dict) else {}
    return args.model or str(tts.get("model") or DEFAULT_MODEL)


def _film(project: Path, film: str) -> tuple[dict, dict, str, Path]:
    name = film or "demo"
    candidate = Path(name).expanduser()
    if candidate.is_file():
        path = candidate.resolve()
    elif (project / "films" / name / "screenplay.json").exists():
        path = project / "films" / name / "screenplay.json"
    elif candidate.is_dir():
        path = candidate / "screenplay.json"
    elif candidate.suffix.lower() == ".json":
        path = resolve_screenplay(project, name)
    else:
        fail(
            f"Screenplay not found: {name}. Expected films/<name>/screenplay.json "
            "or a path to a .json file."
        )
    if not path.exists():
        fail(f"Screenplay not found: {path}")
    screenplay = load_json(path)
    slug = slugify(str(screenplay.get("slug") or path.parent.name))
    kit = load_kit(project)
    return screenplay, kit, slug, path


def _paths(project: Path, slug: str) -> tuple[Path, Path, Path]:
    build_dir = ensure_dir(project / "code_cinema" / "build" / slug)
    out_dir = ensure_dir(project / "out")
    resolved = build_dir / f"{slug}.resolved.json"
    return build_dir, out_dir, resolved


def _check(screenplay: dict, kit: dict) -> None:
    errors, warnings = validate(screenplay, kit, strict=False)
    print_validation(errors, warnings)
    if errors:
        raise PipelineError("Fix the screenplay errors above before rendering.")


def _ffprobe_or_none(project: Path, args, ffmpeg: str | None) -> str | None:
    try:
        return detect_ffprobe(project, args.ffprobe, ffmpeg)
    except PipelineError:
        return None


def _ensure_vo(
    project: Path,
    screenplay: dict,
    kit: dict,
    build_dir: Path,
    *,
    no_tts: bool,
    force: bool,
    api_key: str,
    model: str,
    ffprobe: str | None,
) -> dict:
    if no_tts:
        return generate_all(
            project, screenplay, kit, build_dir,
            no_tts=True, model=model,
        )

    vo = load_vo(build_dir)
    current = {line["key"]: line for line in collect_lines(screenplay, kit)}
    keys = set(current)
    if vo and not force and not vo.get("no_tts"):
        entries = vo.get("lines") if isinstance(vo.get("lines"), dict) else {}
        if keys.issubset(set(entries)):
            complete = True
            for key in keys:
                entry = entries.get(key) or {}
                path = entry.get("path")
                if path and not Path(path).exists():
                    complete = False
                    break
                if entry.get("voice") != current[key].get("voice"):
                    complete = False
                    break
                if entry.get("text") != current[key].get("text"):
                    complete = False
                    break
            if complete:
                log("Using cached voiceover.")
                return vo

    return generate_all(
        project, screenplay, kit, build_dir,
        api_key=api_key,
        model=model,
        ffprobe=ffprobe,
        no_tts=False,
        force=force,
    )


def _resolved(project: Path, screenplay: dict, kit: dict, build_dir: Path, resolved_path: Path, *, no_tts: bool) -> dict:
    vo = {} if no_tts else load_vo(build_dir)
    if no_tts or not vo:
        if not no_tts:
            warn("No voiceover found; using estimated timing. Run `tts` first for real sync.")
        vo = estimate_vo_from_script(screenplay, kit)
    resolved = resolve_timeline(screenplay, kit, project, vo, no_tts=no_tts)
    save_json(resolved_path, resolved)
    return resolved


def _set_window_override(project: Path, width: int, height: int) -> str:
    """Temporarily force Godot's capture size. Godot honours the project override
    over --resolution, so format renders must patch it and restore it."""
    path = project / "project.godot"
    text = path.read_text(encoding="utf-8", errors="replace")
    width = max(1, int(width))
    height = max(1, int(height))

    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        value = str(width if "width" in key else height)
        return f"{key}={value}"

    updated = re.sub(
        r"(window/size/window_(?:width|height)_override)\s*=\s*\d+",
        replace,
        text,
    )
    if "window/size/window_width_override" not in updated:
        updated = updated.replace("[display]\n", f"[display]\nwindow/size/window_width_override={width}\n", 1)
    if "window/size/window_height_override" not in updated:
        updated = updated.replace("[display]\n", f"[display]\nwindow/size/window_height_override={height}\n", 1)
    path.write_text(updated, encoding="utf-8")
    return text


def _window_override(project: Path) -> tuple[int, int] | None:
    """Return the project's editor window override, which is the UI design size.

    Godot's MovieWriter honours this override over --resolution. Laying UI out at
    the full output size while capturing at the override clips captions and cards.
    Rendering at the override and upscaling in ffmpeg keeps text intact.
    """
    config = project / "project.godot"
    if not config.exists():
        return None
    text = config.read_text(encoding="utf-8", errors="replace")
    width_match = re.search(r"^window/size/window_width_override\s*=\s*(\d+)", text, re.MULTILINE)
    height_match = re.search(r"^window/size/window_height_override\s*=\s*(\d+)", text, re.MULTILINE)
    if width_match and height_match:
        width = int(width_match.group(1))
        height = int(height_match.group(1))
        if width > 0 and height > 0:
            return width, height
    return None


def _render(
    project: Path,
    resolved: dict,
    resolved_path: Path,
    *,
    godot: str,
    ffprobe: str,
    fast: bool,
    render_fps: int = 0,
    width: int = 0,
    height: int = 0,
    avi_path: Path | None = None,
    dry_run: bool = False,
) -> tuple[Path, dict]:
    fmt = resolved.get("format") if isinstance(resolved.get("format"), dict) else {}
    target_w = int(fmt.get("width", 1080))
    target_h = int(fmt.get("height", 1920))
    target_fps = int(round(float(fmt.get("fps", 30))))
    total = float(resolved.get("duration", 0.0))
    format_id = _resolved_format_id(resolved)

    design = _window_override(project)
    if design:
        design_ratio = design[0] / max(1, design[1])
        target_ratio = target_w / max(1, target_h)
        if abs(design_ratio - target_ratio) > 0.01:
            design = None

    base_w = design[0] if design else target_w
    base_h = design[1] if design else target_h
    if fast:
        base_w = max(240, (target_w // 2) - (target_w // 2) % 2)
        base_h = max(240, (target_h // 2) - (target_h // 2) % 2)

    out_w = width or base_w
    out_h = height or base_h
    if width and design and width > design[0]:
        warn(
            f"Render width {width} exceeds the project UI design width {design[0]}; "
            "captions may clip. Remove the window override or add UI scaling before increasing it."
        )
    fps = render_fps or (max(12, int(round(target_fps / 2))) if fast else target_fps)
    frames = int(math.ceil(total * fps)) + max(12, int(round(fps * 1.5)))

    if avi_path is None:
        name = resolved.get("slug") or resolved_path.name.replace(".resolved.json", "")
        avi_path = resolved_path.parent / f"{name}_{format_id}{'_preview' if fast else ''}.avi"
    avi_path = avi_path.resolve()
    avi_path.parent.mkdir(parents=True, exist_ok=True)

    episode = res_path(project, resolved_path)
    if design and (out_w, out_h) == design:
        log(f"Source: {out_w}x{out_h} (project window override); mux will upscale to {target_w}x{target_h}.")
    else:
        log(f"Format: {format_id} ({target_w}x{target_h} @ {target_fps}fps); rendering {out_w}x{out_h} natively.")
    cmd = [
        godot,
        "--path", str(project),
        "--write-movie", str(avi_path),
        "--fixed-fps", str(fps),
        "--resolution", f"{out_w}x{out_h}",
        "--quit-after", str(frames),
        "res://code_cinema/player.tscn",
        "--", f"--episode={episode}",
    ]
    if dry_run:
        log("$ " + " ".join(f'"{c}"' if " " in c else c for c in cmd))
        return avi_path, {}

    if avi_path.exists():
        avi_path.unlink()
    config_backup = _set_window_override(project, out_w, out_h)
    try:
        output = run(cmd, cwd=project, timeout=1800)
    finally:
        (project / "project.godot").write_text(config_backup, encoding="utf-8")
    if not avi_path.exists():
        fail("Godot did not produce a movie.\n" + tail(output))

    info = media_info(avi_path, ffprobe)
    if not info.get("has_video"):
        fail(f"Rendered file has no video stream: {avi_path}")
    log(
        f"Video: {avi_path} | {info.get('width')}x{info.get('height')} "
        f"| {info.get('duration', 0.0):.2f}s @ {info.get('fps', 0):.2f}fps"
    )
    if total > 0 and info.get("duration", 0.0) < total * 0.5:
        warn("Rendered video is much shorter than the timeline; check the player log.")
    return avi_path, info


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_init(args) -> None:
    dest = Path(args.dest).expanduser().resolve()
    log(f"Studio: {dest}")
    copy_template(dest, force=args.force)
    ensure_dir(dest / "build")
    ensure_dir(dest / "out")
    ensure_dir(dest / "kit" / "audio")

    godot = ""
    try:
        godot = detect_godot(None, args.godot)
    except PipelineError as exc:
        warn(str(exc))
    ffmpeg = ""
    try:
        ffmpeg = detect_ffmpeg(None, args.ffmpeg)
    except PipelineError as exc:
        warn(str(exc))
    ffprobe = ""
    if ffmpeg:
        try:
            ffprobe = detect_ffprobe(None, args.ffprobe, ffmpeg)
        except PipelineError:
            pass

    config_path = dest / "code_cinema" / "config.json"
    config = load_json(config_path) if config_path.exists() else {}
    if godot:
        config["godot"] = godot
    if ffmpeg:
        config["ffmpeg"] = ffmpeg
    if ffprobe:
        config["ffprobe"] = ffprobe
    save_json(config_path, config)

    scene = dest / "kit" / "locations" / "room_night.tscn"
    if not args.no_author:
        if not godot:
            warn("Godot not found; skipping starter scenes. Set code_cinema/config.json.")
        elif scene.exists() and not args.force:
            log("Starter scenes already exist; skipping author.")
        else:
            log("Authoring starter room, characters and props...")
            run([
                godot, "--headless", "--path", str(dest),
                "--script", "res://code_cinema/tools/author_starter.gd",
            ], timeout=600)
    else:
        log("Skipping starter scene authoring.")

    if not args.no_sfx:
        sfx_cmd = [
            sys.executable, str(SCRIPTS_DIR / "make_sfx.py"),
            "--out", str(dest / "kit" / "audio"),
        ]
        if args.force:
            sfx_cmd.append("--force")
        log("Generating procedural SFX...")
        run(sfx_cmd, timeout=600)
    else:
        log("Skipping procedural SFX.")

    env_example = dest / ".env.example"
    if not env_example.exists():
        env_example.write_text(
            "# Copy to .env and fill in. Never commit .env.\n"
            "SARVAM_API_KEY=\n",
            encoding="utf-8",
        )

    cli = Path(__file__).resolve()
    log("")
    log("Next:")
    log(f'  python "{cli}" validate demo --project "{dest}"')
    log(f'  python "{cli}" make demo --no-tts --fast --project "{dest}"')
    log(f'  python "{cli}" make demo --project "{dest}"   # requires SARVAM_API_KEY in .env')


def cmd_validate(args) -> None:
    project = _project(args)
    screenplay, kit, slug, path = _film(project, args.film)
    print(f"Film: {screenplay.get('title', '(untitled)')} [{slug}]")
    print(f"Screenplay: {path}")
    _check(screenplay, kit)


def cmd_kit(args) -> None:
    project = _project(args)
    kit = load_kit(project)
    print(kit_summary_safe(kit))


def kit_summary_safe(kit: dict) -> str:
    from cc_kit import kit_summary
    return kit_summary(kit)


def cmd_kit_scan(args) -> None:
    project = _project(args)
    godot = detect_godot(project, args.godot)
    scan_kit(project, godot, Path(args.out).resolve() if args.out else None)
    print(kit_summary_safe(load_json(project / "code_cinema" / "kit.scanned.json")))


def cmd_tts(args) -> None:
    project = _project(args)
    screenplay, kit, slug, _ = _film(project, args.film)
    _check(screenplay, kit)
    build_dir, _, _ = _paths(project, slug)
    model = _model(args, screenplay)
    if args.dry_run:
        lines = collect_lines(screenplay, kit)
        for line in lines:
            print(f"{line['key']}: {line['speaker']} [{line['voice_name']}] {line['text']}")
        print(f"{len(lines)} voice lines, model={model}")
        return
    ffmpeg = None
    try:
        ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    except PipelineError:
        pass
    ffprobe = _ffprobe_or_none(project, args, ffmpeg)
    vo = _ensure_vo(
        project, screenplay, kit, build_dir,
        no_tts=args.no_tts,
        force=args.force,
        api_key=args.sarvam_key or os.environ.get("SARVAM_API_KEY", ""),
        model=model,
        ffprobe=ffprobe,
    )
    print(f"Voiceover: {len(vo.get('lines', {}))} lines -> {build_dir / 'vo' / 'vo.json'}")


def cmd_resolve(args) -> None:
    project = _project(args)
    screenplay, kit, slug, _ = _film(project, args.film)
    _check(screenplay, kit)
    build_dir, _, default_path = _paths(project, slug)
    out_path = Path(args.out).expanduser().resolve() if args.out else default_path
    resolved = _resolved(project, screenplay, kit, build_dir, out_path, no_tts=args.no_tts)
    print(f"Resolved: {out_path}")
    print(timeline_stats(resolved))


def cmd_render(args) -> None:
    project = _project(args)
    screenplay, kit, slug, _ = _film(project, args.film)
    if args.format:
        screenplay["format_id"] = str(args.format).lower()
        screenplay["format"] = {}
    _check(screenplay, kit)
    build_dir, _, resolved_path = _paths(project, slug)
    if args.format or not resolved_path.exists():
        _resolved(project, screenplay, kit, build_dir, resolved_path, no_tts=args.no_tts)
    resolved = load_json(resolved_path)
    godot = detect_godot(project, args.godot)
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    ffprobe = detect_ffprobe(project, args.ffprobe, ffmpeg)
    avi = Path(args.avi).expanduser().resolve() if args.avi else None
    _render(
        project, resolved, resolved_path,
        godot=godot, ffprobe=ffprobe,
        fast=args.fast, render_fps=args.render_fps,
        width=args.width, height=args.height,
        avi_path=avi, dry_run=args.dry_run,
    )


def cmd_mix(args) -> None:
    project = _project(args)
    _, _, slug, _ = _film(project, args.film)
    build_dir, _, resolved_path = _paths(project, slug)
    resolved = load_json(resolved_path)
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    lufs = args.lufs
    if lufs is None:
        audio = resolved.get("audio") if isinstance(resolved.get("audio"), dict) else {}
        mix = audio.get("mix") if isinstance(audio.get("mix"), dict) else {}
        lufs = float(mix.get("lufs", -16.0))
    wav = build_mix(resolved, build_dir / f"{slug}.wav", ffmpeg, loudness_lufs=float(lufs))
    print(f"Audio: {wav}")


def _default_video(build_dir: Path, slug: str, fast: bool, format_id: str = "vertical") -> Path:
    return build_dir / f"{slug}_{format_id}{'_preview' if fast else ''}.avi"


def _resolved_format_id(resolved: dict, explicit: str | None = None) -> str:
    if explicit:
        return str(explicit).lower()
    fmt_id = str(resolved.get("format_id", "")) or str(
        resolved.get("format", {}).get("id", "vertical") if isinstance(resolved.get("format"), dict) else "vertical"
    )
    return fmt_id or "vertical"


def cmd_mux(args) -> None:
    project = _project(args)
    screenplay, kit, slug, _ = _film(project, args.film)
    build_dir, out_dir, resolved_path = _paths(project, slug)
    resolved = load_json(resolved_path)
    fmt_id = _resolved_format_id(resolved, args.format)
    if args.format:
        format_info = resolve_format(fmt_id)
        resolved["format_id"] = str(format_info["id"])
        resolved["format"] = {
            "id": str(format_info["id"]),
            "label": str(format_info.get("label", "")),
            "aspect": str(format_info.get("aspect", "")),
            "width": int(format_info["width"]),
            "height": int(format_info["height"]),
            "fps": int(format_info["fps"]),
        }
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    ffprobe = detect_ffprobe(project, args.ffprobe, ffmpeg)
    video = Path(args.video).expanduser().resolve() if args.video else _default_video(build_dir, slug, args.fast, fmt_id)
    audio = Path(args.audio).expanduser().resolve() if args.audio else build_dir / f"{slug}.wav"
    if not video.exists():
        fail(f"Video not found: {video}")
    if not audio.exists():
        fail(f"Audio not found: {audio}")
    default_out = out_dir / f"{slug}_{fmt_id}{'_preview' if args.fast else ''}.mp4"
    out = Path(args.out).expanduser().resolve() if args.out else default_out
    fmt = resolved.get("format") if isinstance(resolved.get("format"), dict) else {}
    info = media_info(video, ffprobe)
    if not info.get("has_video"):
        fail(f"No video stream in {video}")
    mux_media(
        video, audio, out, ffmpeg,
        width=int(fmt.get("width", 1080)),
        height=int(fmt.get("height", 1920)),
        fps=float(fmt.get("fps", 30)),
        title=str(resolved.get("title", screenplay.get("title", "Code Cinema"))),
        crf=args.crf,
        preset=args.preset,
    )
    print(f"MP4: {out}")


def cmd_poster(args) -> None:
    project = _project(args)
    _, _, slug, _ = _film(project, args.film)
    build_dir, out_dir, _ = _paths(project, slug)
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    fmt_id = str(args.format or "vertical").lower()
    if args.video:
        video = Path(args.video).expanduser().resolve()
    else:
        mp4 = out_dir / f"{slug}_{fmt_id}{'_preview' if args.fast else ''}.mp4"
        video = mp4 if mp4.exists() else _default_video(build_dir, slug, args.fast, fmt_id)
    if not video.exists():
        fail(f"Video not found: {video}")
    out = Path(args.out).expanduser().resolve() if args.out else out_dir / f"{slug}_{fmt_id}{'_preview' if args.fast else ''}_poster.jpg"
    make_poster(video, out, ffmpeg, at=args.at)
    print(f"Poster: {out}")


def cmd_srt(args) -> None:
    project = _project(args)
    _, _, slug, _ = _film(project, args.film)
    _, out_dir, resolved_path = _paths(project, slug)
    resolved = load_json(resolved_path)
    out = Path(args.out).expanduser().resolve() if args.out else out_dir / f"{slug}.srt"
    write_srt(resolved.get("captions", []), out)
    print(f"SRT: {out}")


def cmd_frames(args) -> None:
    project = _project(args)
    _, _, slug, _ = _film(project, args.film)
    build_dir, out_dir, resolved_path = _paths(project, slug)
    resolved = load_json(resolved_path)
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    ffprobe = detect_ffprobe(project, args.ffprobe, ffmpeg)
    if args.video:
        video = Path(args.video).expanduser().resolve()
    else:
        mp4 = out_dir / f"{slug}{'_preview' if args.fast else ''}.mp4"
        video = mp4 if mp4.exists() else _default_video(build_dir, slug, args.fast)
    if not video.exists():
        fail(f"Video not found: {video}")
    info = media_info(video, ffprobe)
    total = float(info.get("duration") or resolved.get("duration", 0.0))
    if args.times:
        try:
            times = [float(v.strip()) for v in args.times.split(",") if v.strip()]
        except ValueError:
            fail("--times must be a comma-separated list of seconds.")
    else:
        step = max(0.5, float(args.every))
        times = []
        at = 0.5
        while at < max(1.0, total):
            times.append(at)
            at += step
        if not times:
            times = [0.0]
    out_dir_frames = Path(args.out_dir).expanduser().resolve() if args.out_dir else build_dir / "frames"
    frames = extract_frames(video, out_dir_frames, ffmpeg, times)
    for frame in frames:
        print(frame)


def cmd_make(args) -> None:
    project = _project(args)
    screenplay, kit, slug, sp_path = _film(project, args.film)
    if args.format:
        screenplay["format_id"] = str(args.format).lower()
        screenplay["format"] = {}
    print(f"Film: {screenplay.get('title', '(untitled)')} [{slug}]")
    print(f"Screenplay: {sp_path}")
    selected_format = resolve_format(args.format, screenplay)
    if not selected_format.get("renderable", True):
        fail(f"Format '{selected_format['id']}' is reserved and not renderable yet.")
    _check(screenplay, kit)

    build_dir, out_dir, resolved_path = _paths(project, slug)
    model = _model(args, screenplay)
    ffmpeg = detect_ffmpeg(project, args.ffmpeg)
    ffprobe = detect_ffprobe(project, args.ffprobe, ffmpeg)
    ffprobe_optional = ffprobe

    vo = _ensure_vo(
        project, screenplay, kit, build_dir,
        no_tts=args.no_tts,
        force=args.force_tts,
        api_key=args.sarvam_key or os.environ.get("SARVAM_API_KEY", ""),
        model=model,
        ffprobe=ffprobe_optional,
    )
    resolved = resolve_timeline(screenplay, kit, project, vo, no_tts=args.no_tts)
    save_json(resolved_path, resolved)
    print(f"Resolved: {resolved_path}")
    print(timeline_stats(resolved))

    godot = detect_godot(project, args.godot)
    make_fmt_id = _resolved_format_id(resolved, args.format)
    avi = Path(args.avi).expanduser().resolve() if args.avi else _default_video(build_dir, slug, args.fast, make_fmt_id)
    if args.skip_render:
        if not avi.exists():
            fail(f"--skip-render but video not found: {avi}")
        log(f"Using existing video: {avi}")
    else:
        _render(
            project, resolved, resolved_path,
            godot=godot, ffprobe=ffprobe,
            fast=args.fast, width=args.width, height=args.height,
            avi_path=avi,
        )

    lufs = args.lufs
    if lufs is None:
        audio = resolved.get("audio") if isinstance(resolved.get("audio"), dict) else {}
        mix = audio.get("mix") if isinstance(audio.get("mix"), dict) else {}
        lufs = float(mix.get("lufs", -16.0))
    wav = build_mix(resolved, build_dir / f"{slug}.wav", ffmpeg, loudness_lufs=float(lufs))
    film_title = str(resolved.get("title", screenplay.get("title", "Code Cinema")))
    audio_transcript_mp3 = out_dir / f"{slug}_transcript.mp3"
    audio_only_mp3 = out_dir / f"{slug}_audio.mp3"
    audio_mp3(wav, audio_transcript_mp3, ffmpeg, title=f"{film_title} — Audio Transcript")
    audio_mp3(wav, audio_only_mp3, ffmpeg, title=f"{film_title} — Soundtrack")
    fmt = resolved.get("format") if isinstance(resolved.get("format"), dict) else {}
    fmt_id = _resolved_format_id(resolved, args.format)
    mp4 = out_dir / f"{slug}_{fmt_id}{'_preview' if args.fast else ''}.mp4"
    mux_media(
        avi, wav, mp4, ffmpeg,
        width=int(fmt.get("width", 1080)),
        height=int(fmt.get("height", 1920)),
        fps=float(fmt.get("fps", 30)),
        title=str(resolved.get("title", screenplay.get("title", "Code Cinema"))),
        crf=args.crf,
        preset=args.preset,
    )

    poster = out_dir / f"{slug}_{fmt_id}{'_preview' if args.fast else ''}_poster.jpg"
    make_poster(mp4, poster, ffmpeg, at=min(1.0, max(0.0, float(resolved.get("duration", 0.0)) - 0.1)))
    srt = out_dir / f"{slug}.srt"
    write_srt(resolved.get("captions", []), srt)
    transcript = out_dir / f"{slug}_transcript.md"
    write_transcript(resolved, transcript)
    post = out_dir / f"{slug}_post.md"
    write_post(resolved, post)

    print("")
    print("Done.")
    print(f"  MP4:        {mp4}")
    print(f"  Audio MP3:  {audio_transcript_mp3}")
    print(f"  Soundtrack: {audio_only_mp3}")
    print(f"  Poster:     {poster}")
    print(f"  SRT:        {srt}")
    print(f"  Transcript: {transcript}")
    print(f"  Post:       {post}")
    print(f"  Work:       {build_dir}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _common() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--project", help="Godot studio directory (contains project.godot).")
    parser.add_argument("--godot", help="Godot executable path.")
    parser.add_argument("--ffmpeg", help="ffmpeg executable path.")
    parser.add_argument("--ffprobe", help="ffprobe executable path.")
    return parser


def build_parser() -> argparse.ArgumentParser:
    common = _common()
    parser = argparse.ArgumentParser(description="Code Cinema: JSON screenplay to MP4.")
    sub = parser.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init", parents=[common], help="Create a studio and starter kit.")
    init.add_argument("--dest", default=str(DEFAULT_STUDIO), help="Studio destination.")
    init.add_argument("--force", action="store_true", help="Overwrite template files and rebuild starter assets.")
    init.add_argument("--no-author", action="store_true", help="Skip Godot starter scene authoring.")
    init.add_argument("--no-sfx", action="store_true", help="Skip procedural SFX.")
    init.set_defaults(func=cmd_init)

    val = sub.add_parser("validate", parents=[common], help="Validate a screenplay against the kit.")
    val.add_argument("film", nargs="?", default="demo")
    val.set_defaults(func=cmd_validate)

    kit = sub.add_parser("kit", parents=[common], help="Print the kit manifest summary.")
    kit.set_defaults(func=cmd_kit)

    scan = sub.add_parser("kit-scan", parents=[common], help="Scan scenes into kit.scanned.json.")
    scan.add_argument("--out")
    scan.set_defaults(func=cmd_kit_scan)

    tts = sub.add_parser("tts", parents=[common], help="Generate voiceover (Sarvam or Edge) and timing.")
    tts.add_argument("film", nargs="?", default="demo")
    tts.add_argument("--no-tts", action="store_true", help="Write estimated silent timing only.")
    tts.add_argument("--force", action="store_true", help="Ignore the TTS cache.")
    tts.add_argument("--dry-run", action="store_true", help="List lines without calling Sarvam.")
    tts.add_argument("--sarvam-key", help="Sarvam API key (or use SARVAM_API_KEY).")
    tts.add_argument("--model", help=f"Sarvam model (default {DEFAULT_MODEL}); ignored by Edge voices.")
    tts.set_defaults(func=cmd_tts)

    res = sub.add_parser("resolve", parents=[common], help="Resolve the screenplay into a timed timeline.")
    res.add_argument("film", nargs="?", default="demo")
    res.add_argument("--no-tts", action="store_true", help="Use estimated speeds instead of vo.json.")
    res.add_argument("--out", help="Output resolved JSON path.")
    res.set_defaults(func=cmd_resolve)

    render = sub.add_parser("render", parents=[common], help="Render the silent video with Godot.")
    render.add_argument("film", nargs="?", default="demo")
    render.add_argument("--fast", action="store_true", help="Half-resolution, half-fps preview.")
    render.add_argument("--render-fps", type=int, default=0, help="Override render fps.")
    render.add_argument("--width", type=int, default=0)
    render.add_argument("--height", type=int, default=0)
    render.add_argument("--avi", help="Output AVI path.")
    render.add_argument("--format", help="Output format: vertical, square, landscape, draft.")
    render.add_argument("--no-tts", action="store_true", help="Resolve with estimated timing if needed.")
    render.add_argument("--dry-run", action="store_true", help="Print the Godot command.")
    render.set_defaults(func=cmd_render)

    mix = sub.add_parser("mix", parents=[common], help="Build the mixed WAV from cues.")
    mix.add_argument("film", nargs="?", default="demo")
    mix.add_argument("--lufs", type=float)
    mix.set_defaults(func=cmd_mix)

    mux = sub.add_parser("mux", parents=[common], help="Mux video + audio into MP4.")
    mux.add_argument("film", nargs="?", default="demo")
    mux.add_argument("--fast", action="store_true")
    mux.add_argument("--video")
    mux.add_argument("--audio")
    mux.add_argument("--out")
    mux.add_argument("--format", help="Output format: vertical, square, landscape, draft.")
    mux.add_argument("--crf", type=int, default=18)
    mux.add_argument("--preset", default="medium")
    mux.set_defaults(func=cmd_mux)

    poster = sub.add_parser("poster", parents=[common], help="Extract a poster frame.")
    poster.add_argument("film", nargs="?", default="demo")
    poster.add_argument("--fast", action="store_true")
    poster.add_argument("--video")
    poster.add_argument("--out")
    poster.add_argument("--format", help="Output format: vertical, square, landscape, draft.")
    poster.add_argument("--at", type=float, default=1.0)
    poster.set_defaults(func=cmd_poster)

    srt = sub.add_parser("srt", parents=[common], help="Write subtitles from the resolved timeline.")
    srt.add_argument("film", nargs="?", default="demo")
    srt.add_argument("--out")
    srt.set_defaults(func=cmd_srt)

    frames = sub.add_parser("frames", parents=[common], help="Extract review frames.")
    frames.add_argument("film", nargs="?", default="demo")
    frames.add_argument("--fast", action="store_true")
    frames.add_argument("--video")
    frames.add_argument("--times", help="Comma-separated seconds.")
    frames.add_argument("--every", type=float, default=5.0)
    frames.add_argument("--out-dir")
    frames.set_defaults(func=cmd_frames)

    make = sub.add_parser("make", parents=[common], help="Full pipeline: voice -> resolve -> render -> mix -> mux.")
    make.add_argument("film", nargs="?", default="demo")
    make.add_argument("--no-tts", action="store_true", help="Silent draft; estimated timing.")
    make.add_argument("--force-tts", action="store_true", help="Ignore the TTS cache.")
    make.add_argument("--fast", action="store_true", help="Half-res, half-fps preview output.")
    make.add_argument("--skip-render", action="store_true", help="Reuse an existing AVI.")
    make.add_argument("--format", help="Output format: vertical, square, landscape, draft.")
    make.add_argument("--avi", help="Existing or output AVI path.")
    make.add_argument("--width", type=int, default=0)
    make.add_argument("--height", type=int, default=0)
    make.add_argument("--sarvam-key", help="Sarvam API key (or use SARVAM_API_KEY).")
    make.add_argument("--model", help=f"Sarvam model (default {DEFAULT_MODEL}); ignored by Edge voices.")
    make.add_argument("--lufs", type=float)
    make.add_argument("--crf", type=int, default=18)
    make.add_argument("--preset", default="medium")
    make.set_defaults(func=cmd_make)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.func(args)
        return 0
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
