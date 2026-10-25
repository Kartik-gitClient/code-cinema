"""Kit manifest loading, validation and headless scanning."""

from __future__ import annotations

from pathlib import Path

from cc_common import (
    PipelineError,
    fail,
    load_json,
    log,
    res_path,
    resolve_format,
    run,
    tail,
)


def load_kit(project: Path) -> dict:
    path = project / "code_cinema" / "kit.json"
    if not path.exists():
        fail(f"Kit manifest missing: {path}")
    return load_json(path)


def _as_list(value) -> list:
    return value if isinstance(value, list) else []


def _as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def _voice_exists(name: str, kit: dict) -> bool:
    return name in _as_dict(kit.get("voices"))


FORBIDDEN_SARVAM_SPEAKERS = {"ishita", "ratan", "shubh", "tanya", "varun", "anushka", "abhilash"}


def _forbidden_voice_entry(entry) -> str:
    if not isinstance(entry, dict):
        return ""
    provider = str(entry.get("provider", "sarvam")).strip().lower()
    language = str(entry.get("language", entry.get("language_code", ""))).strip().lower()
    speaker = str(entry.get("speaker", "")).strip().lower()
    if provider == "edge":
        return ""
    if language.startswith("en-in") or speaker in FORBIDDEN_SARVAM_SPEAKERS:
        return speaker or language or provider
    return ""


def _check_ref(errors: list[str], warnings: list[str], label: str, value: str, table: dict, kind: str) -> None:
    if not value:
        return
    if value not in table:
        errors.append(f"{label}: unknown {kind} '{value}'")


def validate(screenplay: dict, kit: dict, *, strict: bool = True) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if int(screenplay.get("version", 1)) < 1:
        errors.append("screenplay.version must be >= 1")
    if not str(screenplay.get("title", "")).strip():
        errors.append("screenplay.title is required")

    fmt = _as_dict(screenplay.get("format"))
    try:
        format_info = resolve_format(screenplay.get("format_id"), screenplay)
        width = format_info["width"]
        height = format_info["height"]
        fps = float(format_info["fps"])
        if fmt:
            authored_width = int(fmt.get("width", width))
            authored_height = int(fmt.get("height", height))
            authored_fps = float(fmt.get("fps", fps))
            if (authored_width, authored_height) != (width, height):
                errors.append(
                    f"screenplay.format {authored_width}x{authored_height} does not match format "
                    f"'{format_info['id']}' ({width}x{height})."
                )
            if authored_fps != fps:
                errors.append(
                    f"screenplay.format.fps {authored_fps} does not match format "
                    f"'{format_info['id']}' ({fps})."
                )
    except PipelineError as exc:
        errors.append(str(exc))
        width, height, fps = 1080, 1920, 30.0
    if width < 64 or height < 64:
        errors.append("format width/height are too small")
    if fps < 6 or fps > 120:
        errors.append("format.fps must be between 6 and 120")
    if not bool(format_info.get("renderable", True)) and "format_info" in locals():
        errors.append(f"Format '{format_info.get('id', 'draft')}' is reserved and not renderable yet.")

    locations = _as_dict(kit.get("locations"))
    characters = _as_dict(kit.get("characters"))
    props = _as_dict(kit.get("props"))
    sfx_table = _as_dict(kit.get("sfx"))
    music_table = _as_dict(kit.get("music"))
    voices = _as_dict(kit.get("voices"))

    shots = _as_list(screenplay.get("shots"))
    if not shots:
        errors.append("screenplay.shots must contain at least one shot")
    if len(shots) > 120:
        warnings.append("More than 120 shots; this is a feature, not a short. Check pacing.")

    seen_ids: set[str] = set()
    estimated_total = float(_as_dict(screenplay.get("opening")).get("duration", 0.0))
    has_dialogue = False

    for index, shot in enumerate(shots):
        if not isinstance(shot, dict):
            errors.append(f"shots[{index}] must be an object")
            continue
        shot_id = str(shot.get("id", f"shot{index + 1}"))
        if shot_id in seen_ids:
            errors.append(f"Duplicate shot id '{shot_id}'")
        seen_ids.add(shot_id)
        label = f"shot {shot_id}"

        try:
            duration = float(shot.get("duration", 0.0))
        except (TypeError, ValueError):
            duration = 0.0
            errors.append(f"{label}: duration must be a number")
        if duration <= 0:
            errors.append(f"{label}: duration must be > 0")
        elif duration > 20:
            warnings.append(f"{label}: {duration:.1f}s is long; consider cutting or splitting it.")
        estimated_total += max(0.0, duration)

        location_name = str(shot.get("location", screenplay.get("default_location", "")))
        if not location_name:
            errors.append(f"{label}: location is required")
            location = {}
        else:
            location = _as_dict(locations.get(location_name))
            if not location:
                errors.append(f"{label}: unknown location '{location_name}'")
        anchors = set(str(a) for a in _as_list(location.get("anchors")))
        slots = set(str(s) for s in _as_list(location.get("slots")))
        slots.add("player")

        camera = _as_dict(shot.get("camera"))
        anchor = str(camera.get("anchor", ""))
        if anchors and anchor and anchor not in anchors:
            warnings.append(f"{label}: camera anchor '{anchor}' is not listed in the kit manifest.")
        if not anchor:
            warnings.append(f"{label}: camera.anchor is empty; the player will use a default position.")
        look_at = str(camera.get("look_at", ""))
        if look_at.startswith("anchor:"):
            ref = look_at.split(":", 1)[1]
            if anchors and ref not in anchors:
                warnings.append(f"{label}: look_at anchor '{ref}' is not listed in the kit manifest.")
        elif look_at.startswith("actor:"):
            ref = look_at.split(":", 1)[1]
            actor_ids = {str(a.get("id")) for a in _as_list(shot.get("actors")) if isinstance(a, dict)}
            if ref not in actor_ids:
                warnings.append(f"{label}: look_at actor '{ref}' is not in this shot's cast.")
        if str(camera.get("move", "static")) not in (
            "static", "push_in", "pull_out", "dolly", "pan", "tilt", "roll",
            "orbit", "crane_up", "crane_down", "handheld", "track", "zoom",
        ):
            errors.append(f"{label}: unknown camera move '{camera.get('move')}'")

        actors = _as_list(shot.get("actors"))
        for actor in actors:
            if not isinstance(actor, dict):
                errors.append(f"{label}: actors entries must be objects")
                continue
            actor_id = str(actor.get("id", ""))
            character_id = str(actor.get("character", ""))
            if not actor_id:
                errors.append(f"{label}: actor.id is required")
            if character_id not in characters:
                errors.append(f"{label}: unknown character '{character_id}'")
                continue
            char = _as_dict(characters.get(character_id))
            anim = str(actor.get("anim", ""))
            anims = set(str(a) for a in _as_list(char.get("animations")))
            if anim and anims and anim not in anims:
                warnings.append(f"{label}: character '{character_id}' has no animation '{anim}'.")
            slot = str(actor.get("slot", ""))
            if slot and slots and slot not in slots:
                warnings.append(f"{label}: slot '{slot}' is not listed for location '{location_name}'.")

        for prop in _as_list(shot.get("props")):
            if not isinstance(prop, dict):
                errors.append(f"{label}: props entries must be objects")
                continue
            prop_id = str(prop.get("prop", ""))
            if prop_id not in props:
                errors.append(f"{label}: unknown prop '{prop_id}'")
            prop_anchor = str(prop.get("anchor", ""))
            if prop_anchor and anchors and prop_anchor not in anchors:
                warnings.append(f"{label}: prop anchor '{prop_anchor}' is not listed in the kit manifest.")

        for sfx in _as_list(shot.get("sfx")):
            if not isinstance(sfx, dict):
                errors.append(f"{label}: sfx entries must be objects")
                continue
            sound = str(sfx.get("sound", ""))
            if sound not in sfx_table:
                errors.append(f"{label}: unknown sfx '{sound}'")
            try:
                at = float(sfx.get("at", 0.0))
                if at < 0:
                    errors.append(f"{label}: sfx '{sound}' has negative start time")
            except (TypeError, ValueError):
                errors.append(f"{label}: sfx '{sound}' start time must be a number")

        dialogue = _as_list(shot.get("dialogue"))
        if dialogue:
            has_dialogue = True
        for line in dialogue:
            if not isinstance(line, dict):
                errors.append(f"{label}: dialogue entries must be objects")
                continue
            text = str(line.get("text", "")).strip()
            if not text:
                errors.append(f"{label}: dialogue text is empty")
            raw_voice = line.get("voice", "narrator")
            if isinstance(raw_voice, str) and raw_voice and not _voice_exists(raw_voice, kit):
                warnings.append(f"{label}: voice '{raw_voice}' is not in kit.json voices.")
            try:
                start = float(line.get("start", 0.0))
                if start < 0:
                    errors.append(f"{label}: dialogue start must be >= 0")
            except (TypeError, ValueError):
                errors.append(f"{label}: dialogue start must be a number")

    opening = _as_dict(screenplay.get("opening"))
    opening_duration = float(opening.get("duration", 0.0)) if opening else 0.0
    if opening_duration < 0:
        errors.append("opening.duration must be >= 0")

    ending = _as_dict(screenplay.get("ending"))
    if ending:
        question = str(ending.get("question", "")).strip()
        options = _as_list(ending.get("options"))
        if not question:
            warnings.append("ending.question is empty; the ending card will be blank.")
        if len(options) < 2:
            warnings.append("ending.options should have at least 2 choices.")
        if len(options) > 4:
            warnings.append("ending.options has more than 4 choices; voting gets messy.")
        ending_voice = ending.get("voice", "narrator")
        if isinstance(ending_voice, str) and ending_voice and not _voice_exists(ending_voice, kit):
            warnings.append(f"ending.voice '{ending_voice}' is not in kit.json voices.")
        try:
            estimated_total += float(ending.get("duration", 5.0))
        except (TypeError, ValueError):
            errors.append("ending.duration must be a number")
    else:
        warnings.append("No ending card. For a series, add ending.question and ending.options.")

    music = _as_dict(_as_dict(screenplay.get("audio")).get("music"))
    if music:
        track = str(music.get("track", ""))
        if track and track not in music_table:
            errors.append(f"audio.music.track: unknown music track '{track}'")

    for voice_name, voice in sorted(voices.items()):
        bad_voice = _forbidden_voice_entry(voice)
        if bad_voice:
            errors.append(
                f"voices.{voice_name}: forbidden narration voice '{bad_voice}'; "
                "use a native English Edge TTS voice."
            )

    if estimated_total < 4:
        warnings.append("Estimated runtime is under 4 seconds. Too short for a film/reel.")
    elif estimated_total > 180:
        warnings.append("Estimated runtime is over 3 minutes. Short attention span; consider splitting.")

    if strict and errors:
        raise PipelineError("Screenplay validation failed:\n- " + "\n- ".join(errors))
    return errors, warnings


def print_validation(errors: list[str], warnings: list[str]) -> None:
    for warning in warnings:
        print(f"WARN: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    if not errors and not warnings:
        log("Screenplay OK.")


def kit_summary(kit: dict) -> str:
    locations = _as_dict(kit.get("locations"))
    characters = _as_dict(kit.get("characters"))
    props = _as_dict(kit.get("props"))
    sfx = _as_dict(kit.get("sfx"))
    music = _as_dict(kit.get("music"))
    lines = [
        f"Kit: {kit.get('name', '(unnamed)')}",
        f"Locations ({len(locations)}): " + ", ".join(sorted(locations)) if locations else "Locations: (none)",
        f"Characters ({len(characters)}): " + ", ".join(sorted(characters)) if characters else "Characters: (none)",
        f"Props ({len(props)}): " + ", ".join(sorted(props)) if props else "Props: (none)",
        f"SFX ({len(sfx)}): " + ", ".join(sorted(sfx)) if sfx else "SFX: (none)",
        f"Music ({len(music)}): " + ", ".join(sorted(music)) if music else "Music: (none)",
    ]
    for name, entry in sorted(locations.items()):
        if not isinstance(entry, dict):
            continue
        anchors = ", ".join(str(a) for a in _as_list(entry.get("anchors"))) or "-"
        slots = ", ".join(str(s) for s in _as_list(entry.get("slots"))) or "-"
        lines.append(f"  {name}: anchors [{anchors}] slots [{slots}]")
    return "\n".join(lines)


def scan_kit(project: Path, godot: str, out_path: Path | None = None) -> dict:
    out_path = out_path or (project / "code_cinema" / "kit.scanned.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_arg = str(out_path.resolve())
    try:
        out_arg = res_path(project, out_path)
    except PipelineError:
        pass
    cmd = [
        godot, "--headless", "--path", str(project),
        "--script", "res://code_cinema/tools/scan_kit.gd",
        "--", f"--out={out_arg}",
    ]
    output = run(cmd, timeout=240, check=False)
    if not out_path.exists():
        fail("Kit scanner did not produce a manifest.\n" + tail(output))
    data = load_json(out_path)
    log(f"Scanned kit: {out_path}")
    return data
