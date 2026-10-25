# Code Cinema

Code Cinema is a deterministic short-film pipeline for AI-assisted cinematic shorts. It turns a JSON screenplay into a rendered Godot film, then assembles voiceover, sound design, captions, and a final MP4 with Python and FFmpeg.

The project currently targets vertical 9:16 shorts, with 1:1 and 16:9 render paths. The first completed film is **SAVE HER**. A 2D remake of the zombie-apocalypse pilot, **DEAD AIR**, is in progress.

## How it works

```text
films/<slug>/screenplay.json
        |
        v
  validate -> TTS -> resolve timeline
        |
        v
  Godot Movie Writer -> silent AVI
        |
        v
  Python audio mix -> captions/SRT -> FFmpeg mux
        |
        v
  out/<slug>_<format>.mp4
```

The Godot player reads a resolved timeline, builds the scene from the kit, animates the camera and cast, and writes frames through Godot's Movie Writer. Python then builds the mix from the same timeline, so picture and sound stay in sync.

## Features

- JSON screenplays with per-shot dialogue, SFX, camera, cast, and captions.
- Central kit manifest for locations, characters, props, SFX, music, and voices.
- Native 1080x1920, 1080x1080, and 1920x1080 renders.
- Deterministic Godot Movie Writer output at a fixed FPS.
- Edge TTS by default, with optional Sarvam support.
- Voice-forward audio mixing with music ducking, limiting, and loudness normalization.
- Burned-in captions plus SRT export.
- Fast preview renders and format-specific final outputs.
- Validation for formats, locations, characters, props, voices, SFX, and ending cards.

## Repository layout

```text
code-cinema/
  .opencode/skills/code-cinema/   # skill, scripts, templates, style registry
  studio/
    code_cinema/                  # Godot player, kit config, audio manifest
    films/                        # screenplays and story data
    kit/                          # locations, characters, props, generated SFX
    open_assets/                  # downloaded third-party assets (not committed)
    out/                          # rendered deliverables (not committed)
  README.md
```

## Requirements

- Python 3.11+
- Godot 4.7 (standard or .NET build)
- FFmpeg and FFprobe on `PATH`
- `edge-tts` for default narration
- Optional: `SARVAM_API_KEY` for Sarvam TTS

Install the Python dependency:

```powershell
python -m pip install edge-tts
```

## Quick start

```powershell
git clone https://github.com/Kartik-gitClient/code-cinema.git
cd code-cinema

# Point the pipeline at your local Godot and FFmpeg if they are not on PATH.
Copy-Item studio\code_cinema\config.example.json studio\code_cinema\config.json
# Edit config.json with your local paths.

$CC = ".opencode\skills\code-cinema\scripts\codecinema.py"

python $CC validate save_her --project studio
python $CC make save_her --project studio --format vertical
```

Outputs land in `studio/out/`.

For a silent draft render:

```powershell
python $CC make save_her --project studio --no-tts --fast
```

## Common commands

| Command | Purpose |
|---|---|
| `validate <film>` | Check the screenplay against the kit and format registry. |
| `tts <film>` | Generate or reuse cached voiceover. |
| `resolve <film>` | Resolve real voice durations into a timed timeline. |
| `render <film>` | Render the silent video with Godot. |
| `mix <film>` | Build the mixed WAV from timeline cues. |
| `mux <film>` | Combine video and audio into MP4. |
| `make <film>` | Run voice, resolve, render, mix, mux, poster, and captions. |
| `poster <film>` | Extract a poster frame. |
| `srt <film>` | Write subtitles from the resolved timeline. |
| `frames <film>` | Extract review frames. |

Use `--format vertical|square|landscape` on render-oriented commands. Use `--fast` for a half-resolution preview.

## Configuration

`studio/code_cinema/config.json` is local and intentionally not committed. Copy `config.example.json` and set:

```json
{
  "godot": "C:/path/to/Godot_v4.7-stable_win64_console.exe",
  "ffmpeg": "C:/path/to/ffmpeg.exe",
  "ffprobe": "C:/path/to/ffprobe.exe"
}
```

Environment variables `GODOT_BIN`, `FFMPEG_BIN`, and `FFPROBE_BIN` also work.

Create `studio/.env` for provider keys:

```text
SARVAM_API_KEY=
```

Never commit `.env`.

## Assets

The `studio/kit/` folder is committed because it contains the authored scenes, characters, and generated SFX needed to render the current films.

Large third-party downloads under `studio/open_assets/` are not committed. See `studio/open_assets/CREDITS.md` for attribution and use the download scripts in `.opencode/skills/code-cinema/scripts/` to restore them locally.

## Current status

- **SAVE HER**: completed vertical pilot, 1080x1920, 30 fps. The delivered files are frozen in `studio/out/` on the original machine.
- **DEAD AIR**: planned 2D remake of the zombie-apocalypse pilot using Godot's built-in 2D stack.
- Active work: Creative Director story/hook layer, narration direction, audio-post QC, caption pacing, creative QA, reliability checks, and the 2D player.

## Design principles

- Picture and sound come from one resolved timeline.
- Renders are deterministic and reproducible.
- Validation runs before expensive work.
- Cached voiceover is keyed by text and full voice settings.
- Generated media, local config, secrets, and third-party asset caches stay out of Git.
- The final MP4 is the delivery target, not just the WAV or the silent render.

## Credits

Third-party asset attribution lives in `studio/open_assets/CREDITS.md`. Add a project license before redistributing the repository or its rendered media.
