"""Shared helpers for Code Cinema. Standard library only."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = SKILL_ROOT / "scripts"
TEMPLATE_STUDIO = SKILL_ROOT / "templates" / "studio"
FORMATS_PATH = SKILL_ROOT / "styles" / "formats.json"


class PipelineError(RuntimeError):
    pass


def log(message: str = "") -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print("WARN: " + message, file=sys.stderr, flush=True)


def fail(message: str) -> None:
    raise PipelineError(message)


def load_json(path: str | Path) -> dict:
    p = Path(path)
    if not p.exists():
        fail(f"JSON file not found: {p}")
    try:
        with p.open("r", encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        fail(f"Invalid JSON in {p}: {exc}")
    if not isinstance(data, dict):
        fail(f"Expected a JSON object in {p}")
    return data


def save_json(path: str | Path, data, indent: int = 2) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=indent, ensure_ascii=False)
        fh.write("\n")


def sha1_text(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()


def slugify(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_-]+", "-", value.strip()).strip("-").lower()
    return value or "film"


def ensure_dir(path: str | Path) -> Path:
    p = Path(path)
    p.mkdir(parents=True, exist_ok=True)
    return p


def fmt_clock(seconds: float) -> str:
    seconds = max(0.0, float(seconds))
    minutes = int(seconds // 60)
    secs = seconds - minutes * 60
    return f"{minutes:02d}:{secs:05.2f}"


def fmt_srt(seconds: float) -> str:
    seconds = max(0.0, float(seconds))
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    ms = int(round((seconds - int(seconds)) * 1000))
    if ms >= 1000:
        secs += 1
        ms -= 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"


def estimate_vo_duration(text: str, words_per_second: float = 2.6) -> float:
    clean = re.sub(r"\s+", " ", (text or "").strip())
    if not clean:
        return 0.6
    words = len(clean.split())
    punctuation = 0.08 * (clean.count(",") + clean.count(";") + clean.count(":"))
    sentence = 0.14 * (clean.count(".") + clean.count("!") + clean.count("?"))
    return max(0.8, words / max(0.5, words_per_second) + punctuation + sentence)


def load_dotenv(project: Path) -> None:
    for candidate in (project / ".env", project / "code_cinema" / ".env"):
        if not candidate.exists():
            continue
        try:
            for raw in candidate.read_text(encoding="utf-8", errors="replace").splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = value
        except OSError:
            pass


def find_project(start: str | Path | None = None, explicit: str | None = None) -> Path:
    if explicit:
        p = Path(explicit).expanduser().resolve()
        if not (p / "project.godot").exists():
            fail(f"Not a Godot project (project.godot missing): {p}")
        return p

    start_path = Path(start) if start else Path.cwd()
    start_path = start_path.expanduser().resolve()
    if start_path.is_file():
        start_path = start_path.parent

    for candidate in [start_path, *start_path.parents]:
        if (candidate / "project.godot").exists():
            return candidate
        studio = candidate / "studio"
        if (studio / "project.godot").exists():
            return studio

    fail(
        "Could not find a Godot studio (project.godot). Run `codecinema.py init` "
        "to create one, or pass --project <path>."
    )
    raise AssertionError


def load_config(project: Path) -> dict:
    path = project / "code_cinema" / "config.json"
    return load_json(path) if path.exists() else {}


def load_formats() -> dict:
    data = load_json(FORMATS_PATH)
    formats = data.get("formats") if isinstance(data, dict) else None
    if not isinstance(formats, dict) or not formats:
        fail(f"Format registry is empty or invalid: {FORMATS_PATH}")
    return data


def _screenplay_format_id(screenplay: dict) -> str:
    explicit = str(screenplay.get("format_id", "") or "").strip().lower()
    if explicit:
        return explicit
    fmt = screenplay.get("format") if isinstance(screenplay.get("format"), dict) else {}
    width = int(fmt.get("width", 0) or 0)
    height = int(fmt.get("height", 0) or 0)
    if width == 1080 and height == 1920:
        return "vertical"
    if width == 1080 and height == 1080:
        return "square"
    if width == 1920 and height == 1080:
        return "landscape"
    if width == 540 and height == 960:
        return "draft"
    return ""


def resolve_format(explicit: str | None, screenplay: dict | None = None) -> dict:
    """Return the registry entry for a format, with width/height/fps and id."""
    data = load_formats()
    formats = data["formats"]
    default_id = str(data.get("default_format", "vertical"))
    format_id = (explicit or ( screenplay.get("format_id") if isinstance(screenplay, dict) else None) or _screenplay_format_id(screenplay or {}) or default_id)
    format_id = str(format_id).strip().lower()
    if format_id not in formats:
        available = ", ".join(sorted(formats.keys()))
        fail(f"Unknown format '{format_id}'. Available formats: {available}")
    entry = dict(formats[format_id])
    if not isinstance(entry, dict):
        fail(f"Format '{format_id}' is invalid in {FORMATS_PATH}")
    entry["id"] = format_id
    try:
        entry["width"] = int(entry.get("width", 0))
        entry["height"] = int(entry.get("height", 0))
        entry["fps"] = int(entry.get("fps", 30))
        entry["renderable"] = bool(entry.get("renderable", True))
    except (TypeError, ValueError) as exc:
        raise PipelineError(f"Format '{format_id}' has invalid width/height/fps: {exc}") from exc
    if entry["width"] <= 0 or entry["height"] <= 0:
        fail(f"Format '{format_id}' has invalid width/height.")
    return entry


def _is_console(exe: Path) -> bool:
    return "console" in exe.name.lower()


def _godot_candidates(project: Path | None, explicit: str | None, config: dict) -> list[Path]:
    candidates: list[Path] = []

    def push(value):
        if not value:
            return
        p = Path(value).expanduser()
        if p.is_dir():
            candidates.extend(sorted(p.glob("Godot*.exe")))
        else:
            candidates.append(p)

    push(explicit)
    push(config.get("godot"))
    push(os.environ.get("GODOT_BIN"))
    push(os.environ.get("GODOT4_BIN"))
    for name in ("godot", "godot4", "Godot"):
        found = shutil.which(name)
        if found:
            candidates.append(Path(found))
    if project:
        push(project / ".godot" / "godot")
    push(Path("C:/Program Files/Godot"))
    push(Path("C:/Program Files (x86)/Godot"))
    push(Path.home() / "AppData/Local/Programs/Godot")
    push(Path.home() / "scoop/apps/godot/current")

    cleaned: list[Path] = []
    seen = set()
    for p in candidates:
        try:
            p = p.resolve()
        except OSError:
            continue
        if p in seen or not p.exists() or not p.is_file():
            continue
        if p.suffix.lower() not in (".exe", ""):
            continue
        seen.add(p)
        cleaned.append(p)
    if os.name == "nt":
        cleaned.sort(key=lambda p: not _is_console(p))
    return cleaned


def detect_godot(project: Path | None = None, explicit: str | None = None) -> str:
    config = load_config(project) if project else {}
    candidates = _godot_candidates(project, explicit, config)
    if not candidates:
        fail(
            "Godot executable not found. Pass --godot <path>, set GODOT_BIN, "
            "or edit code_cinema/config.json."
        )
    return str(candidates[0])


def detect_ffmpeg(project: Path | None = None, explicit: str | None = None) -> str:
    config = load_config(project) if project else {}
    for value in (explicit, config.get("ffmpeg"), os.environ.get("FFMPEG_BIN")):
        if value:
            p = Path(value).expanduser()
            if p.is_dir():
                p = p / "ffmpeg.exe"
            if p.exists():
                return str(p)
    found = shutil.which("ffmpeg")
    if found:
        return found
    fail("ffmpeg not found. Install it or set FFMPEG_BIN / code_cinema/config.json.")


def detect_ffprobe(project: Path | None = None, explicit: str | None = None, ffmpeg: str | None = None) -> str:
    config = load_config(project) if project else {}
    for value in (explicit, config.get("ffprobe"), os.environ.get("FFPROBE_BIN")):
        if value:
            p = Path(value).expanduser()
            if p.is_dir():
                p = p / "ffprobe.exe"
            if p.exists():
                return str(p)
    found = shutil.which("ffprobe")
    if found:
        return found
    if ffmpeg:
        sibling = Path(ffmpeg).with_name("ffprobe.exe" if os.name == "nt" else "ffprobe")
        if sibling.exists():
            return str(sibling)
    fail("ffprobe not found. Install it or set FFPROBE_BIN / code_cinema/config.json.")


def run(cmd: list[str], cwd: Path | None = None, timeout: int | None = None, check: bool = True) -> str:
    printable = " ".join(f'"{c}"' if " " in c else c for c in cmd)
    log("$ " + printable)
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.output or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", "replace")
        fail(f"Command timed out after {timeout}s:\n{printable}\n{tail(output)}")
    output = proc.stdout or ""
    if check and proc.returncode != 0:
        fail(f"Command failed ({proc.returncode}):\n{printable}\n{tail(output)}")
    return output


def tail(text: str, lines: int = 40) -> str:
    parts = (text or "").strip().splitlines()
    return "\n".join(parts[-lines:])


def media_info(path: str | Path, ffprobe: str) -> dict:
    p = Path(path)
    if not p.exists():
        fail(f"Media file not found: {p}")
    cmd = [
        ffprobe, "-v", "error",
        "-show_entries", "stream=index,codec_type,width,height,r_frame_rate,duration,channels,sample_rate",
        "-show_entries", "format=duration,size",
        "-of", "json",
        str(p),
    ]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=60)
    except OSError as exc:
        fail(f"Could not run ffprobe: {exc}")
    if proc.returncode != 0:
        fail(f"ffprobe failed for {p}: {proc.stderr.strip()}")
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        fail(f"ffprobe returned invalid JSON for {p}")
    info = {"duration": 0.0, "width": 0, "height": 0, "fps": 0.0, "has_video": False, "has_audio": False}
    fmt = data.get("format", {})
    try:
        info["duration"] = float(fmt.get("duration") or 0.0)
    except (TypeError, ValueError):
        pass
    for stream in data.get("streams", []):
        kind = stream.get("codec_type")
        if kind == "video" and not info["has_video"]:
            info["has_video"] = True
            info["width"] = int(stream.get("width") or 0)
            info["height"] = int(stream.get("height") or 0)
            rate = stream.get("r_frame_rate") or "0/1"
            try:
                num, den = rate.split("/")
                info["fps"] = float(num) / float(den) if float(den) else 0.0
            except (ValueError, ZeroDivisionError):
                info["fps"] = 0.0
            if not info["duration"]:
                try:
                    info["duration"] = float(stream.get("duration") or 0.0)
                except (TypeError, ValueError):
                    pass
        elif kind == "audio":
            info["has_audio"] = True
    return info


def res_path(project: Path, path: str | Path) -> str:
    p = Path(path).resolve()
    try:
        rel = p.relative_to(project.resolve())
    except ValueError:
        fail(f"Path is outside the Godot project: {p}")
    return "res://" + rel.as_posix()


def project_path(project: Path, value: str) -> Path:
    if value.startswith("res://"):
        return project / value[len("res://"):]
    p = Path(value)
    return p if p.is_absolute() else project / p


def resolve_screenplay(project: Path, value: str) -> Path:
    if value.startswith("res://"):
        return project_path(project, value)
    p = Path(value).expanduser()
    if p.is_absolute():
        return p
    for candidate in (Path.cwd() / p, project / p, project / "films" / p):
        if candidate.exists():
            return candidate.resolve()
    return (Path.cwd() / p).resolve()


def copy_template(destination: Path, force: bool = False) -> None:
    if not TEMPLATE_STUDIO.exists():
        fail(f"Studio template missing: {TEMPLATE_STUDIO}")
    destination.mkdir(parents=True, exist_ok=True)
    for source in TEMPLATE_STUDIO.rglob("*"):
        if source.is_dir():
            continue
        rel = source.relative_to(TEMPLATE_STUDIO)
        target = destination / rel
        if target.exists() and not force:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def copy_file(source: Path, target: Path, force: bool = False) -> None:
    if target.exists() and not force:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def wait_for_file(path: Path, timeout: float = 10.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists() and path.stat().st_size > 0:
            return True
        time.sleep(0.2)
    return False
