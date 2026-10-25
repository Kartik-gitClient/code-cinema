"""Text-to-speech with disk caching and duration probing (Sarvam + Edge)."""

from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.request
import wave
from datetime import datetime, timezone
from pathlib import Path

from cc_common import (
    PipelineError,
    ensure_dir,
    estimate_vo_duration,
    fail,
    load_json,
    log,
    media_info,
    save_json,
    sha1_text,
    warn,
)

SARVAM_URL = "https://api.sarvam.ai/text-to-speech"
DEFAULT_MODEL = "bulbul:v3"
DEFAULT_VOICE = "narrator"
DEFAULT_EDGE_VOICE = "en-US-AndrewNeural"


def _deep_merge(base: dict, extra: dict) -> dict:
    out = dict(base)
    for key, value in extra.items():
        out[key] = value
    return out


def voice_for(line: dict, kit: dict, screenplay: dict) -> tuple[str, dict]:
    voices = kit.get("voices", {}) if isinstance(kit.get("voices"), dict) else {}
    audio = screenplay.get("audio", {}) if isinstance(screenplay.get("audio"), dict) else {}
    tts_defaults = audio.get("tts", {}) if isinstance(audio.get("tts"), dict) else {}
    default_name = str(tts_defaults.get("default_voice", DEFAULT_VOICE))
    default_voice = dict(voices.get(default_name, {}))
    if not default_voice:
        default_voice = {
            "provider": "edge",
            "voice": DEFAULT_EDGE_VOICE,
            "rate": "-4%",
            "pitch": "+0Hz",
        }

    raw = line.get("voice", default_name)
    if isinstance(raw, dict):
        name = str(raw.get("name", default_name))
        base = dict(voices.get(name, default_voice))
        return name, _deep_merge(_deep_merge(base, tts_defaults), raw)
    name = str(raw or default_name)
    base = dict(voices.get(name, default_voice))
    if name not in voices and raw:
        warn(f"Voice '{name}' is not in kit.json voices; using the default voice.")
    return name, _deep_merge(base, tts_defaults)


def collect_lines(screenplay: dict, kit: dict) -> list[dict]:
    lines: list[dict] = []
    shots = screenplay.get("shots", [])
    if not isinstance(shots, list):
        return lines
    for shot_index, shot in enumerate(shots):
        if not isinstance(shot, dict):
            continue
        shot_id = str(shot.get("id", f"shot{shot_index + 1}"))
        dialogue = shot.get("dialogue", [])
        if not isinstance(dialogue, list):
            continue
        for line_index, line in enumerate(dialogue):
            if not isinstance(line, dict):
                continue
            text = str(line.get("text", "")).strip()
            if not text:
                continue
            name, voice = voice_for(line, kit, screenplay)
            lines.append(
                {
                    "key": f"{shot_id}:{line_index}",
                    "kind": "dialogue",
                    "shot_id": shot_id,
                    "line_index": line_index,
                    "speaker": str(line.get("speaker", "narrator")),
                    "voice_name": name,
                    "voice": voice,
                    "text": text,
                }
            )

    ending = screenplay.get("ending", {})
    if isinstance(ending, dict):
        text = str(ending.get("speak") or ending.get("question") or "").strip()
        if text:
            name, voice = voice_for(ending, kit, screenplay)
            lines.append(
                {
                    "key": "ending",
                    "kind": "ending",
                    "shot_id": None,
                    "line_index": None,
                    "speaker": str(ending.get("speaker", "narrator")),
                    "voice_name": name,
                    "voice": voice,
                    "text": text,
                }
            )
    return lines


def _payload(text: str, voice: dict, model: str) -> dict:
    payload = {
        "text": text,
        "language_code": str(voice.get("language", voice.get("language_code", "en-IN"))),
        "speaker": str(voice.get("speaker", "ishita")),
        "pace": float(voice.get("pace", 1.0)),
        "speech_sample_rate": int(voice.get("sample_rate", 22050)),
        "model": model,
        "output_audio_codec": "wav",
    }
    if model == "bulbul:v2":
        payload["pitch"] = float(voice.get("pitch", 0.0))
        payload["loudness"] = float(voice.get("loudness", 1.0))
        payload["enable_preprocessing"] = bool(voice.get("preprocessing", True))
    else:
        payload["temperature"] = float(voice.get("temperature", 0.6))
    return payload


class SarvamClient:
    def __init__(self, api_key: str, model: str = DEFAULT_MODEL, timeout: int = 120):
        if not api_key:
            fail(
                "SARVAM_API_KEY is not set. Put SARVAM_API_KEY=... in the studio .env, "
                "set the environment variable, or pass --sarvam-key."
            )
        self.api_key = api_key.strip()
        self.model = model or DEFAULT_MODEL
        self.timeout = timeout

    def synthesize(self, text: str, voice: dict) -> bytes:
        payload = _payload(text, voice, self.model)
        request = urllib.request.Request(
            SARVAM_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "api-subscription-key": self.api_key,
                "Content-Type": "application/json",
                "User-Agent": "code-cinema/0.1",
            },
            method="POST",
        )
        last_error = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    data = json.loads(response.read().decode("utf-8"))
                audios = data.get("audios") or []
                if not audios:
                    last_error = PipelineError(f"Sarvam returned no audio: {data}")
                    break
                return base64.b64decode(audios[0])
            except urllib.error.HTTPError as exc:
                body = ""
                try:
                    body = exc.read().decode("utf-8", "replace")
                except Exception:
                    pass
                last_error = PipelineError(f"Sarvam HTTP {exc.code}: {body.strip() or exc.reason}")
                if exc.code in (429, 500, 502, 503, 504) and attempt < 2:
                    time.sleep(2.0 * (attempt + 1))
                    continue
                break
            except urllib.error.URLError as exc:
                last_error = PipelineError(f"Could not reach Sarvam: {exc.reason}")
                if attempt < 2:
                    time.sleep(2.0 * (attempt + 1))
                    continue
                break
            except json.JSONDecodeError as exc:
                last_error = PipelineError(f"Sarvam returned invalid JSON: {exc}")
                break
        raise last_error or PipelineError("Sarvam synthesis failed for an unknown reason.")


def _edge_rate(voice: dict) -> str:
    rate = voice.get("rate")
    if rate:
        return str(rate)
    pace = float(voice.get("pace", 1.0))
    return f"{int(round((pace - 1.0) * 100.0)):+d}%"


class EdgeTTSClient:
    def __init__(self, timeout: int = 120):
        self.timeout = timeout

    def synthesize(self, text: str, voice: dict, out_path: Path) -> None:
        try:
            import edge_tts
        except ImportError as exc:
            fail("edge-tts is not installed. Run: python -m pip install edge-tts")
            raise AssertionError from exc
        voice_name = str(voice.get("voice", DEFAULT_EDGE_VOICE))
        try:
            communicate = edge_tts.Communicate(
                text,
                voice_name,
                rate=_edge_rate(voice),
                pitch=str(voice.get("pitch", "+0Hz")),
                volume=str(voice.get("volume", "+0%")),
            )
            communicate.save_sync(str(out_path))
        except Exception as exc:
            raise PipelineError(f"Edge TTS failed for voice '{voice_name}': {exc}") from exc
        if not out_path.exists() or out_path.stat().st_size <= 0:
            raise PipelineError(f"Edge TTS returned empty audio for: {text}")


def _wav_duration(path: Path) -> float | None:
    try:
        with wave.open(str(path), "rb") as handle:
            frames = handle.getnframes()
            rate = handle.getframerate()
            if rate:
                return frames / float(rate)
    except (wave.Error, OSError):
        return None
    return None


def probe_duration(path: Path, ffprobe: str | None) -> float:
    if path.suffix.lower() == ".wav":
        duration = _wav_duration(path)
        if duration:
            return duration
    if ffprobe:
        try:
            info = media_info(path, ffprobe)
            if info.get("duration"):
                return float(info["duration"])
        except PipelineError:
            pass
    return 0.0


def generate_all(
    project: Path,
    screenplay: dict,
    kit: dict,
    build_dir: Path,
    *,
    api_key: str = "",
    model: str = DEFAULT_MODEL,
    ffprobe: str | None = None,
    no_tts: bool = False,
    force: bool = False,
    silent_ok: bool = False,
) -> dict:
    lines = collect_lines(screenplay, kit)
    vo_dir = ensure_dir(build_dir / "vo")
    cache_dir = ensure_dir(vo_dir / "cache")
    result = {
        "model": model,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "no_tts": no_tts,
        "lines": {},
    }

    if not lines:
        log("No voiceover lines found.")
        save_json(vo_dir / "vo.json", result)
        return result

    sarvam_client = None
    edge_client = None

    total = len(lines)
    for index, line in enumerate(lines, start=1):
        text = line["text"]
        voice = line["voice"]
        display = text if len(text) <= 58 else text[:55] + "..."
        log(f"[{index}/{total}] {line['speaker']}: {display}")

        if no_tts:
            duration = estimate_vo_duration(text)
            result["lines"][line["key"]] = {
                **line,
                "path": None,
                "duration": round(duration, 3),
                "silent": True,
            }
            continue

        provider = str(voice.get("provider", "sarvam")).strip().lower()
        if provider == "edge":
            if edge_client is None:
                edge_client = EdgeTTSClient()
            cache_payload = {
                "provider": "edge",
                "voice": voice,
                "text": text,
            }
            cache_key = sha1_text(json.dumps(cache_payload, sort_keys=True, ensure_ascii=False))
            cache_path = cache_dir / f"{cache_key}.mp3"
            if cache_path.exists() and not force:
                log("  cached")
            else:
                edge_client.synthesize(text, voice, cache_path)
                log(f"  {cache_path.stat().st_size:,} bytes")
        else:
            if sarvam_client is None:
                if not api_key:
                    fail(
                        "SARVAM_API_KEY is not set. Put SARVAM_API_KEY=... in the studio .env, "
                        "set the environment variable, or pass --sarvam-key. "
                        "Use --no-tts for a silent draft render."
                    )
                sarvam_client = SarvamClient(api_key, model=model)
            payload = _payload(text, voice, model)
            cache_key = sha1_text(json.dumps(payload, sort_keys=True, ensure_ascii=False))
            cache_path = cache_dir / f"{cache_key}.wav"
            if cache_path.exists() and not force:
                log("  cached")
            else:
                raw = sarvam_client.synthesize(text, voice)
                if not raw:
                    fail(f"Sarvam returned empty audio for: {text}")
                cache_path.write_bytes(raw)
                log(f"  {len(raw):,} bytes")
        duration = probe_duration(cache_path, ffprobe)
        if duration <= 0.0:
            duration = estimate_vo_duration(text)
            warn(f"Could not probe audio duration; estimated {duration:.2f}s")
        result["lines"][line["key"]] = {
            **line,
            "path": str(cache_path.resolve()),
            "duration": round(duration, 3),
            "silent": False,
        }

    save_json(vo_dir / "vo.json", result)
    log(f"Voiceover ready: {vo_dir / 'vo.json'}")
    return result


def load_vo(build_dir: Path) -> dict:
    path = build_dir / "vo" / "vo.json"
    return load_json(path) if path.exists() else {}
