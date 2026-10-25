"""Turn a screenplay + voiceover durations into a resolved, timed film."""

from __future__ import annotations

import copy
import re
import sys
from pathlib import Path

from cc_common import PipelineError, estimate_vo_duration, fail, load_json, log, resolve_format, warn
from cc_tts import collect_lines


def _as_list(value) -> list:
    return value if isinstance(value, list) else []


def _as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def _kit_audio_path(project: Path, value: str) -> str:
    if not value:
        return ""
    if value.startswith("res://"):
        return str((project / value[len("res://"):]).resolve())
    path = Path(value)
    return str(path if path.is_absolute() else (project / path).resolve())


def _audio_farm_config(project: Path, audio: dict) -> dict:
    farm_path = project / "code_cinema" / "audio_manifest.json"
    profile_name = str(audio.get("mix_profile", "clean"))
    merged = dict(audio)
    merged["mix_profile"] = profile_name
    merged["dialog_gain"] = float(audio.get("dialog_gain", 2.8))
    merged["sfx_gain"] = float(audio.get("sfx_gain", 0.4))
    merged["music_gain"] = float(audio.get("music_gain", 0.5))
    user_retro = audio.get("retro") if isinstance(audio.get("retro"), dict) else {}
    merged_retro = {"vo": False, "sfx": False, "music": False}
    if farm_path.exists():
        try:
            farm = load_json(farm_path)
        except PipelineError:
            farm = {}
        profiles = farm.get("mix_profiles") if isinstance(farm.get("mix_profiles"), dict) else {}
        if not profiles or profile_name not in profiles:
            if profile_name != "clean":
                warn(f"Unknown audio mix_profile '{profile_name}'; using clean.")
        else:
            profile = profiles[profile_name]
            if not isinstance(profile, dict):
                profile = {}
            for key in ("dialog_gain", "sfx_gain", "music_gain"):
                if key in profile:
                    merged[key] = float(profile[key])
            profile_retro = profile.get("retro") if isinstance(profile.get("retro"), dict) else {}
            merged_retro.update(profile_retro)
    for key in ("vo", "sfx", "music"):
        merged_retro[key] = bool(merged_retro.get(key, False) or bool(user_retro.get(key, False)))
    merged["retro"] = merged_retro
    return merged


def split_caption(text: str, max_chars: int = 84) -> list[str]:
    clean = re.sub(r"\s+", " ", (text or "").strip())
    if not clean:
        return []
    if len(clean) <= max_chars:
        return [clean]
    sentences = re.split(r"(?<=[.!?])\s+", clean)
    chunks: list[str] = []
    current = ""
    for sentence in sentences:
        candidate = (current + " " + sentence).strip() if current else sentence
        if len(candidate) <= max_chars:
            current = candidate
            continue
        if current:
            chunks.append(current)
        if len(sentence) <= max_chars:
            current = sentence
        else:
            words = sentence.split()
            current = ""
            for word in words:
                candidate = (current + " " + word).strip() if current else word
                if len(candidate) <= max_chars:
                    current = candidate
                else:
                    if current:
                        chunks.append(current)
                    current = word
    if current:
        chunks.append(current)
    return chunks or [clean]


def _caption_chunks_for_line(text: str, line: dict) -> list[str]:
    override = line.get("caption_chunks")
    if isinstance(override, list) and override:
        return [str(c) for c in override if str(c).strip()]
    caption_text = str(line.get("caption_text", text)).strip()
    return split_caption(caption_text, int(line.get("caption_max_chars", 84)))


def _voice_entry(vo: dict, key: str, text: str) -> dict:
    lines = _as_dict(vo.get("lines"))
    entry = lines.get(key)
    if isinstance(entry, dict):
        return entry
    return {"path": None, "duration": estimate_vo_duration(text), "silent": True}


def resolve_timeline(
    screenplay: dict,
    kit: dict,
    project: Path,
    vo: dict | None = None,
    *,
    no_tts: bool = False,
) -> dict:
    vo = vo or {}
    out = copy.deepcopy(screenplay)
    format_info = resolve_format(out.get("format_id"), out)
    width = int(format_info["width"])
    height = int(format_info["height"])
    fps = float(format_info["fps"])
    out["format_id"] = str(format_info["id"])
    out["format"] = {
        "id": str(format_info["id"]),
        "label": str(format_info.get("label", "")),
        "aspect": str(format_info.get("aspect", "")),
        "width": width,
        "height": height,
        "fps": fps,
    }

    opening = _as_dict(out.get("opening"))
    opening_duration = max(0.0, float(opening.get("duration", 0.0)))
    opening["duration"] = opening_duration
    opening["start"] = 0.0
    out["opening"] = opening

    cues: dict[str, list] = {"dialogue": [], "sfx": [], "music": []}
    captions: list[dict] = []
    shots_out: list[dict] = []
    cursor = opening_duration
    gap = float(_as_dict(out.get("audio")).get("dialogue_gap", 0.22))
    tail = float(_as_dict(out.get("audio")).get("shot_tail", 0.30))

    for shot_index, raw_shot in enumerate(_as_list(out.get("shots"))):
        if not isinstance(raw_shot, dict):
            continue
        shot = copy.deepcopy(raw_shot)
        shot_id = str(shot.get("id", f"shot{shot_index + 1}"))
        min_duration = max(0.05, float(shot.get("duration", 3.0)))
        shot_start = cursor
        line_cursor = 0.0
        content_end = 0.0
        resolved_dialogue: list[dict] = []

        for line_index, raw_line in enumerate(_as_list(shot.get("dialogue"))):
            if not isinstance(raw_line, dict):
                continue
            text = str(raw_line.get("text", "")).strip()
            if not text:
                continue
            key = f"{shot_id}:{line_index}"
            entry = _voice_entry(vo, key, text)
            duration = max(0.3, float(entry.get("duration") or estimate_vo_duration(text)))
            authored_start = max(0.0, float(raw_line.get("start", 0.0)))
            line_start = max(authored_start, line_cursor)
            line_end = line_start + duration
            local_gap = max(0.0, float(raw_line.get("gap", gap)))
            line_cursor = line_end + local_gap
            content_end = max(content_end, line_cursor)

            line_out = copy.deepcopy(raw_line)
            line_out["start"] = round(line_start, 3)
            line_out["duration"] = round(duration, 3)
            line_out["end"] = round(line_end, 3)
            line_out["path"] = entry.get("path")
            line_out["silent"] = bool(entry.get("silent", not entry.get("path")))
            resolved_dialogue.append(line_out)

            cues["dialogue"].append(
                {
                    "key": key,
                    "kind": "dialogue",
                    "shot_id": shot_id,
                    "speaker": str(raw_line.get("speaker", "narrator")),
                    "text": text,
                    "start": round(shot_start + line_start, 3),
                    "duration": round(duration, 3),
                    "volume": float(raw_line.get("volume", 1.0)),
                    "path": entry.get("path"),
                    "silent": bool(entry.get("silent", not entry.get("path"))),
                }
            )

            if bool(shot.get("captions", True)) and bool(raw_line.get("caption", True)):
                chunks = _caption_chunks_for_line(text, raw_line)
                if chunks:
                    total_chars = max(1, sum(len(c) for c in chunks))
                    chunk_cursor = line_start
                    for chunk_index, chunk in enumerate(chunks):
                        if chunk_index == len(chunks) - 1:
                            chunk_end = line_end
                        else:
                            share = len(chunk) / total_chars
                            chunk_end = chunk_cursor + max(0.35, duration * share)
                            chunk_end = min(chunk_end, line_end)
                        if chunk_end <= chunk_cursor:
                            chunk_end = min(line_end, chunk_cursor + 0.3)
                        captions.append(
                            {
                                "start": round(shot_start + chunk_cursor, 3),
                                "end": round(shot_start + chunk_end, 3),
                                "text": chunk,
                            }
                        )
                        chunk_cursor = chunk_end

        sfx_out: list[dict] = []
        for raw_sfx in _as_list(shot.get("sfx")):
            if not isinstance(raw_sfx, dict):
                continue
            sound = str(raw_sfx.get("sound", ""))
            at = max(0.0, float(raw_sfx.get("at", 0.0)))
            sfx = copy.deepcopy(raw_sfx)
            sfx["at"] = round(at, 3)
            sfx_out.append(sfx)
            content_end = max(content_end, at + 1.0)
            path = ""
            sfx_table = _as_dict(kit.get("sfx"))
            if sound and isinstance(sfx_table.get(sound), str):
                path = _kit_audio_path(project, str(sfx_table[sound]))
            cues["sfx"].append(
                {
                    "sound": sound,
                    "start": round(shot_start + at, 3),
                    "duration": float(raw_sfx.get("duration", 0.0)),
                    "volume": float(raw_sfx.get("volume", 1.0)),
                    "path": path,
                }
            )

        actual_duration = max(min_duration, content_end + tail)
        shot["duration"] = round(actual_duration, 3)
        shot["start"] = round(shot_start, 3)
        if resolved_dialogue:
            shot["dialogue"] = resolved_dialogue
        if sfx_out:
            shot["sfx"] = sfx_out
        shots_out.append(shot)
        cursor += actual_duration

    shots_end = cursor

    ending = _as_dict(out.get("ending"))
    if ending:
        ending = copy.deepcopy(ending)
        ending_start = cursor
        text = str(ending.get("speak") or ending.get("question") or "").strip()
        entry = _voice_entry(vo, "ending", text) if text else {"duration": 0.0, "path": None, "silent": True}
        vo_duration = max(0.0, float(entry.get("duration") or 0.0))
        authored = max(0.5, float(ending.get("duration", 5.0)))
        ending_duration = max(authored, 0.45 + vo_duration + 1.0)
        ending["start"] = round(ending_start, 3)
        ending["duration"] = round(ending_duration, 3)
        out["ending"] = ending
        if text:
            cues["dialogue"].append(
                {
                    "key": "ending",
                    "kind": "ending",
                    "shot_id": None,
                    "speaker": str(ending.get("speaker", "narrator")),
                    "text": text,
                    "start": round(ending_start + 0.45, 3),
                    "duration": round(vo_duration, 3),
                    "volume": 1.0,
                    "path": entry.get("path"),
                    "silent": bool(entry.get("silent", not entry.get("path"))),
                }
            )
        cursor += ending_duration
    else:
        out.pop("ending", None)

    total = cursor
    audio = _audio_farm_config(project, _as_dict(out.get("audio")))
    out["audio"] = audio
    music = _as_dict(audio.get("music"))
    if music:
        track = str(music.get("track", ""))
        music_table = _as_dict(kit.get("music"))
        path = ""
        if track and isinstance(music_table.get(track), str):
            path = _kit_audio_path(project, str(music_table[track]))
        cues["music"].append(
            {
                "track": track,
                "start": 0.0,
                "duration": round(total, 3),
                "volume": float(music.get("volume", 0.18)),
                "path": path,
            }
        )

    out["shots"] = shots_out
    out["captions"] = captions
    out["cues"] = cues
    out["duration"] = round(total, 3)
    out["shots_end"] = round(shots_end, 3)
    out["no_tts"] = bool(no_tts)
    return out


def estimate_vo_from_script(screenplay: dict, kit: dict) -> dict:
    lines = collect_lines(screenplay, kit)
    out = {"model": "estimate", "lines": {}}
    for line in lines:
        out["lines"][line["key"]] = {
            **line,
            "path": None,
            "duration": round(estimate_vo_duration(line["text"]), 3),
            "silent": True,
        }
    return out


def timeline_stats(resolved: dict) -> str:
    shots = _as_list(resolved.get("shots"))
    total = float(resolved.get("duration", 0.0))
    dialogue = len(_as_list(_as_dict(resolved.get("cues")).get("dialogue")))
    sfx = len(_as_list(_as_dict(resolved.get("cues")).get("sfx")))
    captions = len(_as_list(resolved.get("captions")))
    return (
        f"{len(shots)} shots | {total:.2f}s | {dialogue} voice cues | "
        f"{sfx} sfx | {captions} captions"
    )


def warn_long_lines(screenplay: dict) -> None:
    for shot in _as_list(screenplay.get("shots")):
        if not isinstance(shot, dict):
            continue
        for line in _as_list(shot.get("dialogue")):
            if not isinstance(line, dict):
                continue
            text = str(line.get("text", ""))
            if len(text) > 220:
                warn(f"Long voiceover line ({len(text)} chars); consider splitting: {text[:60]}...")
